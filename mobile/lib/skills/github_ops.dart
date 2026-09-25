import 'dart:convert';

import '../agent/review_format.dart';
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
      case 'github_list_pulls':
        return _encode(await client.listPulls(
          _str(args['owner']),
          _str(args['repo']),
          state: _str(args['state'], 'open'),
        ));
      case 'github_get_pull':
        return _encode(await client.getPull(
          _str(args['owner']),
          _str(args['repo']),
          _int(args['number'], 0),
        ));
      case 'github_create_pull':
        return _encode(await client.createPull(
          _str(args['owner']),
          _str(args['repo']),
          title: _str(args['title']),
          head: _str(args['head']),
          base: _str(args['base']),
          body: _str(args['body'], ''),
        ));
      case 'github_list_branches':
        return _encode(await client.listBranches(
          _str(args['owner']),
          _str(args['repo']),
        ));
      case 'github_create_branch':
        return _encode(await client.createBranch(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['branch']),
          _str(args['from'], 'main'),
        ));
      case 'github_list_workflows':
        return _encode(await client.listWorkflows(
          _str(args['owner']),
          _str(args['repo']),
        ));
      case 'github_list_workflow_runs':
        return _encode(await client.listWorkflowRuns(
          _str(args['owner']),
          _str(args['repo']),
          workflowId: args['workflow_id']?.toString(),
        ));
      case 'github_trigger_workflow':
        return _encode(await client.triggerWorkflow(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['workflow_id']),
          _str(args['ref'], 'main'),
        ));
      case 'github_review_code':
        final file = await client.getFile(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['path']),
          ref: args['ref']?.toString(),
        );
        final excerpt = file['decoded']?.toString() ?? file['content']?.toString() ?? '';
        return ReviewFormat.skeleton(
          owner: _str(args['owner']),
          repo: _str(args['repo']),
          path: _str(args['path']),
          ref: args['ref']?.toString(),
          focus: args['focus']?.toString(),
          excerpt: excerpt,
        );
      case 'github_delete_file':
        return _encode(await client.deleteFile(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['path']),
          _str(args['message']),
          _str(args['sha']),
          branch: args['branch']?.toString(),
        ));
      case 'github_delete_branch':
        return _encode(await client.deleteBranch(
          _str(args['owner']),
          _str(args['repo']),
          _str(args['branch']),
        ));
      case 'github_close_issue':
        return _encode(await client.closeIssue(
          _str(args['owner']),
          _str(args['repo']),
          _int(args['number'], 0),
        ));
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
      case 'github_create_pull':
        return 'Open PR "${args['title']}" ${args['head']} -> ${args['base']} on ${args['owner']}/${args['repo']}';
      case 'github_create_branch':
        return 'Create branch ${args['branch']} from ${args['from'] ?? 'main'} on ${args['owner']}/${args['repo']}';
      case 'github_trigger_workflow':
        return 'Dispatch workflow ${args['workflow_id']} on ${args['owner']}/${args['repo']} @ ${args['ref'] ?? 'main'}';
      case 'github_delete_file':
        return 'DELETE FILE ${args['owner']}/${args['repo']}:${args['path']}\nCommit: ${args['message']}\nType DELETE in the sheet.';
      case 'github_delete_branch':
        return 'DELETE BRANCH ${args['branch']} on ${args['owner']}/${args['repo']}\nType DELETE in the sheet.';
      case 'github_close_issue':
        return 'CLOSE ISSUE #${args['number']} on ${args['owner']}/${args['repo']}\nType DELETE in the sheet.';
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
