import '../skills/github_ops.dart';
import '../skills/github_schemas.dart';

typedef MutationConfirm = Future<bool> Function(String title, String detail);

class ToolRouter {
  ToolRouter({required this.ops, this.confirm});

  final GithubOps ops;
  MutationConfirm? confirm;

  List<Map<String, dynamic>> get functionDeclarations =>
      GithubSchemas.declarations;

  Future<String> dispatch(String name, Map<String, dynamic> args) async {
    if (GithubOps.needsConfirm(name) && confirm != null) {
      final ok = await confirm!(
        'Confirm $name',
        ops.confirmSummary(name, args),
      );
      if (!ok) return '{"cancelled":true,"tool":"$name"}';
    }
    return ops.run(name, args);
  }
}
