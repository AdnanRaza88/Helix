import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../agent/context_compactor.dart';
import '../agent/system_prompt.dart';
import '../agent/tool_router.dart';
import '../github.dart';
import '../skills/github_ops.dart';
import 'openai_compat.dart' show StreamAbort;

class OllamaClient {
  OllamaClient({
    required this.baseUrl,
    required this.model,
    required this.github,
    this.confirm,
  }) : router = ToolRouter(ops: GithubOps(github), confirm: confirm);

  final String baseUrl;
  final String model;
  final GitHubClient github;
  final MutationConfirm? confirm;
  final ToolRouter router;
  StreamAbort? activeAbort;
  String? activeRepo;

  String get _root {
    var u = baseUrl.trim();
    if (u.isEmpty) u = 'http://127.0.0.1:11434';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  bool get isLive => model.isNotEmpty;

  void bindConfirm(MutationConfirm fn) {
    router.confirm = fn;
  }

  void stop() => activeAbort?.cancel();

  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$_root/api/tags'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> listModels() async {
    final res = await http
        .get(Uri.parse('$_root/api/tags'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Ollama ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final models = data['models'] as List? ?? const [];
    return models
        .map((m) => (m is Map ? '${m['name'] ?? ''}' : ''))
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Stream<double> pullModel(String name) async* {
    final req = http.Request('POST', Uri.parse('$_root/api/pull'));
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode({'name': name, 'stream': true});
    final client = http.Client();
    try {
      final streamed =
          await client.send(req).timeout(const Duration(minutes: 30));
      if (streamed.statusCode >= 400) {
        final err = await streamed.stream.bytesToString();
        throw Exception('Ollama pull ${streamed.statusCode}: $err');
      }
      var carry = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        carry += chunk;
        final lines = carry.split('\n');
        carry = lines.removeLast();
        for (final line in lines) {
          final t = line.trim();
          if (t.isEmpty) continue;
          try {
            final j = jsonDecode(t) as Map<String, dynamic>;
            final total = (j['total'] as num?)?.toDouble() ?? 0;
            final completed = (j['completed'] as num?)?.toDouble() ?? 0;
            if (total > 0) {
              yield (completed / total).clamp(0.0, 1.0);
            }
            final status = '${j['status'] ?? ''}';
            if (status.contains('success')) yield 1.0;
          } catch (_) {}
        }
      }
      yield 1.0;
    } finally {
      client.close();
    }
  }

  Future<String> runWithTools(
    String userMessage, {
    List<Map<String, String>> history = const [],
    void Function(String delta)? onDelta,
    void Function(String toolName)? onTool,
    StreamAbort? abort,
  }) async {
    activeAbort = abort ?? StreamAbort();
    final token = activeAbort!;
    if (!isLive) {
      const sim = '[Ollama] Set base URL + model, then pull a model.';
      onDelta?.call(sim);
      return sim;
    }

    final compacted = ContextCompactor.compact(history);
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': HelixPrompt.build(
          githubLive: github.isLive,
          activeRepo: activeRepo,
        ),
      },
    ];
    for (final m in compacted) {
      messages.add({
        'role': m['role'] == 'user' ? 'user' : 'assistant',
        'content': m['text'] ?? '',
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    final tools = router.functionDeclarations
        .map((d) => {
              'type': 'function',
              'function': d,
            })
        .toList();

    String lastText = '';
    for (var hop = 0; hop < 6; hop++) {
      if (token.cancelled) return lastText.isEmpty ? 'Stopped.' : lastText;
      final parsed = await _chat(messages, tools, token, onDelta);
      lastText = parsed.text.isNotEmpty ? parsed.text : lastText;
      if (parsed.calls.isEmpty) {
        return lastText.isEmpty ? 'Empty response.' : lastText;
      }
      messages.add({
        'role': 'assistant',
        'content': parsed.text.isEmpty ? null : parsed.text,
        'tool_calls': parsed.calls
            .asMap()
            .entries
            .map((e) => {
                  'id': e.value['id'] ?? 'call_${e.key}',
                  'type': 'function',
                  'function': {
                    'name': e.value['name'],
                    'arguments': e.value['arguments'] is String
                        ? e.value['arguments']
                        : jsonEncode(e.value['arguments'] ?? {}),
                  },
                })
            .toList(),
      });
      for (final call in parsed.calls) {
        if (token.cancelled) break;
        final name = '${call['name'] ?? ''}';
        onTool?.call(name);
        Map<String, dynamic> args = {};
        final rawArgs = call['arguments'];
        if (rawArgs is String && rawArgs.isNotEmpty) {
          try {
            final d = jsonDecode(rawArgs);
            if (d is Map) args = Map<String, dynamic>.from(d);
          } catch (_) {}
        } else if (rawArgs is Map) {
          args = Map<String, dynamic>.from(rawArgs);
        }
        final result = await router.dispatch(name, args);
        messages.add({
          'role': 'tool',
          'tool_call_id': call['id'] ?? 'call_0',
          'content': result,
        });
      }
    }
    return lastText.isEmpty ? 'Tool loop ended.' : lastText;
  }

  Future<_Parsed> _chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    StreamAbort abort,
    void Function(String delta)? onDelta,
  ) async {
    final uri = Uri.parse('$_root/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'stream': false,
      'temperature': 0.4,
    });
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 120));
    if (abort.cancelled) return _Parsed('', []);
    if (res.statusCode >= 400) {
      return _nativeChat(messages, abort, onDelta);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? const [];
    if (choices.isEmpty) return _Parsed('', []);
    final msg = choices[0]['message'] as Map<String, dynamic>? ?? {};
    final text = (msg['content'] as String?) ?? '';
    if (text.isNotEmpty) onDelta?.call(text);
    final calls = <Map<String, dynamic>>[];
    final toolCalls = msg['tool_calls'] as List? ?? const [];
    for (final c in toolCalls) {
      if (c is! Map) continue;
      final fn = c['function'] as Map? ?? {};
      calls.add({
        'id': c['id'],
        'name': fn['name'],
        'arguments': fn['arguments'],
      });
    }
    return _Parsed(text, calls);
  }

  Future<_Parsed> _nativeChat(
    List<Map<String, dynamic>> messages,
    StreamAbort abort,
    void Function(String delta)? onDelta,
  ) async {
    final uri = Uri.parse('$_root/api/chat');
    final clean = messages
        .map((m) => {
              'role': m['role'],
              'content': m['content']?.toString() ?? '',
            })
        .toList();
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'messages': clean,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (abort.cancelled) return _Parsed('', []);
    if (res.statusCode >= 400) {
      throw Exception('Ollama ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final msg = data['message'] as Map<String, dynamic>? ?? {};
    final text = (msg['content'] as String?) ?? '';
    if (text.isNotEmpty) onDelta?.call(text);
    return _Parsed(text, []);
  }
}

class _Parsed {
  _Parsed(this.text, this.calls);
  final String text;
  final List<Map<String, dynamic>> calls;
}
