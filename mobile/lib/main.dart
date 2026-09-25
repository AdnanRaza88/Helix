import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github.dart';
import 'gemini.dart';
import 'sessions.dart';
import 'updater.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0221),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HelixApp());
}

class H {
  static const bgDeep = Color(0xFF0D0221);
  static const bgMid = Color(0xFF1A0A3C);
  static const purple = Color(0xFF7B5CFF);
  static const purpleSoft = Color(0xFFB89BFF);
  static const pink = Color(0xFFE879F9);
  static const glass = Color(0x33FFFFFF);
  static const glassBorder = Color(0x55FFFFFF);
  static const text = Color(0xFFF4F0FF);
  static const textMuted = Color(0xFFB8A9D9);
  static const success = Color(0xFF4ADE80);
}

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: H.purple,
          secondary: H.pink,
          surface: H.bgMid,
          onSurface: H.text,
        ),
        scaffoldBackgroundColor: H.bgDeep,
        fontFamily: 'sans-serif',
      ),
      home: const Shell(),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.margin = const EdgeInsets.only(bottom: 14), this.borderRadius = 22, this.blur = 18});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;
  final double blur;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: H.glass,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: H.glassBorder, width: 1.2),
              boxShadow: [BoxShadow(color: H.purple.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientBg extends StatelessWidget {
  const GradientBg({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-0.6, -0.7), radius: 1.4, colors: [Color(0xFF3B1A7A), H.bgDeep])),
      child: Stack(children: [
        Positioned(top: -40, right: -30, child: _orb(160, H.purple.withValues(alpha: 0.35))),
        Positioned(bottom: 120, left: -50, child: _orb(200, H.pink.withValues(alpha: 0.22))),
        Positioned(top: 180, right: -20, child: _orb(90, H.purpleSoft.withValues(alpha: 0.25))),
        child,
      ]),
    );
  }
  Widget _orb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])));
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  String ghToken = '';
  String geminiKey = '';
  List<dynamic> repos = [];
  String status = 'Simulation';
  Map<String, dynamic>? user;
  bool loading = false;
  AppUpdateInfo? updateInfo;
  late GitHubClient github;
  late GeminiClient gemini;

  @override
  void initState() {
    super.initState();
    github = GitHubClient(token: '');
    gemini = GeminiClient(apiKey: '', github: github);
    _load();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateChecker().check();
    if (info != null && mounted) setState(() => updateInfo = info);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    ghToken = prefs.getString('github_token') ?? '';
    geminiKey = prefs.getString('gemini_key') ?? '';
    github = GitHubClient(token: ghToken);
    gemini = GeminiClient(apiKey: geminiKey, github: github);
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    try {
      final list = await github.listRepos();
      Map<String, dynamic>? u;
      if (github.isLive) u = await github.getUser();
      setState(() {
        repos = list;
        user = u;
        status = github.isLive ? 'Live · ${u?['login'] ?? 'GitHub'}' : 'Simulation';
        loading = false;
      });
    } catch (e) {
      setState(() { status = 'Error: $e'; loading = false; });
    }
  }

  Future<void> _saveKeys(String token, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', token);
    await prefs.setString('gemini_key', key);
    setState(() {
      ghToken = token;
      geminiKey = key;
      github = GitHubClient(token: token);
      gemini = GeminiClient(apiKey: key, github: github);
    });
    await _refresh();
  }

  Future<void> _openUpdate() async {
    final url = updateInfo?.apkUrl ?? 'https://github.com/AdnanRaza88/Helix/actions';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(status: status, repos: repos, user: user, loading: loading, onRefresh: _refresh, onOpenChat: () => setState(() => index = 1), onOpenRepos: () => setState(() => index = 2)),
      _ChatPage(gemini: gemini),
      _ReposPage(repos: repos, onRefresh: _refresh, loading: loading),
      _SettingsPage(ghToken: ghToken, geminiKey: geminiKey, onSave: _saveKeys),
    ];
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            if (updateInfo != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openUpdate,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [H.purple.withValues(alpha: 0.55), H.pink.withValues(alpha: 0.4)]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: H.glassBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Update available · v${updateInfo!.version}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(updateInfo!.notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                      ])),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            Expanded(child: pages[index]),
          ]),
        ),
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(color: H.bgDeep.withValues(alpha: 0.72), border: const Border(top: BorderSide(color: H.glassBorder, width: 0.8))),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                indicatorColor: H.purple.withValues(alpha: 0.35),
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
                  NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Repos'),
                  NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.status, required this.repos, required this.user, required this.loading, required this.onRefresh, required this.onOpenChat, required this.onOpenRepos});
  final String status;
  final List<dynamic> repos;
  final Map<String, dynamic>? user;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenRepos;
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: H.purple,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [H.purple, H.pink], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: H.purple.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))]), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Helix', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: H.text, letterSpacing: -0.5)), Text('VIP GitHub Agent', style: TextStyle(fontSize: 13, color: H.textMuted))])),
            if (loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: H.purple)),
          ]),
          const SizedBox(height: 22),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, style: const TextStyle(color: H.purpleSoft, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Text(user != null ? 'Signed in as ${user!['login']}' : 'Add GitHub token for live control', style: const TextStyle(color: H.text, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('${repos.length} repositories available', style: const TextStyle(color: H.textMuted, fontSize: 13)),
          ])),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quick actions', style: TextStyle(color: H.text, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ActionBtn(icon: Icons.chat_bubble_rounded, label: 'Chat with Gemini', onTap: onOpenChat)),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(icon: Icons.folder_rounded, label: 'Browse repos', onTap: onOpenRepos)),
            ]),
          ])),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [H.purple.withValues(alpha: 0.35), H.pink.withValues(alpha: 0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: H.glassBorder)),
          child: Column(children: [Icon(icon, color: H.text, size: 26), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: H.text, fontSize: 12, fontWeight: FontWeight.w500))]),
        ),
      ),
    );
  }
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({required this.gemini});
  final GeminiClient gemini;
  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
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
    _loadSessions();
  }

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
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
                  Text('“List my repos”\n“Who am I on GitHub?”\n“Create a repo named demo-app”\n\nSessions are saved automatically.', textAlign: TextAlign.center, style: TextStyle(color: H.textMuted, fontSize: 13, height: 1.5)),
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
                    hintText: 'Message Helix…',
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

