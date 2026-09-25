import 'dart:convert';
import 'package:http/http.dart' as http;

import 'agent/context_compactor.dart';
import 'agent/system_prompt.dart';
import 'agent/tool_router.dart';
import 'github.dart';
import 'skills/github_ops.dart';

class GeminiClient {
  GeminiClient({required this.apiKey, required this.github, this.confirm})
      : router = ToolRouter(ops: GithubOps(github), confirm: confirm);

  final String apiKey;
  final GitHubClient github;
  final MutationConfirm? confirm;
  final ToolRouter router;

  bool get isLive => apiKey.isNotEmpty;

  void bindConfirm(MutationConfirm fn) {
    router.confirm = fn;
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
  }) async {
    if (!isLive) return _simulate(userMessage);

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

    String? lastText;
    for (var hop = 0; hop < 6; hop++) {
      final data = await _generate(contents, tools);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return lastText ?? 'No response from Gemini.';
      }
      final content = candidates[0]['content'] as Map<String, dynamic>? ?? {};
      final parts = content['parts'] as List? ?? const [];
      final calls = <Map<String, dynamic>>[];
      final texts = <String>[];
      for (final p in parts) {
        if (p is! Map) continue;
        final fc = p['functionCall'];
        if (fc is Map) {
          calls.add(Map<String, dynamic>.from(fc));
        }
        final t = p['text'];
        if (t is String && t.trim().isNotEmpty) texts.add(t);
      }
      if (texts.isNotEmpty) lastText = texts.join('\n');
      if (calls.isEmpty) {
        return lastText ?? 'Empty response.';
      }
      contents.add({
        'role': 'model',
        'parts': calls
            .map((c) => {
                  'functionCall': {
                    'name': c['name'],
                    'args': c['args'] ?? {},
                  }
                })
            .toList(),
      });
      final responseParts = <Map<String, dynamic>>[];
      for (final c in calls) {
        final name = '${c['name'] ?? ''}';
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
    return lastText ?? 'Tool loop stopped.';
  }

  Future<Map<String, dynamic>> _generate(
    List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> tools,
  ) async {
    final body = {
      'system_instruction': {
        'parts': [
          {'text': HelixPrompt.build(githubLive: github.isLive)}
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
      try {
        final uri = Uri.parse('$_base/$model:generateContent?key=$apiKey');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (res.statusCode == 404) {
          lastError = Exception('Model $model not found');
          continue;
        }
        if (res.statusCode >= 400) {
          throw Exception('Gemini ${res.statusCode}: ${res.body}');
        }
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('404')) continue;
        rethrow;
      }
    }
    throw lastError ?? Exception('No Gemini model available');
  }

  String _simulate(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('repo') || lower.contains('list')) {
      return '[SIM] Sample repositories:\n\n'
          '\u2022 helix-user/helix-core (public) \u2605128\n'
          '\u2022 helix-user/pulse-api (private) \u26054\n'
          '\u2022 helix-user/glass-ui (public) \u260542\n\n'
          'Add a GitHub token in Settings for live data.';
    }
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hello. I am Helix, your GitHub operator.\n'
          'Add a Gemini API key and GitHub token in Settings to unlock live tools.';
    }
    return '[SIM] Simulation mode.\n'
        'Phase 1 tools: get user, list/get repos, issues, files, tree, search code.\n'
        'Writes (create issue, put file) require confirm when live.';
  }
}
