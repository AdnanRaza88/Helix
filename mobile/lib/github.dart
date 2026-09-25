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
    if (!isLive) return _sim('GET', path, null);
    final res = await http.get(Uri.parse('$_api$path'), headers: _headers);
    if (res.statusCode >= 400) {
      throw Exception('GitHub ${res.statusCode}: ${res.body}');
    }
    return res.body.isEmpty ? {} : jsonDecode(res.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (!isLive) return _sim('POST', path, body);
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

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    if (!isLive) return _sim('PUT', path, body);
    final res = await http.put(
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
    final data = await get(
        '/user/repos?sort=updated&per_page=$perPage&affiliation=owner,collaborator');
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> getUser() async {
    final data = await get('/user');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> getRepo(String owner, String repo) async {
    final data = await get('/repos/$owner/$repo');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<dynamic>> listIssues(String owner, String repo,
      {String state = 'open'}) async {
    final data = await get('/repos/$owner/$repo/issues?state=$state&per_page=30');
    return data is List ? data : [];
  }

  Future<dynamic> createIssue(String owner, String repo, String title,
      {String body = ''}) {
    return post('/repos/$owner/$repo/issues', {
      'title': title,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> getFile(String owner, String repo, String path,
      {String? ref}) async {
    final q = ref == null || ref.isEmpty ? '' : '?ref=$ref';
    final data = await get('/repos/$owner/$repo/contents/$path$q');
    if (data is! Map<String, dynamic>) return {};
    final encoded = data['content']?.toString().replaceAll('\n', '') ?? '';
    if (encoded.isNotEmpty && data['encoding'] == 'base64') {
      try {
        data['decoded'] = utf8.decode(base64Decode(encoded));
      } catch (_) {}
    }
    return data;
  }

  Future<dynamic> putFile(
    String owner,
    String repo,
    String path,
    String content,
    String message, {
    String? branch,
    String? sha,
  }) {
    final body = <String, dynamic>{
      'message': message,
      'content': base64Encode(utf8.encode(content)),
    };
    if (branch != null && branch.isNotEmpty) body['branch'] = branch;
    if (sha != null && sha.isNotEmpty) body['sha'] = sha;
    return put('/repos/$owner/$repo/contents/$path', body);
  }

  Future<Map<String, dynamic>> listTree(String owner, String repo,
      {String ref = 'HEAD', bool recursive = true}) async {
    final rec = recursive ? '?recursive=1' : '';
    final data = await get('/repos/$owner/$repo/git/trees/$ref$rec');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> searchCode(String query) async {
    final q = Uri.encodeQueryComponent(query);
    final data = await get('/search/code?q=$q&per_page=15');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<dynamic> createRepo(String name,
      {String? description, bool private = false}) {
    return post('/user/repos', {
      'name': name,
      'description': description ?? '',
      'private': private,
      'auto_init': true,
    });
  }

  dynamic _sim(String method, String path, Map<String, dynamic>? body) {
    if (path == '/user') {
      return {
        'login': 'helix-user',
        'name': 'Helix Pilot',
        'public_repos': 5,
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
        },
        {
          'full_name': 'helix-user/pulse-api',
          'name': 'pulse-api',
          'description': 'Private telemetry API.',
          'private': true,
          'language': 'Go',
          'stargazers_count': 4,
        },
        {
          'full_name': 'helix-user/glass-ui',
          'name': 'glass-ui',
          'description': 'Glassmorphism component kit.',
          'private': false,
          'language': 'Dart',
          'stargazers_count': 42,
        },
      ];
    }
    return {
      'ok': true,
      'simulated': true,
      'method': method,
      'path': path,
      if (body != null) 'body': body,
    };
  }
}
