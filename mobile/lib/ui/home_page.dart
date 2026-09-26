import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/glass.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.status, required this.repos, required this.user, required this.loading, required this.onRefresh, required this.onOpenChat, required this.onOpenRepos});
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [H.purple, H.pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: H.purple.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Helix', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: H.text, letterSpacing: -0.5)),
                  Text('VIP GitHub Agent', style: TextStyle(fontSize: 13, color: H.textMuted)),
                ],
              ),
            ),
            if (loading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: H.purple)),
          ]),
          const SizedBox(height: 22),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(color: H.purpleSoft, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  user != null ? 'Signed in as ${user!['login']}' : 'Add GitHub token for live control',
                  style: const TextStyle(color: H.text, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text('${repos.length} repositories available', style: const TextStyle(color: H.textMuted, fontSize: 13)),
              ],
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick actions', style: TextStyle(color: H.text, fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _ActionBtn(icon: Icons.chat_bubble_rounded, label: 'Chat with Gemini', onTap: onOpenChat)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionBtn(icon: Icons.folder_rounded, label: 'Browse repos', onTap: onOpenRepos)),
                ]),
              ],
            ),
          ),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [H.purple.withValues(alpha: 0.35), H.pink.withValues(alpha: 0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: H.glassBorder),
          ),
          child: Column(children: [
            Icon(icon, color: H.text, size: 26),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: H.text, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
