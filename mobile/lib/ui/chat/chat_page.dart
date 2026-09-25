import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../gemini.dart';
import '../../sessions.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.gemini});
  final GeminiClient gemini;
  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final store = SessionStore();
  final controller = TextEditingController();
  final scroll = ScrollController();
  List<ChatSession> sessions = [];
  ChatSession? active;
  bool sending = false;
  bool showDrawer = false;
  final pendingFiles = <_Attach>[];
  StreamAbort? abort;

  @override
  void initState() {
    super.initState();
    widget.gemini.bindConfirm(_confirmMutation);
    _loadSessions();
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.gemini.bindConfirm(_confirmMutation);
  }

  @override
  void dispose() {
    abort?.cancel();
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmMutation(String title, String detail) async {
    if (!mounted) return false;
    final hard = title.startsWith('HARD');
    final phrase = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          final typed = phrase.text.trim().toUpperCase() == 'DELETE';
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  color: H.bgDeep.withValues(alpha: 0.92),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: TextStyle(color: hard ? H.pink : H.text, fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(detail, style: const TextStyle(color: H.textMuted, fontSize: 14, height: 1.4)),
                      if (hard) ...[
                        const SizedBox(height: 12),
                        const Text('Type DELETE to enable confirm.', style: TextStyle(color: H.pink, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phrase,
                          onChanged: (_) => setLocal(() {}),
                          style: const TextStyle(color: H.text),
                          decoration: const InputDecoration(hintText: 'DELETE', hintStyle: TextStyle(color: H.textMuted)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: (!hard || typed) ? () => Navigator.pop(ctx, true) : null,
                            style: FilledButton.styleFrom(backgroundColor: hard ? H.pink : H.purple),
                            child: Text(hard ? 'Delete' : 'Confirm'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
    phrase.dispose();
    return result == true;
  }

  Future<void> _exportSession() async {
    if (active == null) return;
    final json = store.exportSession(active!);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session JSON copied'), duration: Duration(seconds: 2)));
  }

  Future<void> _loadSessions() async {
    final all = await store.loadAll();
    final activeId = await store.getActiveId();
    ChatSession? current;
    if (activeId != null) {
      for (final s in all) {
        if (s.id == activeId) { current = s; break; }
      }
    }
    current ??= all.isNotEmpty ? all.first : null;
    setState(() { sessions = all; active = current; });
  }

  Future<void> _persist() async {
    if (active != null) {
      final idx = sessions.indexWhere((s) => s.id == active!.id);
      if (idx >= 0) sessions[idx] = active!;
      else sessions.insert(0, active!);
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await store.saveAll(sessions);
    await store.setActiveId(active?.id);
  }

  Future<void> _newChat() async {
    final s = ChatSession(id: store.newId(), title: 'New chat');
    setState(() { active = s; sessions = [s, ...sessions]; showDrawer = false; });
    await _persist();
  }

  Future<void> _selectSession(ChatSession s) async {
    setState(() { active = s; showDrawer = false; });
    await store.setActiveId(s.id);
  }

  Future<void> _deleteSession(ChatSession s) async {
    sessions.removeWhere((e) => e.id == s.id);
    if (active?.id == s.id) active = sessions.isNotEmpty ? sessions.first : null;
    setState(() {});
    await _persist();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      String excerpt = '';
      if (f.path != null) {
        try {
          final file = File(f.path!);
          final bytes = await file.length();
          if (bytes < 80 * 1024) {
            excerpt = await file.readAsString();
            if (excerpt.length > 6000) excerpt = excerpt.substring(0, 6000);
          }
        } catch (_) {}
      }
      pendingFiles.add(_Attach(f.name, excerpt));
    }
    setState(() {});
  }

  String _composeUserText(String raw) {
    if (pendingFiles.isEmpty) return raw;
    final buf = StringBuffer(raw);
    for (final f in pendingFiles) {
      buf.writeln('\n\nAttached `${f.name}`:');
      if (f.excerpt.isNotEmpty) {
        buf.writeln('```');
        buf.writeln(f.excerpt);
        buf.writeln('```');
      }
    }
    return buf.toString();
  }

  Future<void> _send({String? override, String? parentId}) async {
    final typed = override ?? controller.text.trim();
    if ((typed.isEmpty && pendingFiles.isEmpty) || sending) return;
    final names = pendingFiles.map((e) => e.name).toList();
    final text = _composeUserText(typed.isEmpty ? 'See attached files.' : typed);
    pendingFiles.clear();
    active ??= ChatSession(id: store.newId(), title: store.titleFromFirstMessage(text));
    if (active!.messages.isEmpty) active!.title = store.titleFromFirstMessage(text);
    final userMsg = ChatMessage(role: 'user', text: text, parentId: parentId, attachments: names);
    final modelMsg = ChatMessage(role: 'model', text: '', status: 'streaming');
    setState(() {
      active!.messages.add(userMsg);
      active!.messages.add(modelMsg);
      active!.updatedAt = DateTime.now();
      sending = true;
    });
    if (override == null) controller.clear();
    _scrollEnd();
    await _persist();
    abort = StreamAbort();
    try {
      final history = active!.historyForApi();
      final prior = history.length > 2 ? history.sublist(0, history.length - 2) : <Map<String, String>>[];
      final reply = await widget.gemini.runWithTools(
        text,
        history: prior,
        abort: abort,
        onDelta: (d) {
          if (!mounted) return;
          setState(() => modelMsg.text += d);
          _scrollEnd();
        },
        onTool: (name) {
          if (!mounted) return;
          setState(() => modelMsg.tools.add(name));
        },
      );
      setState(() {
        if (modelMsg.text.isEmpty) modelMsg.text = reply;
        modelMsg.status = 'done';
        sending = false;
      });
    } catch (e) {
      setState(() {
        modelMsg.text = modelMsg.text.isEmpty ? 'Error: $e' : modelMsg.text;
        modelMsg.status = 'error';
        sending = false;
      });
    }
    await _persist();
    _scrollEnd();
  }

  void _stop() {
    abort?.cancel();
    widget.gemini.stop();
    setState(() => sending = false);
  }

  Future<void> _copy(ChatMessage m) async {
    await Clipboard.setData(ClipboardData(text: m.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    active?.messages.removeWhere((e) => e.id == m.id);
    setState(() {});
    await _persist();
  }

  Future<void> _edit(ChatMessage m) async {
    final edit = TextEditingController(text: m.text);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: H.bgMid,
        title: const Text('Edit message', style: TextStyle(color: H.text)),
        content: TextField(controller: edit, maxLines: 6, style: const TextStyle(color: H.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, edit.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    setState(() { m.text = next; m.editedAt = DateTime.now(); });
    await _persist();
  }

  Future<void> _resend(ChatMessage m) async {
    await _send(override: m.text, parentId: m.id);
  }

  Future<void> _retry(ChatMessage m) async {
    final msgs = active?.messages ?? [];
    final idx = msgs.indexWhere((e) => e.id == m.id);
    String? userText;
    if (idx > 0 && msgs[idx - 1].role == 'user') userText = msgs[idx - 1].text;
    if (idx >= 0) msgs.removeAt(idx);
    setState(() {});
    if (userText != null) await _send(override: userText);
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = active?.messages ?? [];
    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            IconButton(onPressed: () => setState(() => showDrawer = !showDrawer), icon: const Icon(Icons.menu_rounded, color: H.text), tooltip: 'Sessions'),
            const Expanded(child: Text('Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: H.text))),
            IconButton(onPressed: _exportSession, icon: const Icon(Icons.ios_share_rounded, color: H.purpleSoft), tooltip: 'Export session'),
            IconButton(onPressed: _newChat, icon: const Icon(Icons.edit_square, color: H.purpleSoft), tooltip: 'New chat'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.gemini.isLive ? H.success.withValues(alpha: 0.2) : H.purple.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.gemini.isLive ? H.success : H.glassBorder),
              ),
              child: Text(widget.gemini.isLive ? 'Gemini Live' : 'Simulation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.gemini.isLive ? H.success : H.purpleSoft)),
            ),
          ]),
        ),
        if (active != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text(active!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: H.textMuted, fontSize: 12))),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(32), child: GlassCard(margin: EdgeInsets.zero, child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, color: H.purpleSoft, size: 36),
                  SizedBox(height: 12),
                  Text('Ask Helix anything', style: TextStyle(color: H.text, fontWeight: FontWeight.w600, fontSize: 17)),
                  SizedBox(height: 8),
                  Text('List repos, open issues, read or write files. Writes ask for confirm.', textAlign: TextAlign.center, style: TextStyle(color: H.textMuted, fontSize: 13, height: 1.5)),
                ]))))
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _bubble(messages[i]),
                ),
        ),
        if (pendingFiles.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: pendingFiles.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(label: Text(f.name, style: const TextStyle(fontSize: 11)), onDeleted: () => setState(() => pendingFiles.remove(f))),
              )).toList(),
            ),
          ),
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
              decoration: BoxDecoration(color: H.bgDeep.withValues(alpha: 0.7), border: const Border(top: BorderSide(color: H.glassBorder, width: 0.8))),
              child: Row(children: [
                IconButton(onPressed: sending ? null : _pickFile, icon: const Icon(Icons.attach_file, color: H.purpleSoft)),
                Expanded(child: TextField(
                  controller: controller,
                  style: const TextStyle(color: H.text),
                  decoration: InputDecoration(
                    hintText: 'Message Helix',
                    hintStyle: const TextStyle(color: H.textMuted),
                    filled: true,
                    fillColor: H.glass,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: H.glassBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: H.glassBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: H.purple, width: 1.4)),
                  ),
                  onSubmitted: (_) => _send(),
                )),
                const SizedBox(width: 8),
                Material(
                  color: sending ? H.pink : H.purple,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: sending ? _stop : _send,
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(width: 46, height: 46, child: Icon(sending ? Icons.stop_rounded : Icons.send_rounded, color: Colors.white, size: 20)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
      if (showDrawer) ...[
        Positioned.fill(child: GestureDetector(onTap: () => setState(() => showDrawer = false), child: Container(color: Colors.black54))),
        Positioned(
          left: 0, top: 0, bottom: 0, width: MediaQuery.of(context).size.width * 0.78,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(color: H.bgDeep.withValues(alpha: 0.92), border: const Border(right: BorderSide(color: H.glassBorder))),
                child: SafeArea(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(children: [
                        const Text('Sessions', style: TextStyle(color: H.text, fontWeight: FontWeight.w700, fontSize: 18)),
                        const Spacer(),
                        IconButton(onPressed: _newChat, icon: const Icon(Icons.add_circle_outline, color: H.purpleSoft)),
                      ]),
                    ),
                    Expanded(
                      child: sessions.isEmpty
                          ? const Center(child: Text('No saved chats yet', style: TextStyle(color: H.textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              itemCount: sessions.length,
                              itemBuilder: (context, i) {
                                final s = sessions[i];
                                final selected = active?.id == s.id;
                                return Dismissible(
                                  key: Key(s.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), color: Colors.red.withValues(alpha: 0.35), child: const Icon(Icons.delete_outline, color: Colors.white)),
                                  onDismissed: (_) => _deleteSession(s),
                                  child: Material(
                                    color: selected ? H.purple.withValues(alpha: 0.28) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                      dense: true,
                                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: H.text, fontSize: 14)),
                                      subtitle: Text('${s.messages.length} messages', style: const TextStyle(color: H.textMuted, fontSize: 11)),
                                      onTap: () => _selectSession(s),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.attachments.isNotEmpty)
                Wrap(spacing: 6, children: m.attachments.map((n) => Chip(visualDensity: VisualDensity.compact, label: Text(n, style: const TextStyle(fontSize: 11)))).toList()),
              if (m.tools.isNotEmpty)
                Wrap(spacing: 6, children: m.tools.map((t) => Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.build, size: 14), label: Text(t, style: const TextStyle(fontSize: 11)))).toList()),
              if (m.status == 'streaming' && m.text.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: H.purple)))
              else if (isUser)
                Text(m.text, style: const TextStyle(color: H.text, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500))
              else
                MarkdownBody(
                  data: m.text.isEmpty ? '…' : m.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: H.text, fontSize: 14.5, height: 1.4),
                    code: const TextStyle(color: H.purpleSoft, fontSize: 13),
                    listBullet: const TextStyle(color: H.text),
                    h1: const TextStyle(color: H.text, fontSize: 20, fontWeight: FontWeight.w700),
                    h2: const TextStyle(color: H.text, fontSize: 18, fontWeight: FontWeight.w700),
                    h3: const TextStyle(color: H.text, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              if (m.editedAt != null)
                const Padding(padding: EdgeInsets.only(top: 4), child: Text('edited', style: TextStyle(color: H.textMuted, fontSize: 10))),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: H.textMuted, size: 18),
                  onSelected: (v) {
                    if (v == 'copy') _copy(m);
                    if (v == 'delete') _deleteMessage(m);
                    if (v == 'edit') _edit(m);
                    if (v == 'resend') _resend(m);
                    if (v == 'retry') _retry(m);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                    if (isUser) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isUser) const PopupMenuItem(value: 'resend', child: Text('Resend')),
                    if (!isUser) const PopupMenuItem(value: 'retry', child: Text('Retry')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Attach {
  _Attach(this.name, this.excerpt);
  final String name;
  final String excerpt;
}