class _ReposPage extends StatelessWidget {
  const _ReposPage({required this.repos, required this.onRefresh, required this.loading});
  final List<dynamic> repos;
  final Future<void> Function() onRefresh;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: H.purple,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: repos.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [
              const Text('Repositories', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: H.text)),
              const Spacer(),
              if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: H.purple)),
            ]));
          }
          final repo = repos[i - 1] as Map<String, dynamic>;
          final name = (repo['full_name'] ?? repo['name'] ?? '').toString();
          final private = repo['private'] == true;
          final stars = repo['stargazers_count'] ?? 0;
          final lang = (repo['language'] ?? '').toString();
          final desc = (repo['description'] ?? '').toString();
          return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(color: H.text, fontWeight: FontWeight.w600, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: private ? H.pink.withValues(alpha: 0.2) : H.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(private ? 'private' : 'public', style: TextStyle(fontSize: 11, color: private ? H.pink : H.success, fontWeight: FontWeight.w600)),
              ),
            ]),
            if (desc.isNotEmpty) ...[const SizedBox(height: 6), Text(desc, style: const TextStyle(color: H.textMuted, fontSize: 13))],
            const SizedBox(height: 10),
            Row(children: [
              if (lang.isNotEmpty) ...[const Icon(Icons.code, size: 14, color: H.purpleSoft), const SizedBox(width: 4), Text(lang, style: const TextStyle(color: H.purpleSoft, fontSize: 12)), const SizedBox(width: 14)],
              const Icon(Icons.star_rounded, size: 14, color: H.purpleSoft),
              const SizedBox(width: 4),
              Text('$stars', style: const TextStyle(color: H.purpleSoft, fontSize: 12)),
            ]),
          ]));
        },
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.ghToken, required this.geminiKey, required this.onSave});
  final String ghToken;
  final String geminiKey;
  final Future<void> Function(String token, String key) onSave;
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final ghCtrl = TextEditingController(text: widget.ghToken);
  late final gemCtrl = TextEditingController(text: widget.geminiKey);
  bool saving = false;
  @override
  void dispose() { ghCtrl.dispose(); gemCtrl.dispose(); super.dispose(); }
  Future<void> _save() async {
    setState(() => saving = true);
    await widget.onSave(ghCtrl.text.trim(), gemCtrl.text.trim());
    setState(() => saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Keys saved'), backgroundColor: H.purple.withValues(alpha: 0.9), behavior: SnackBarBehavior.floating));
    }
  }
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: H.text)),
        const SizedBox(height: 6),
        const Text('Connect providers for live control', style: TextStyle(color: H.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.vpn_key_rounded, color: H.purpleSoft, size: 20), SizedBox(width: 8), Text('GitHub Personal Access Token', style: TextStyle(color: H.text, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          TextField(controller: ghCtrl, obscureText: true, style: const TextStyle(color: H.text), decoration: _inputDeco('ghp_... or github_pat_...')),
          const SizedBox(height: 8),
          const Text('Needs repo + user scopes. Create at github.com/settings/tokens', style: TextStyle(color: H.textMuted, fontSize: 12)),
        ])),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome, color: H.pink, size: 20), SizedBox(width: 8), Text('Gemini API Key (Google)', style: TextStyle(color: H.text, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          TextField(controller: gemCtrl, obscureText: true, style: const TextStyle(color: H.text), decoration: _inputDeco('AIza...')),
          const SizedBox(height: 8),
          const Text('Get a free key at aistudio.google.com/apikey', style: TextStyle(color: H.textMuted, fontSize: 12)),
        ])),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: H.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save & connect', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: H.textMuted),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: H.glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: H.glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: H.purple, width: 1.4)),
    );
  }
}
