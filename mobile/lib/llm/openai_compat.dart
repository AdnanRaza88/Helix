import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../agent/context_compactor.dart';
import '../agent/system_prompt.dart';
import '../agent/tool_router.dart';
import '../github.dart';
import '../skills/github_ops.dart';

class StreamAbort {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class OpenAiCompatClient {
  OpenAiCompatClient({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.github,
    this.confirm,
    this.providerLabel = 'OpenAI',
    this.extraHeaders = const {},
  }) : router = ToolRouter(ops: GithubOps(github), confirm: confirm);

  final String apiKey;
  final String baseUrl;
  final String model;
  final GitHubClient github;
  final MutationConfirm? confirm;
  final String providerLabel;
  final Map<String, String> extraHeaders;
  final ToolRouter router;
  StreamAbort? activeAbort;
  String? activeRepo;

  bool get isLive => apiKey.isNotEmpty;

  void bindConfirm(MutationConfirm fn) {
    router.confirm = fn;
  }

  void stop() {
    activeAbort?.cancel();
  }

  Future<String> chat(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) {
    return runWithTools(userMessage, history: history);
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
      final sim =
          '[$providerLabel SIM] Add API key in Settings for live tools.';
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
    final uri = Uri.parse(
      baseUrl.endsWith('/')
          ? '${baseUrl}chat/completions'
          : '$baseUrl/chat/completions',
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      ...extraHeaders,
    };
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'stream': false,
      'temperature': 0.4,
    });

    final res = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 90));
    if (abort.cancelled) return _Parsed('', []);
    if (res.statusCode >= 400) {
      throw Exception('$providerLabel ${res.statusCode}: ${res.body}');
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
}

class _Parsed {
  _Parsed(this.text, this.calls);
  final String text;
  final List<Map<String, dynamic>> calls;
}
