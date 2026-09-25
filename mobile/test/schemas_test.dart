import 'package:flutter_test/flutter_test.dart';
import 'package:helix/skills/github_schemas.dart';

void main() {
  test('every declaration name is unique', () {
    final names = GithubSchemas.declarations.map((d) => d['name'] as String).toList();
    expect(names.toSet().length, names.length);
  });

  test('hard confirm tools are a subset of confirm tools', () {
    expect(
      GithubSchemas.hardConfirmNames.every(GithubSchemas.confirmNames.contains),
      isTrue,
    );
    expect(GithubSchemas.isHardConfirm('github_delete_file'), isTrue);
    expect(GithubSchemas.isHardConfirm('github_put_file'), isFalse);
    expect(GithubSchemas.needsConfirm('github_close_issue'), isTrue);
  });
}
