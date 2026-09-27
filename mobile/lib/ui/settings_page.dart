import 'package:flutter/material.dart';

import '../github.dart';
import '../llm/catalog.dart';
import '../llm/ollama.dart';
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
    required this.ollamaBase,
  });

  final String ghToken;
  final String provider;
  final String model;
  final String geminiKey;
  final String groqKey;
  final String openRouterKey;
  final String ollamaBase;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.ghToken,
    required this.provider,
    required this.model,
    required this.geminiKey,
    required this.groqKey,
    required this.openRouterKey,
    required this.ollamaBase,
    required this.onSave,
  });

  final String ghToken;
  final String provider;
  final String model;
  final String geminiKey;
  final String groqKey;
  final String openRouterKey;
  final String ollamaBase;
  final Future<void> Function(SettingsSavePayload p) onSave;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late final ghCtrl = TextEditingController(text: widget.ghToken);
  late final gemCtrl = TextEditingController(text: widget.geminiKey);
  late final groqCtrl = TextEditingController(text: widget.groqKey);
  late final orCtrl = TextEditingController(text: widget.openRouterKey);
  late final ollamaCtrl = TextEditingController(text: widget.ollamaBase);
  late String provider = widget.provider;
  late String model = widget.model;
  bool saving = false;
  bool ollamaOnline = false;
  String? ollamaStatus;
  String? pulling;
  double? pullProgress;
  List<String> installed = [];

  @override
  void initState() {
    super.initState();
    if (provider == 'ollama') _refreshOllama();
  }

  @override
  void dispose() {
    ghCtrl.dispose();
    gemCtrl.dispose();
    groqCtrl.dispose();
    orCtrl.dispose();
    ollamaCtrl.dispose();
    super.dispose();
  }

  List<LlmModel> get _models => LlmCatalog.forProvider(provider);

  Future<void> _refreshOllama() async {
    setState(() {
      ollamaStatus = 'Checking…';
      ollamaOnline = false;
    });
    try {
      final base = ollamaCtrl.text.trim().isEmpty
          ? 'http://127.0.0.1:11434'
          : ollamaCtrl.text.trim();
      final client = _makeOllama(base, model);
      final ok = await client.ping();
      final list = ok ? await client.listModels() : <String>[];
      if (!mounted) return;
      setState(() {
        ollamaOnline = ok;
        installed = list;
        ollamaStatus = ok
            ? 'Online · ${list.length} model(s)'
            : 'Offline — start Ollama on this URL';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ollamaOnline = false;
        ollamaStatus = 'Offline: $e';
        installed = [];
      });
    }
  }

  OllamaClient _makeOllama(String base, String m) {
    return OllamaClient(
      baseUrl: base,
      model: m,
      github: GitHubClient(token: ''),
    );
  }

  Future<void> _pull(LlmModel m) async {
    final base = ollamaCtrl.text.trim().isEmpty
        ? 'http://127.0.0.1:11434'
        : ollamaCtrl.text.trim();
    final client = _makeOllama(base, m.ollamaName);
    setState(() {
      pulling = m.ollamaName;
      pullProgress = 0;
      ollamaStatus = 'Pulling ${m.ollamaName}…';
    });
    try {
      await for (final p in client.pullModel(m.ollamaName)) {
        if (!mounted) return;
        setState(() => pullProgress = p);
      }
      await _refreshOllama();
      if (!mounted) return;
      setState(() {
        model = m.id;
        provider = 'ollama';
        pulling = null;
        pullProgress = null;
        ollamaStatus = 'Ready · ${m.label}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${m.label} downloaded — select Ollama & Save'),
          backgroundColor: H.purple.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pulling = null;
        pullProgress = null;
        ollamaStatus = 'Pull failed: $e';
      });
    }
  }

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
      ollamaBase: ollamaCtrl.text.trim().isEmpty
          ? 'http://127.0.0.1:11434'
          : ollamaCtrl.text.trim(),
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
        const Text('Providers, models, Ollama pull — chats stay on device',
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
                  DropdownMenuItem(
                      value: 'ollama', child: Text('Ollama (local)')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    provider = v;
                    final list = LlmCatalog.forProvider(v);
                    model = list.isEmpty ? '' : list.first.id;
                  });
                  if (v == 'ollama') _refreshOllama();
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
        if (provider != 'ollama') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemini API Key',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                    controller: gemCtrl,
                    obscureText: true,
                    style: const TextStyle(color: H.text),
                    decoration: _inputDeco('AIza...')),
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
                      style: TextStyle(
                          color: H.text, fontWeight: FontWeight.w600)),
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
                const Text('OpenRouter API Key',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                    controller: orCtrl,
                    obscureText: true,
                    style: const TextStyle(color: H.text),
                    decoration: _inputDeco('sk-or-...')),
                const SizedBox(height: 8),
                const Text(
                    'openrouter.ai — Qwen, Nemotron, Llama',
                    style: TextStyle(color: H.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.storage_rounded, color: H.pink, size: 20),
                SizedBox(width: 8),
                Text('Ollama (local)',
                    style:
                        TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Phone: point to PC LAN IP running Ollama.\n'
                'Emulator: http://10.0.2.2:11434 · Device: http://127.0.0.1:11434 or http://192.168.x.x:11434',
                style: TextStyle(color: H.textMuted, fontSize: 11, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ollamaCtrl,
                style: const TextStyle(color: H.text),
                decoration: _inputDeco('http://127.0.0.1:11434'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                FilledButton.tonal(
                  onPressed: pulling != null ? null : _refreshOllama,
                  child: const Text('Check'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ollamaStatus ?? 'Not checked',
                    style: TextStyle(
                      color: ollamaOnline ? H.success : H.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ]),
              if (pullProgress != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: pullProgress,
                  color: H.purple,
                  backgroundColor: H.glassBorder,
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloading $pulling… ${((pullProgress ?? 0) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: H.textMuted, fontSize: 11),
                ),
              ],
              const SizedBox(height: 14),
              const Text('One-tap download (then use)',
                  style: TextStyle(color: H.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...LlmCatalog.forProvider('ollama').map((m) {
                final have = installed.any((n) =>
                    n == m.ollamaName ||
                    n.startsWith('${m.ollamaName}:') ||
                    n.split(':').first == m.ollamaName.split(':').first);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m.label}${m.contextK != null ? ' · ${m.contextK}K' : ''}${m.note != null ? '\n${m.note}' : ''}',
                          style: const TextStyle(
                              color: H.text, fontSize: 13, height: 1.25),
                        ),
                      ),
                      if (have)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_circle,
                              color: H.success, size: 18),
                        ),
                      FilledButton(
                        onPressed: pulling != null ? null : () => _pull(m),
                        style: FilledButton.styleFrom(
                          backgroundColor: H.purple,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(have ? 'Re-pull' : 'Download'),
                      ),
                    ],
                  ),
                );
              }),
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
