class ContextCompactor {
  static const int maxHistoryChars = 24000;
  static const int keepLastTurns = 8;

  static List<Map<String, String>> compact(List<Map<String, String>> history) {
    if (history.isEmpty) return const [];
    var total = 0;
    for (final m in history) {
      total += (m['text'] ?? '').length;
    }
    if (total <= maxHistoryChars && history.length <= keepLastTurns * 2) {
      return List<Map<String, String>>.from(history);
    }

    final keepCount = keepLastTurns * 2;
    if (history.length <= keepCount) {
      return List<Map<String, String>>.from(history);
    }

    final older = history.sublist(0, history.length - keepCount);
    final recent = history.sublist(history.length - keepCount);
    final summary = _summarize(older);
    return [
      {'role': 'user', 'text': summary},
      ...recent,
    ];
  }

  static String _summarize(List<Map<String, String>> older) {
    final goals = <String>[];
    final decisions = <String>[];
    for (final m in older) {
      final t = (m['text'] ?? '').trim();
      if (t.isEmpty) continue;
      final clip = t.length > 160 ? '${t.substring(0, 160)}…' : t;
      if (m['role'] == 'user') {
        goals.add(clip);
      } else {
        decisions.add(clip);
      }
    }
    final g = goals.take(6).map((e) => '- $e').join('\n');
    final d = decisions.take(6).map((e) => '- $e').join('\n');
    return 'Previous context (compacted)\nGoals:\n${g.isEmpty ? '- none' : g}\nDecisions:\n${d.isEmpty ? '- none' : d}';
  }
}
