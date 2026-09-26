import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../github.dart';
import '../llm/catalog.dart';
import '../llm/helix_llm.dart';
import '../updater.dart';
import 'chat/chat_page.dart';
import 'home_page.dart';
import 'repos_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/update_banner.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  String ghToken = '';
  String geminiKey = '';
  String groqKey = '';
  String openRouterKey = '';
  String provider = 'gemini';
  String model = 'gemini-2.5-flash';
  List<dynamic> repos = [];
  String status = 'Simulation';
  Map<String, dynamic>? user;
  bool loading = false;
  AppUpdateInfo? updateInfo;
  double? updateProgress;
  bool updating = false;
  late GitHubClient github;
  late HelixLlm llm;
  String? activeRepo;

  @override
  void initState() {
    super.initState();
    github = GitHubClient(token: '');
    llm = HelixLlm(
      provider: provider,
      model: model,
      github: github,
    );
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
    groqKey = prefs.getString('groq_key') ?? '';
    openRouterKey = prefs.getString('openrouter_key') ?? '';
    provider = prefs.getString('llm_provider') ?? 'gemini';
    model = prefs.getString('llm_model') ?? LlmCatalog.defaultModel(provider);
    activeRepo = prefs.getString('helix_active_repo');
    github = GitHubClient(token: ghToken);
    llm = HelixLlm(
      provider: provider,
      model: model,
      github: github,
      geminiKey: geminiKey,
      groqKey: groqKey,
      openRouterKey: openRouterKey,
    )..setActiveRepo(activeRepo);
    await _refresh();
  }

  Future<void> _setActiveRepo(String owner, String repo) async {
    final prefs = await SharedPreferences.getInstance();
    final value = '$owner/$repo';
    await prefs.setString('helix_active_repo', value);
    setState(() {
      activeRepo = value;
      llm.setActiveRepo(value);
    });
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
        status = github.isLive
            ? 'Live · ${u?['login'] ?? 'GitHub'}'
            : 'Simulation';
        loading = false;
      });
    } catch (e) {
      setState(() {
        status = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _saveSettings(SettingsSavePayload p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', p.ghToken);
    await prefs.setString('gemini_key', p.geminiKey);
    await prefs.setString('groq_key', p.groqKey);
    await prefs.setString('openrouter_key', p.openRouterKey);
    await prefs.setString('llm_provider', p.provider);
    await prefs.setString('llm_model', p.model);
    setState(() {
      ghToken = p.ghToken;
      geminiKey = p.geminiKey;
      groqKey = p.groqKey;
      openRouterKey = p.openRouterKey;
      provider = p.provider;
      model = p.model;
      github = GitHubClient(token: p.ghToken);
      llm = HelixLlm(
        provider: p.provider,
        model: p.model,
        github: github,
        geminiKey: p.geminiKey,
        groqKey: p.groqKey,
        openRouterKey: p.openRouterKey,
      )..setActiveRepo(activeRepo);
    });
    await _refresh();
  }

  Future<void> _openUpdate() async {
    final info = updateInfo;
    if (info == null) return;
    if (updating) return;

    final action = await showModalBottomSheet<String>(
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
                  Text('Update to v${info.version}',
                      style: const TextStyle(
                          color: H.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(info.notes,
                      style: const TextStyle(
                          color: H.textMuted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'Chats, tokens, and SQLite stay on device. Same app signature keeps data.',
                    style: TextStyle(color: H.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'install'),
                    style: FilledButton.styleFrom(backgroundColor: H.purple),
                    child: const Text('Download & install'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'browser'),
                    child: const Text('Open release page',
                        style: TextStyle(color: H.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == 'browser') {
      await UpdateInstaller.openReleasePage(info);
      return;
    }
    if (action != 'install') return;

    setState(() {
      updating = true;
      updateProgress = 0;
    });
    try {
      await UpdateInstaller.downloadAndInstall(
        info,
        onProgress: (p) {
          if (mounted) setState(() => updateProgress = p);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Install prompt opened. Keep Helix when asked — data is safe.'),
            backgroundColor: H.purple.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: H.pink.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await UpdateInstaller.openReleasePage(info);
      }
    } finally {
      if (mounted) {
        setState(() {
          updating = false;
          updateProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        status: status,
        repos: repos,
        user: user,
        loading: loading,
        onRefresh: _refresh,
        onOpenChat: () => setState(() => index = 1),
        onOpenRepos: () => setState(() => index = 2),
      ),
      ChatPage(llm: llm),
      ReposPage(
        repos: repos,
        onRefresh: _refresh,
        loading: loading,
        activeRepo: activeRepo,
        onSelect: _setActiveRepo,
      ),
      SettingsPage(
        ghToken: ghToken,
        provider: provider,
        model: model,
        geminiKey: geminiKey,
        groqKey: groqKey,
        openRouterKey: openRouterKey,
        onSave: _saveSettings,
      ),
    ];
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            if (updateInfo != null)
              UpdateBanner(
                info: updateInfo!,
                onTap: _openUpdate,
                progress: updateProgress,
              ),
            Expanded(child: pages[index]),
          ]),
        ),
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: H.bgDeep.withValues(alpha: 0.72),
                border: const Border(
                    top: BorderSide(color: H.glassBorder, width: 0.8)),
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                indicatorColor: H.purple.withValues(alpha: 0.35),
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: 'Chat',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: 'Repos',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
