import 'package:flutter/material.dart';

import '../llm/catalog.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class SettingsSavePayload {
  SettingsSavePayload({
    required this.ghToken,
    required this.provider,
    required this.model,
    required this.geminiKey,
    required this.groqKey,
    required this.openRouterKey,
  });

  final String ghToken;
  final String provider;
  final String model;
  final String geminiKey;
  final String groqKey;
  final String openRouterKey;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.ghToken,
    required this.provider,
    required this.model,
    required this.geminiKey,
    required this.groqKey,
    required this.openRouterKey,
    required this.onSave,
  });

  final String ghToken;
  final String provider;
  final String model;
  final String geminiKey;
  final String groqKey;
  final String openRouterKey;
  final Future<void> Function(SettingsSavePayload p) onSave;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late final ghCtrl = TextEditingController(text: widget.ghToken);
  late final gemCtrl = TextEditingController(text: widget.geminiKey);
  late final groqCtrl = TextEditingController(text: widget.groqKey);
  late final orCtrl = TextEditingController(text: widget.openRouterKey);
  late String provider = widget.provider;
  late String model = widget.model;
  bool saving = false;

  @override
  void dispose() {
    ghCtrl.dispose();
    gemCtrl.dispose();
    groqCtrl.dispose();
    orCtrl.dispose();
    super.dispose();
  }

  List<LlmModel> get _models => LlmCatalog.forProvider(provider);

  Future<void> _save() async {
    setState(() => saving = true);
    var m = model;
    final allowed = _models.map((e) => e.id).toSet();
    if (!allowed.contains(m) && _models.isNotEmpty) {
      m = _models.first.id;
    }
    await widget.onSave(SettingsSavePayload(
      ghToken: ghCtrl.text.trim(),
      provider: provider,
      model: m,
      geminiKey: gemCtrl.text.trim(),
      groqKey: groqCtrl.text.trim(),
      openRouterKey: orCtrl.text.trim(),
    ));
    setState(() {
      saving = false;
      model = m;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved'),
          backgroundColor: H.purple.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = _models;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('Settings',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: H.text)),
        const SizedBox(height: 6),
        const Text('Providers, models, and keys — chats stay on device',
            style: TextStyle(color: H.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.vpn_key_rounded, color: H.purpleSoft, size: 20),
                SizedBox(width: 8),
                Text('GitHub Personal Access Token',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: ghCtrl,
                  obscureText: true,
                  style: const TextStyle(color: H.text),
                  decoration: _inputDeco('ghp_... or github_pat_...')),
              const SizedBox(height: 8),
              const Text(
                  'Needs repo + user scopes. Create at github.com/settings/tokens',
                  style: TextStyle(color: H.textMuted, fontSize: 12)),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.hub_outlined, color: H.pink, size: 20),
                SizedBox(width: 8),
                Text('LLM Provider',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: provider,
                dropdownColor: H.bgMid,
                style: const TextStyle(color: H.text),
                decoration: _inputDeco('Provider'),
                items: const [
                  DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                  DropdownMenuItem(value: 'groq', child: Text('Groq (fast)')),
                  DropdownMenuItem(
                      value: 'openrouter', child: Text('OpenRouter')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    provider = v;
                    final list = LlmCatalog.forProvider(v);
                    model = list.isEmpty ? '' : list.first.id;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: models.any((m) => m.id == model)
                    ? model
                    : (models.isEmpty ? null : models.first.id),
                dropdownColor: H.bgMid,
                style: const TextStyle(color: H.text, fontSize: 13),
                isExpanded: true,
                decoration: _inputDeco('Model'),
                items: models
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            m.note == null
                                ? m.label
                                : '${m.label} · ${m.note}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => model = v);
                },
              ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: H.pink, size: 20),
                SizedBox(width: 8),
                Text('Gemini API Key',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: gemCtrl,
                  obscureText: true,
                  style: const TextStyle(color: H.text),
                  decoration: _inputDeco('AIza...')),
              const SizedBox(height: 8),
              const Text('aistudio.google.com/apikey',
                  style: TextStyle(color: H.textMuted, fontSize: 12)),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.bolt, color: H.purpleSoft, size: 20),
                SizedBox(width: 8),
                Text('Groq API Key',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: groqCtrl,
                  obscureText: true,
                  style: const TextStyle(color: H.text),
                  decoration: _inputDeco('gsk_...')),
              const SizedBox(height: 8),
              const Text('console.groq.com — fastest remote tools',
                  style: TextStyle(color: H.textMuted, fontSize: 12)),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.route, color: H.pink, size: 20),
                SizedBox(width: 8),
                Text('OpenRouter API Key',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: orCtrl,
                  obscureText: true,
                  style: const TextStyle(color: H.text),
                  decoration: _inputDeco('sk-or-...')),
              const SizedBox(height: 8),
              const Text(
                  'openrouter.ai — Qwen Coder, Nemotron, Llama, etc.',
                  style: TextStyle(color: H.textMuted, fontSize: 12)),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Local models (Ollama next)',
                  style:
                      TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...LlmCatalog.localSuggestions.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${m.label}${m.contextK != null ? ' · ${m.contextK}K ctx' : ''}${m.note != null ? ' — ${m.note}' : ''}',
                      style:
                          const TextStyle(color: H.textMuted, fontSize: 12),
                    ),
                  )),
              const SizedBox(height: 4),
              const Text(
                  'Pull via Ollama on device/PC; wire-up in next phase.',
                  style: TextStyle(color: H.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: H.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save & connect',
                    style: TextStyle(fontWeight: FontWeight.w600)),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: H.glassBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: H.glassBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: H.purple, width: 1.4)),
    );
  }
}
