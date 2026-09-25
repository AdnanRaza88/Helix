import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.ghToken, required this.geminiKey, required this.onSave});
  final String ghToken;
  final String geminiKey;
  final Future<void> Function(String token, String key) onSave;
  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
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
