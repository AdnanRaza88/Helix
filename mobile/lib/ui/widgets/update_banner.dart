import 'package:flutter/material.dart';

import '../../updater.dart';
import '../theme.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.info, required this.onTap});
  final AppUpdateInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              H.purple.withValues(alpha: 0.55),
              H.pink.withValues(alpha: 0.4),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: H.glassBorder),
          ),
          child: Row(children: [
            const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update available \u00b7 v${info.version}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    info.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}
