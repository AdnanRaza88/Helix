import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/session_repo.dart';

export 'data/models.dart';

class SessionStore {
  static const _legacyKey = 'helix_chat_sessions_v1';
  static const _activeKey = 'helix_active_session_id';
  static const _migratedKey = 'helix_sessions_sqlite_v1';
  static const _activeRepoKey = 'helix_active_repo';

  final SessionRepo _repo = SessionRepo();
  bool _migrated = false;

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) {
      _migrated = true;
      return;
    }
    final raw = prefs.getString(_legacyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        final sessions = list
            .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (sessions.isNotEmpty) {
          await _repo.replaceAll(sessions);
        }
      } catch (_) {}
    }
    await prefs.setBool(_migratedKey, true);
    _migrated = true;
  }

  Future<List<ChatSession>> loadAll() async {
    await _ensureMigrated();
    final list = await _repo.listSessions();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveAll(List<ChatSession> sessions) async {
    await _ensureMigrated();
    await _repo.replaceAll(sessions);
  }

  Future<String?> getActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  Future<String?> getActiveRepo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeRepoKey);
  }

  Future<void> setActiveRepo(String? ownerRepo) async {
    final prefs = await SharedPreferences.getInstance();
    if (ownerRepo == null || ownerRepo.isEmpty) {
      await prefs.remove(_activeRepoKey);
    } else {
      await prefs.setString(_activeRepoKey, ownerRepo);
    }
  }

  String exportSession(ChatSession session) {
    return const JsonEncoder.withIndent('  ').convert(session.toJson());
  }

  String exportAll(List<ChatSession> sessions) {
    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
    });
  }

  String newId() => _repo.newId();

  String titleFromFirstMessage(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= 36) return t.isEmpty ? 'New chat' : t;
    return '${t.substring(0, 36)}…';
  }
}
