import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubClient {
  GitHubClient({required this.token});

  final String token;
  static const _api = 'https://api.github.com';

  bool get isLive => token.isNotEmpty;

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Helix-GitHub-Agent',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<dynamic> get(String path) async {
    if (!isLive) return _sim(path);
    final res = await http.get(Uri.parse('$_api$path'), headers: _headers);
    if (res.statusCode >= 400) {
      throw Exception('GitHub ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (!isLive) {
      return {'ok': true, 'simulated': true, 'path': path, 'body': body};
    }
    final res = await http.post(
      Uri.parse('$_api$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('GitHub ${res.statusCode}: ${res.body}');
    }
    return res.body.isEmpty ? {'ok': true} : jsonDecode(res.body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    if (!isLive) {
      return {'ok': true, 'simulated': true, 'path': path, 'body': body};
    }
    final res = await http.patch(
      Uri.parse('$_api$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('GitHub ${res.statusCode}: ${res.body}');
    }
    return res.body.isEmpty ? {'ok': true} : jsonDecode(res.body);
  }

  Future<List<dynamic>> listRepos({int perPage = 30}) async {
    final data = await get('/user/repos?sort=updated&per_page=$perPage&affiliation=owner,collaborator');
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> getUser() async {
    final data = await get('/user');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<dynamic> createIssue(String owner, String repo, String title, String body) {
    return post('/repos/$owner/$repo/issues', {'title': title, 'body': body});
  }

  Future<dynamic> createRepo(String name, {String? description, bool private = false}) {
    return post('/user/repos', {
      'name': name,
      'description': description ?? '',
      'private': private,
      'auto_init': true,
    });
  }

  dynamic _sim(String path) {
    if (path == '/user') {
      return {
        'login': 'helix-user',
        'name': 'Helix Pilot',
        'public_repos': 5,
        'avatar_url': '',
      };
    }
    if (path.startsWith('/user/repos')) {
      return [
        {
          'full_name': 'helix-user/helix-core',
          'name': 'helix-core',
          'description': 'Multi-agent GitHub command runtime.',
          'private': false,
          'language': 'TypeScript',
          'stargazers_count': 128,
          'html_url': 'https://github.com/helix-user/helix-core',
        },
        {
          'full_name': 'helix-user/pulse-api',
          'name': 'pulse-api',
          'description': 'Private telemetry API.',
          'private': true,
          'language': 'Go',
          'stargazers_count': 4,
          'html_url': 'https://github.com/helix-user/pulse-api',
        },
        {
          'full_name': 'helix-user/glass-ui',
          'name': 'glass-ui',
          'description': 'Glassmorphism component kit.',
          'private': false,
          'language': 'Dart',
          'stargazers_count': 42,
          'html_url': 'https://github.com/helix-user/glass-ui',
        },
      ];
    }
    return [];
  }
}
