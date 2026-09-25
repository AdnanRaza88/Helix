import 'dart:convert';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? at,
    String? id,
    this.status = 'done',
    this.parentId,
    this.editedAt,
    List<String>? tools,
    List<String>? attachments,
  })  : at = at ?? DateTime.now(),
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        tools = tools ?? [],
        attachments = attachments ?? [];

  final String id;
  final String role;
  String text;
  final DateTime at;
  String status;
  String? parentId;
  DateTime? editedAt;
  final List<String> tools;
  final List<String> attachments;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'at': at.toIso8601String(),
        'status': status,
        if (parentId != null) 'parent_id': parentId,
        if (editedAt != null) 'edited_at': editedAt!.toIso8601String(),
        if (tools.isNotEmpty) 'tools': tools,
        if (attachments.isNotEmpty) 'attachments': attachments,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        role: j['role'] as String? ?? 'user',
        text: (j['text'] as String?) ?? (j['content'] as String?) ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        status: j['status'] as String? ?? 'done',
        parentId: j['parent_id'] as String?,
        editedAt: DateTime.tryParse(j['edited_at'] as String? ?? ''),
        tools: ((j['tools'] as List?) ?? []).map((e) => '$e').toList(),
        attachments:
            ((j['attachments'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    DateTime? createdAt,
    this.pinned = false,
    this.model,
    this.meta,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  final List<ChatMessage> messages;
  DateTime updatedAt;
  DateTime createdAt;
  bool pinned;
  String? model;
  String? meta;

  Map<String, dynamic> metaMap() {
    if (meta == null || meta!.isEmpty) return {};
    try {
      final v = jsonDecode(meta!);
      return v is Map<String, dynamic> ? Map<String, dynamic>.from(v) : {};
    } catch (_) {
      return {};
    }
  }

  String? get activeRepo {
    final m = metaMap();
    final o = (m['owner'] ?? '').toString();
    final r = (m['repo'] ?? '').toString();
    if (o.isEmpty || r.isEmpty) return null;
    return '$o/$r';
  }

  void setActiveRepo(String owner, String repo) {
    final m = metaMap();
    m['owner'] = owner;
    m['repo'] = repo;
    meta = jsonEncode(m);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'pinned': pinned,
        if (model != null) 'model': model,
        if (meta != null) 'meta': meta,
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Chat',
        updatedAt:
            DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        pinned: j['pinned'] == true || j['pinned'] == 1,
        model: j['model'] as String?,
        meta: j['meta'] as String?,
        messages: ((j['messages'] as List?) ?? [])
            .map((e) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  List<Map<String, String>> historyForApi() => messages
      .where((m) => m.role == 'user' || m.role == 'model')
      .map((m) => {'role': m.role, 'text': m.text})
      .toList();
}
