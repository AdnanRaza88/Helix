import 'package:flutter_test/flutter_test.dart';
import 'package:helix/data/models.dart';

void main() {
  test('session json roundtrip and active repo', () {
    final s = ChatSession(id: 'a', title: 't');
    s.messages.add(ChatMessage(role: 'user', text: 'hi'));
    s.setActiveRepo('AdnanRaza88', 'Helix');
    final copy = ChatSession.fromJson(s.toJson());
    expect(copy.id, 'a');
    expect(copy.activeRepo, 'AdnanRaza88/Helix');
    expect(copy.historyForApi().single['text'], 'hi');
  });
}
