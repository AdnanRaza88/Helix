import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'agent/context_compactor.dart';
import 'agent/system_prompt.dart';
import 'agent/tool_router.dart';
import 'github.dart';
import 'skills/github_ops.dart';

class StreamAbort {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class GeminiClient {
  GeminiClient({required this.apiKey, required this.github, this.confirm})
      : router = ToolRouter(ops: GithubOps(github), confirm: confirm);

  final String apiKey;
  final GitHubClient github;
  final MutationConfirm? confirm;
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

  static const _models = [
    'gemini-2.5-flash',
    'gemini-3.5-flash',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];
  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

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
      final sim = _simulate(userMessage);
      onDelta?.call(sim);
      return sim;
    }

    final compacted = ContextCompactor.compact(history);
    final contents = <Map<String, dynamic>>[];
    for (final m in compacted) {
      contents.add({
        'role': m['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': m['text'] ?? ''}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final tools = [
      {'functionDeclarations': router.functionDeclarations}
    ];

    String lastText = '';
    for (var hop = 0; hop < 6; hop++) {
      if (token.cancelled) return lastText.isEmpty ? 'Stopped.' : lastText;
      final parsed = await _generateStream(contents, tools, token, onDelta);
      lastText = parsed.text.isNotEmpty ? parsed.text : lastText;
      if (parsed.calls.isEmpty) {
        return lastText.isEmpty ? 'Empty response.' : lastText;
      }
      contents.add({
        'role': 'model',
        'parts': parsed.calls
            .map((c) => {
                  'functionCall': {
                    'name': c['name'],
                    'args': c['args'] ?? {},
                  }
                })
            .toList(),
      });
      final responseParts = <Map<String, dynamic>>[];
      for (final c in parsed.calls) {
        if (token.cancelled) break;
        final name = '${c['name'] ?? ''}';
        onTool?.call(name);
        final args = Map<String, dynamic>.from(c['args'] as Map? ?? {});
        String result;
        try {
          result = await router.dispatch(name, args);
        } catch (e) {
          result = jsonEncode({'error': e.toString()});
        }
        responseParts.add({
          'functionResponse': {
            'name': name,
            'response': {'result': result},
          }
        });
      }
      contents.add({'role': 'user', 'parts': responseParts});
    }
    return lastText.isEmpty ? 'Tool loop stopped.' : lastText;
  }

  Future<_Parsed> _generateStream(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> tools,
    StreamAbort abort,
    void Function(String delta)? onDelta,
  ) async {
    final body = {
      'system_instruction': {
        'parts': [
          {
            'text': HelixPrompt.build(
              githubLive: github.isLive,
              activeRepo: activeRepo,
            )
          }
        ],
      },
      'contents': contents,
      'tools': tools,
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
      },
    };

    Exception? lastError;
    for (final model in _models) {
      if (abort.cancelled) return _Parsed('', []);
      try {
        final uri =
            Uri.parse('$_base/$model:streamGenerateContent?alt=sse&key=$apiKey');
        final req = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body);
        final streamed = await http.Client().send(req);
        if (streamed.statusCode == 404) {
          lastError = Exception('Model $model not found');
          continue;
        }
        if (streamed.statusCode >= 400) {
          final err = await streamed.stream.bytesToString();
          throw Exception('Gemini ${streamed.statusCode}: $err');
        }
        return await _readSse(streamed, abort, onDelta);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('404')) continue;
        rethrow;
      }
    }
    throw lastError ?? Exception('No Gemini model available');
  }

  Future<_Parsed> _readSse(
    http.StreamedResponse streamed,
    StreamAbort abort,
    void Function(String delta)? onDelta,
  ) async {
    final buf = StringBuffer();
    final calls = <Map<String, dynamic>>[];
    var carry = '';
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      if (abort.cancelled) break;
      carry += chunk;
      final lines = carry.split('\n');
      carry = lines.removeLast();
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final raw = trimmed.substring(5).trim();
        if (raw.isEmpty || raw == '[DONE]') continue;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final content =
              candidates[0]['content'] as Map<String, dynamic>? ?? {};
          final parts = content['parts'] as List? ?? const [];
          for (final p in parts) {
            if (p is! Map) continue;
            final fc = p['functionCall'];
            if (fc is Map) {
              calls.add(Map<String, dynamic>.from(fc));
            }
            final t = p['text'];
            if (t is String && t.isNotEmpty) {
              buf.write(t);
              onDelta?.call(t);
            }
          }
        } catch (_) {}
      }
    }
    return _Parsed(buf.toString(), calls);
  }

  String _simulate(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('repo') || lower.contains('list')) {
      return '[SIM] Sample repositories:\n\n'
          '- helix-user/helix-core (public)\n'
          '- helix-user/pulse-api (private)\n\n'
          'Add a GitHub token in Settings for live data.';
    }
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hello. I am Helix, your GitHub operator.\n'
          'Add a Gemini API key and GitHub token in Settings to unlock live tools.';
    }
    return '[SIM] Simulation mode.\n'
        'Phase 2 tools: PRs, branches, Actions list/trigger, code review.\n'
        'Writes require confirm when live.'
        '${activeRepo == null ? '' : '\nActive repo: $activeRepo'}';
  }
}

class _Parsed {
  _Parsed(this.text, this.calls);
  final String text;
  final List<Map<String, dynamic>> calls;
}
