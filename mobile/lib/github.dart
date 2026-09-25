import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubClient {
  GitHubClient({required this.token, this.simulate = true});

  final String token;
  final bool simulate;
  static const _api = 'https://api.github.com';

  Future<dynamic> get(String path) async {
    if (simulate || token.isEmpty) {
      return _sim(path);
    }
    final res = await http.get(
      Uri.parse('$_api$path'),
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Helix-GitHub-Agent',
      },
    );
    if (res.statusCode >= 400) {
      throw Exception(res.body);
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (simulate || token.isEmpty) {
      return {'ok': true, 'simulated': true, 'path': path, 'body': body};
    }
    final res = await http.post(
      Uri.parse('$_api$path'),
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'User-Agent': 'Helix-GitHub-Agent',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception(res.body);
    }
    return res.body.isEmpty ? {'ok': true} : jsonDecode(res.body);
  }

  dynamic _sim(String path) {
    if (path == '/user') {
      return {
        'login': 'lumen-pilot',
        'name': 'Lumen Pilot',
        'public_repos': 3,
      };
    }
    if (path.startsWith('/user/repos')) {
      return [
        {
          'full_name': 'lumen-pilot/helix-core',
          'description': 'Multi-agent GitHub command runtime.',
          'private': false,
          'language': 'TypeScript',
          'stargazers_count': 128,
        },
        {
          'full_name': 'lumen-pilot/pulse-api',
          'description': 'Private telemetry API.',
          'private': true,
          'language': 'Go',
          'stargazers_count': 4,
        },
      ];
    }
    return [];
  }
}
