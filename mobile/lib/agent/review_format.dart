class ReviewFormat {
  static const template = '''
## Review
### Summary
- (one paragraph)

### Critical
- none | finding + file:line

### High
- none | finding

### Medium
- none | finding

### Low
- none | finding

### Suggested patches
- minimal diff notes

### Test gaps
- missing coverage

### Security
- tokens, auth, injection, secrets
''';

  static String skeleton({
    required String owner,
    required String repo,
    required String path,
    String? ref,
    String? focus,
    String? excerpt,
  }) {
    final head = '$owner/$repo `$path`${ref == null || ref.isEmpty ? '' : ' @$ref'}';
    final focusLine = (focus == null || focus.isEmpty) ? '' : 'Focus: $focus\n';
    final body = excerpt == null || excerpt.isEmpty
        ? ''
        : excerpt.length > 8000
            ? excerpt.substring(0, 8000)
            : excerpt;
    return '''
Target: $head
$focusLine
Use this structure in the next model reply (do not invent SHAs):
$template
--- file excerpt ---
$body
''';
  }
}
