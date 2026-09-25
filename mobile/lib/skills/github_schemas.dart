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
  ];

  static bool needsConfirm(String name) {
    return name == 'github_create_issue' || name == 'github_put_file';
  }
}
