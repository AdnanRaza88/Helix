import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';

class SessionRepo {
  SessionRepo({HelixDb? db}) : _db = db ?? HelixDb.instance;
  final HelixDb _db;
  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  Future<List<ChatSession>> listSessions() async {
    final db = await _db.database;
    final rows = await db.query('sessions', orderBy: 'updated_at DESC');
    final out = <ChatSession>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final msgs = await db.query(
        'messages',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'created_at ASC',
      );
      out.add(ChatSession(
        id: id,
        title: row['title'] as String? ?? 'Chat',
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        pinned: (row['pinned'] as int? ?? 0) == 1,
        model: row['model'] as String?,
        meta: row['meta'] as String?,
        messages: msgs.map((m) => _fromRow(m)).toList(),
      ));
    }
    return out;
  }

  ChatMessage _fromRow(Map<String, Object?> m) {
    var text = m['content'] as String? ?? '';
    final tools = <String>[];
    final attachments = <String>[];
    final toolMatch = RegExp(r'\n__tools__:([^\n]*)\s*$');
    final fileMatch = RegExp(r'\n__files__:([^\n]*)\s*$');
    final fm = fileMatch.firstMatch(text);
    if (fm != null) {
      attachments.addAll(
        fm.group(1)!.split(',').where((e) => e.trim().isNotEmpty),
      );
      text = text.replaceFirst(fileMatch, '');
    }
    final tm = toolMatch.firstMatch(text);
    if (tm != null) {
      tools.addAll(tm.group(1)!.split(',').where((e) => e.trim().isNotEmpty));
      text = text.replaceFirst(toolMatch, '');
    }
    return ChatMessage(
      id: m['id'] as String,
      role: m['role'] as String,
      text: text,
      at: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      status: m['status'] as String? ?? 'done',
      parentId: m['parent_id'] as String?,
      editedAt: m['edited_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['edited_at'] as int),
      tools: tools,
      attachments: attachments,
    );
  }

  String _encode(ChatMessage m) {
    var text = m.text;
    if (m.tools.isNotEmpty) text += '\n__tools__:${m.tools.join(',')}';
    if (m.attachments.isNotEmpty) {
      text += '\n__files__:${m.attachments.join(',')}';
    }
    return text;
  }

  Future<void> replaceAll(List<ChatSession> sessions) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('sessions');
      for (final s in sessions) {
        await txn.insert('sessions', {
          'id': s.id,
          'title': s.title,
          'created_at': s.createdAt.millisecondsSinceEpoch,
          'updated_at': s.updatedAt.millisecondsSinceEpoch,
          'pinned': s.pinned ? 1 : 0,
          'model': s.model,
          'meta': s.meta,
        });
        for (final m in s.messages) {
          await txn.insert('messages', {
            'id': m.id,
            'session_id': s.id,
            'role': m.role,
            'content': _encode(m),
            'created_at': m.at.millisecondsSinceEpoch,
            'edited_at': m.editedAt?.millisecondsSinceEpoch,
            'parent_id': m.parentId,
            'status': m.status,
          });
        }
      }
    });
  }
}
