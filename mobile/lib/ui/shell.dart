import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gemini.dart';
import '../github.dart';
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
  List<dynamic> repos = [];
  String status = 'Simulation';
  Map<String, dynamic>? user;
  bool loading = false;
  AppUpdateInfo? updateInfo;
  late GitHubClient github;
  late GeminiClient gemini;
  String? activeRepo;

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
    activeRepo = prefs.getString('helix_active_repo');
    github = GitHubClient(token: ghToken);
    gemini = GeminiClient(apiKey: geminiKey, github: github)
      ..activeRepo = activeRepo;
    await _refresh();
  }

  Future<void> _setActiveRepo(String owner, String repo) async {
    final prefs = await SharedPreferences.getInstance();
    final value = '$owner/$repo';
    await prefs.setString('helix_active_repo', value);
    setState(() {
      activeRepo = value;
      gemini.activeRepo = value;
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
        status = github.isLive ? 'Live \u00b7 ${u?['login'] ?? 'GitHub'}' : 'Simulation';
        loading = false;
      });
    } catch (e) {
      setState(() {
        status = 'Error: $e';
        loading = false;
      });
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
      gemini = GeminiClient(apiKey: key, github: github)
        ..activeRepo = activeRepo;
    });
    await _refresh();
  }

  Future<void> _openUpdate() async {
    final url = updateInfo?.apkUrl ?? 'https://github.com/AdnanRaza88/Helix/actions';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      ChatPage(gemini: gemini),
      ReposPage(
        repos: repos,
        onRefresh: _refresh,
        loading: loading,
        activeRepo: activeRepo,
        onSelect: _setActiveRepo,
      ),
      SettingsPage(ghToken: ghToken, geminiKey: geminiKey, onSave: _saveKeys),
    ];
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            if (updateInfo != null)
              UpdateBanner(info: updateInfo!, onTap: _openUpdate),
            Expanded(child: pages[index]),
          ]),
        ),
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: H.bgDeep.withValues(alpha: 0.72),
                border: const Border(top: BorderSide(color: H.glassBorder, width: 0.8)),
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
