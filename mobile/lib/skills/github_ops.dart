import 'dart:convert';

import '../github.dart';
import 'github_schemas.dart';

class GithubOps {
  GithubOps(this.client);
  final GitHubClient client;

  Future<String> run(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'github_get_user':
        return _encode(await client.getUser());
      case 'github_list_repos':
        final n = _int(args['per_page'], 30);
        return _encode(await client.listRepos(perPage: n));
      case 'github_get_repo':
        return _encode(await client.getRepo(_str(args['owner']), _str(args['repo'])));
      case 'github_list_issues':
        return _encode(await client.listIssues(
          _str(args['owner']),
          _str(args['repo']),
          state: _str(args['state'], 'open'),
        ));
      case 'github_create_issue':
        return _encode(await client.createIssue(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['title']),
          body: _str(args['body'], ''),
        ));
      case 'github_get_file':
        return _encode(await client.getFile(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['path']),
          ref: args['ref']?.toString(),
        ));
      case 'github_put_file':
        return _encode(await client.putFile(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['path']),
          _str(args['content']),
          _str(args['message']),
          branch: args['branch']?.toString(),
          sha: args['sha']?.toString(),
        ));
      case 'github_list_tree':
        return _encode(await client.listTree(
          _str(args['owner']),
          _str(args['repo']),
          ref: _str(args['ref'], 'HEAD'),
          recursive: args['recursive'] == true,
        ));
      case 'github_search_code':
        return _encode(await client.searchCode(_str(args['query'])));
      default:
        return jsonEncode({'error': 'Unknown tool $name'});
    }
  }

  String confirmSummary(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'github_create_issue':
        return 'Create issue "${args['title']}" on ${args['owner']}/${args['repo']}';
      case 'github_put_file':
        return 'Write ${args['path']} on ${args['owner']}/${args['repo']}\nCommit: ${args['message']}';
      default:
        return name;
    }
  }

  static bool needsConfirm(String name) => GithubSchemas.needsConfirm(name);

  String _encode(dynamic data) {
    final prefix = client.isLive ? '' : '[SIM] ';
    if (data is List) {
      final clipped = data.take(25).toList();
      return '$prefix${jsonEncode(clipped)}';
    }
    return '$prefix${jsonEncode(data)}';
  }

  String _str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  int _int(dynamic v, int fallback) {
    if (v is int) return v;
    return int.tryParse('$v') ?? fallback;
  }
}
