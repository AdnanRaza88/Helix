import 'dart:convert';
import 'package:http/http.dart' as http;
import 'github.dart';

class GeminiClient {
  GeminiClient({required this.apiKey, required this.github});

  final String apiKey;
  final GitHubClient github;

  bool get isLive => apiKey.isNotEmpty;

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
  }) async {
    if (!isLive) return _simulate(userMessage);

    final system = '''
You are Helix, a VIP glassmorphism GitHub control agent.
You help the user manage their GitHub account using natural language.
You have access to GitHub tools via the connected token.
When the user asks to list repos, create issues, create repos, or similar, respond with a clear plan and the result.
Keep answers concise, professional, and helpful.
Remember the full conversation context and refer to earlier messages when relevant.
Current GitHub mode: ${github.isLive ? "LIVE" : "SIMULATION"}.
''';

    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      contents.add({
        'role': m['role'] == 'user' ? 'user' : 'model',
        'parts': [{'text': m['text'] ?? ''}],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    final body = {
      'system_instruction': {
        'parts': [{'text': system}],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.4,
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
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          return 'No response from Gemini.';
        }
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) return 'Empty response.';
        return (parts[0]['text'] as String?) ?? 'Empty response.';
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('404')) continue;
        rethrow;
      }
    }
    throw lastError ?? Exception('No Gemini model available');
  }

  Future<String> runWithTools(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async {
    final lower = userMessage.toLowerCase();

    if (lower.contains('list repo') ||
        lower.contains('my repo') ||
        lower.contains('show repo') ||
        lower.contains('repositories')) {
      try {
        final repos = await github.listRepos();
        if (repos.isEmpty) return 'No repositories found.';
        final buf = StringBuffer('Found ${repos.length} repositories:\n\n');
        for (final r in repos.take(15)) {
          final name = r['full_name'] ?? r['name'] ?? '?';
          final priv = r['private'] == true ? 'private' : 'public';
          final stars = r['stargazers_count'] ?? 0;
          final desc = (r['description'] ?? '').toString();
          buf.writeln('• $name ($priv) ★$stars');
          if (desc.isNotEmpty) buf.writeln('  $desc');
        }
        return buf.toString();
      } catch (e) {
        return 'Failed to list repos: $e';
      }
    }

    if (lower.contains('who am i') ||
        lower.contains('my profile') ||
        lower.contains('my account')) {
      try {
        final user = await github.getUser();
        return 'Logged in as **${user['login'] ?? 'unknown'}**\n'
            'Name: ${user['name'] ?? '—'}\n'
            'Public repos: ${user['public_repos'] ?? '—'}';
      } catch (e) {
        return 'Failed to fetch profile: $e';
      }
    }

    final createMatch = RegExp(
      r'create\s+(?:a\s+)?repo(?:sitory)?\s+(?:named\s+|called\s+)?([a-zA-Z0-9_.-]+)',
      caseSensitive: false,
    ).firstMatch(userMessage);
    if (createMatch != null) {
      final name = createMatch.group(1)!;
      try {
        final res = await github.createRepo(name);
        final url = res['html_url'] ?? 'created';
        return 'Repository **$name** created.\n$url';
      } catch (e) {
        return 'Failed to create repo: $e';
      }
    }

    return chat(userMessage, history: history);
  }

  String _simulate(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('repo') || lower.contains('list')) {
      return 'Simulation mode — sample repositories:\n\n'
          '• helix-user/helix-core (public) ★128\n'
          '• helix-user/pulse-api (private) ★4\n'
          '• helix-user/glass-ui (public) ★42\n\n'
          'Add a GitHub token in Settings for live data.';
    }
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hello. I am Helix, your glassmorphism GitHub agent.\n'
          'Add a Gemini API key and GitHub token in Settings to unlock full control.';
    }
    return 'Simulation mode active.\n'
        'I can list repos, check profile, create repositories, and chat once you add keys in Settings.\n'
        'Gemini key + GitHub token required for live mode.';
  }
}
