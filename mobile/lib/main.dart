import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'github.dart';

void main() {
  runApp(const HelixApp());
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
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1B4F72),
          onPrimary: Color(0xFFF4F7FB),
          surface: Color(0xFFE8EEF5),
          onSurface: Color(0xFF161C27),
        ),
        scaffoldBackgroundColor: const Color(0xFFE8EEF5),
        fontFamily: 'sans-serif',
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  String token = '';
  List<dynamic> repos = [];
  String status = 'Simulation workspace';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('github_token') ?? '';
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final client = GitHubClient(token: token, simulate: token.isEmpty);
      final data = await client.get('/user/repos?sort=updated&per_page=30');
      setState(() {
        repos = data is List ? data : [];
        status = token.isEmpty ? 'Simulation workspace' : 'Live GitHub';
      });
    } catch (error) {
      setState(() => status = error.toString());
    }
  }

  Future<void> _saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', value);
    setState(() => token = value);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(status: status, repos: repos, onOpenRepos: () => setState(() => index = 1)),
      _ReposPage(repos: repos, onRefresh: _refresh),
      _SettingsPage(token: token, onSave: _saveToken),
    ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Repos'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.status, required this.repos, required this.onOpenRepos});
  final String status;
  final List<dynamic> repos;
  final VoidCallback onOpenRepos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text('Helix', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(status, style: const TextStyle(color: Color(0xFF5A6574))),
        const SizedBox(height: 20),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${repos.length} repositories', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              FilledButton(onPressed: onOpenRepos, child: const Text('Open repos')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReposPage extends StatelessWidget {
  const _ReposPage({required this.repos, required this.onRefresh});
  final List<dynamic> repos;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        itemCount: repos.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Repos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
            );
          }
          final repo = repos[i - 1] as Map<String, dynamic>;
          final name = (repo['full_name'] ?? repo['name'] ?? '').toString();
          final private = repo['private'] == true;
          return Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text((repo['description'] ?? '').toString(), style: const TextStyle(color: Color(0xFF5A6574))),
                const SizedBox(height: 8),
                Text(private ? 'private' : 'public'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.token, required this.onSave});
  final String token;
  final Future<void> Function(String value) onSave;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController controller = TextEditingController(text: widget.token);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GitHub token'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'ghp_...'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => widget.onSave(controller.text.trim()),
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leave empty to stay in simulation. APK builds run from GitHub Actions on push.',
                style: TextStyle(color: Color(0xFF5A6574)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
