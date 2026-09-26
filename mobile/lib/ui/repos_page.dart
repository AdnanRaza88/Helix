import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/glass.dart';

class ReposPage extends StatelessWidget {
  const ReposPage({
    required this.repos,
    required this.onRefresh,
    required this.loading,
    this.activeRepo,
    this.onSelect,
  });
  final List<dynamic> repos;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? activeRepo;
  final void Function(String owner, String repo)? onSelect;

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
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                const Text('Repositories',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: H.text)),
                const Spacer(),
                if (activeRepo != null)
                  Text(activeRepo!,
                      style: const TextStyle(color: H.purpleSoft, fontSize: 12)),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: H.purple),
                  ),
              ]),
            );
          }
          final repo = repos[i - 1] as Map<String, dynamic>;
          final name = (repo['full_name'] ?? repo['name'] ?? '').toString();
          final private = repo['private'] == true;
          final stars = repo['stargazers_count'] ?? 0;
          final lang = (repo['language'] ?? '').toString();
          final desc = (repo['description'] ?? '').toString();
          final selected = activeRepo == name;
          return GestureDetector(
            onTap: () {
              final parts = name.split('/');
              if (parts.length >= 2) {
                onSelect?.call(parts[0], parts.sublist(1).join('/'));
              }
            },
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: selected ? H.purpleSoft : H.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: private
                            ? H.pink.withValues(alpha: 0.2)
                            : H.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        private ? 'private' : 'public',
                        style: TextStyle(
                          fontSize: 11,
                          color: private ? H.pink : H.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(desc,
                        style:
                            const TextStyle(color: H.textMuted, fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    if (lang.isNotEmpty) ...[
                      const Icon(Icons.code, size: 14, color: H.purpleSoft),
                      const SizedBox(width: 4),
                      Text(lang,
                          style: const TextStyle(
                              color: H.purpleSoft, fontSize: 12)),
                      const SizedBox(width: 14),
                    ],
                    const Icon(Icons.star_rounded,
                        size: 14, color: H.purpleSoft),
                    const SizedBox(width: 4),
                    Text('$stars',
                        style:
                            const TextStyle(color: H.purpleSoft, fontSize: 12)),
                    if (selected) ...[
                      const Spacer(),
                      const Text('active',
                          style: TextStyle(color: H.purpleSoft, fontSize: 11)),
                    ],
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
