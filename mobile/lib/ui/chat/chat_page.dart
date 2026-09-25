import 'dart:ui';
import 'package:flutter/material.dart';

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
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmMutation(String title, String detail) async {
    if (!mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
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
                  Text(title, style: const TextStyle(color: H.text, fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(detail, style: const TextStyle(color: H.textMuted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: H.purple),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result == true;
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

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    active ??= ChatSession(id: store.newId(), title: store.titleFromFirstMessage(text));
    if (active!.messages.isEmpty) active!.title = store.titleFromFirstMessage(text);
    setState(() {
      active!.messages.add(ChatMessage(role: 'user', text: text));
      active!.updatedAt = DateTime.now();
      sending = true;
    });
    controller.clear();
    _scrollEnd();
    await _persist();
    try {
      final history = active!.historyForApi();
      final prior = history.length > 1 ? history.sublist(0, history.length - 1) : <Map<String, String>>[];
      final reply = await widget.gemini.runWithTools(text, history: prior);
      setState(() {
        active!.messages.add(ChatMessage(role: 'model', text: reply));
        active!.updatedAt = DateTime.now();
        sending = false;
      });
    } catch (e) {
      setState(() {
        active!.messages.add(ChatMessage(role: 'model', text: 'Error: $e'));
        sending = false;
      });
    }
    await _persist();
    _scrollEnd();
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
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
                  itemCount: messages.length + (sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (sending && i == messages.length) {
                      return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: H.purple))));
                    }
                    final m = messages[i];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          borderRadius: 18,
                          child: Text(m.text, style: TextStyle(color: H.text, fontSize: 14.5, height: 1.4, fontWeight: isUser ? FontWeight.w500 : FontWeight.w400)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(color: H.bgDeep.withValues(alpha: 0.7), border: const Border(top: BorderSide(color: H.glassBorder, width: 0.8))),
              child: Row(children: [
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
                Material(color: H.purple, borderRadius: BorderRadius.circular(22), child: InkWell(onTap: sending ? null : _send, borderRadius: BorderRadius.circular(22), child: const SizedBox(width: 46, height: 46, child: Icon(Icons.send_rounded, color: Colors.white, size: 20)))),
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
}
