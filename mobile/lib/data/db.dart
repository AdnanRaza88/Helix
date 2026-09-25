import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class HelixDb {
  HelixDb._();
  static final HelixDb instance = HelixDb._();
  static const schemaVersion = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'helix.db');
    _db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  pinned INTEGER DEFAULT 0,
  model TEXT,
  meta TEXT
)''');
        await db.execute('''
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  edited_at INTEGER,
  parent_id TEXT,
  status TEXT DEFAULT 'done',
  FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE tool_runs (
  id TEXT PRIMARY KEY,
  message_id TEXT,
  session_id TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  args_json TEXT,
  result_json TEXT,
  status TEXT,
  created_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE attachments (
  id TEXT PRIMARY KEY,
  message_id TEXT,
  session_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  name TEXT,
  mime TEXT,
  local_path TEXT,
  size INTEGER,
  created_at INTEGER NOT NULL
)''');
        await db.execute(
          'CREATE INDEX idx_messages_session ON messages(session_id, created_at)',
        );
        await db.execute(
          'CREATE INDEX idx_tool_runs_session ON tool_runs(session_id)',
        );
      },
    );
    return _db!;
  }
}
