class GithubSchemas {
  static const declarations = <Map<String, dynamic>>[
    {
      'name': 'github_get_user',
      'description': 'Get the authenticated GitHub user profile.',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    },
    {
      'name': 'github_list_repos',
      'description': 'List repositories for the authenticated user.',
      'parameters': {
        'type': 'object',
        'properties': {
          'per_page': {'type': 'integer', 'description': 'Max repos, default 30'},
        },
      },
    },
    {
      'name': 'github_get_repo',
      'description': 'Get a single repository by owner and name.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_list_issues',
      'description': 'List issues in a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'state': {'type': 'string', 'description': 'open, closed, or all'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_create_issue',
      'description': 'Create an issue. Host will confirm before write.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'title': {'type': 'string'},
          'body': {'type': 'string'},
        },
        'required': ['owner', 'repo', 'title'],
      },
    },
    {
      'name': 'github_get_file',
      'description': 'Get file contents at a path in a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'path': {'type': 'string'},
          'ref': {'type': 'string', 'description': 'Branch, tag, or SHA'},
        },
        'required': ['owner', 'repo', 'path'],
      },
    },
    {
      'name': 'github_put_file',
      'description': 'Create or update a file. Host will confirm before write.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'path': {'type': 'string'},
          'content': {'type': 'string', 'description': 'Plain text file body'},
          'message': {'type': 'string'},
          'branch': {'type': 'string'},
          'sha': {'type': 'string', 'description': 'Existing blob SHA when updating'},
        },
        'required': ['owner', 'repo', 'path', 'content', 'message'],
      },
    },
    {
      'name': 'github_list_tree',
      'description': 'List git tree for a repository ref.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'ref': {'type': 'string', 'description': 'Branch or SHA, default HEAD'},
          'recursive': {'type': 'boolean'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_search_code',
      'description': 'Search code with GitHub code search syntax.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    },
    {
      'name': 'github_list_pulls',
      'description': 'List pull requests in a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'state': {'type': 'string', 'description': 'open, closed, or all'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_get_pull',
      'description': 'Get one pull request by number.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'number': {'type': 'integer'},
        },
        'required': ['owner', 'repo', 'number'],
      },
    },
    {
      'name': 'github_create_pull',
      'description': 'Open a pull request. Host will confirm before write.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'title': {'type': 'string'},
          'head': {'type': 'string', 'description': 'Source branch'},
          'base': {'type': 'string', 'description': 'Target branch'},
          'body': {'type': 'string'},
        },
        'required': ['owner', 'repo', 'title', 'head', 'base'],
      },
    },
    {
      'name': 'github_list_branches',
      'description': 'List branches in a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_create_branch',
      'description': 'Create a branch from an existing ref. Host will confirm.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'branch': {'type': 'string', 'description': 'New branch name'},
          'from': {'type': 'string', 'description': 'Source branch, default main'},
        },
        'required': ['owner', 'repo', 'branch'],
      },
    },
    {
      'name': 'github_list_workflows',
      'description': 'List GitHub Actions workflows in a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_list_workflow_runs',
      'description': 'List recent Actions workflow runs.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'workflow_id': {
            'type': 'string',
            'description': 'Optional workflow id or file name'
          },
        },
        'required': ['owner', 'repo'],
      },
    },
    {
      'name': 'github_trigger_workflow',
      'description': 'Dispatch a workflow_dispatch workflow. Host will confirm.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'workflow_id': {
            'type': 'string',
            'description': 'Workflow file name or numeric id'
          },
          'ref': {'type': 'string', 'description': 'Branch or tag, default main'},
        },
        'required': ['owner', 'repo', 'workflow_id'],
      },
    },
    {
      'name': 'github_review_code',
      'description':
          'Fetch a file and return a structured code review (Summary, severity findings, patches, tests, security).',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'path': {'type': 'string'},
          'ref': {'type': 'string'},
          'focus': {'type': 'string', 'description': 'Optional review focus'},
        },
        'required': ['owner', 'repo', 'path'],
      },
    },
    {
      'name': 'github_delete_file',
      'description':
          'Delete one file. Hard confirm required. Never use for mass delete.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'path': {'type': 'string'},
          'message': {'type': 'string'},
          'sha': {'type': 'string', 'description': 'Blob SHA of the file'},
          'branch': {'type': 'string'},
        },
        'required': ['owner', 'repo', 'path', 'message', 'sha'],
      },
    },
    {
      'name': 'github_delete_branch',
      'description':
          'Delete a non-default branch. Hard confirm. Refuses main/master.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'branch': {'type': 'string'},
        },
        'required': ['owner', 'repo', 'branch'],
      },
    },
    {
      'name': 'github_close_issue',
      'description': 'Close an issue by number. Hard confirm required.',
      'parameters': {
        'type': 'object',
        'properties': {
          'owner': {'type': 'string'},
          'repo': {'type': 'string'},
          'number': {'type': 'integer'},
        },
        'required': ['owner', 'repo', 'number'],
      },
    },
  ];

  static const confirmNames = {
    'github_create_issue',
    'github_put_file',
    'github_create_pull',
    'github_create_branch',
    'github_trigger_workflow',
    'github_delete_file',
    'github_delete_branch',
    'github_close_issue',
  };

  static const hardConfirmNames = {
    'github_delete_file',
    'github_delete_branch',
    'github_close_issue',
  };

  static bool needsConfirm(String name) => confirmNames.contains(name);

  static bool isHardConfirm(String name) => hardConfirmNames.contains(name);
}
