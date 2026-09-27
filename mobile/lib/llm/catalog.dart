class LlmModel {
  const LlmModel({
    required this.id,
    required this.label,
    required this.provider,
    this.contextK,
    this.local = false,
    this.note,
    this.pullTag,
  });

  final String id;
  final String label;
  final String provider;
  final int? contextK;
  final bool local;
  final String? note;
  final String? pullTag;

  String get ollamaName => pullTag ?? id;
}

class LlmCatalog {
  static const providers = <String>[
    'gemini',
    'groq',
    'openrouter',
    'ollama',
  ];

  static const models = <LlmModel>[
    LlmModel(
      id: 'gemini-2.5-flash',
      label: 'Gemini 2.5 Flash',
      provider: 'gemini',
      contextK: 1000,
      note: 'Fast default · Google',
    ),
    LlmModel(
      id: 'gemini-2.0-flash',
      label: 'Gemini 2.0 Flash',
      provider: 'gemini',
      contextK: 1000,
      note: 'Fallback cascade',
    ),
    LlmModel(
      id: 'llama-3.1-8b-instant',
      label: 'Llama 3.1 8B Instant',
      provider: 'groq',
      contextK: 128,
      note: 'Speed king · tools',
    ),
    LlmModel(
      id: 'llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B',
      provider: 'groq',
      contextK: 128,
      note: 'Quality on Groq',
    ),
    LlmModel(
      id: 'qwen/qwen3-32b',
      label: 'Qwen3 32B (Groq)',
      provider: 'groq',
      contextK: 128,
      note: 'Strong coding',
    ),
    LlmModel(
      id: 'google/gemini-2.0-flash-001',
      label: 'Gemini Flash (OpenRouter)',
      provider: 'openrouter',
      contextK: 1000,
    ),
    LlmModel(
      id: 'qwen/qwen2.5-coder-7b-instruct',
      label: 'Qwen2.5 Coder 7B',
      provider: 'openrouter',
      contextK: 32,
      note: 'Coding specialist',
    ),
    LlmModel(
      id: 'qwen/qwen3-8b',
      label: 'Qwen3 8B',
      provider: 'openrouter',
      contextK: 128,
      note: 'Balanced agent',
    ),
    LlmModel(
      id: 'meta-llama/llama-3.1-8b-instruct',
      label: 'Llama 3.1 8B',
      provider: 'openrouter',
      contextK: 128,
    ),
    LlmModel(
      id: 'nvidia/llama-3.1-nemotron-nano-8b-v1',
      label: 'Nemotron Nano 8B',
      provider: 'openrouter',
      contextK: 128,
      note: 'NVIDIA Nemotron',
    ),
    LlmModel(
      id: 'qwen2.5-coder:1.5b',
      label: 'Qwen2.5 Coder 1.5B',
      provider: 'ollama',
      contextK: 32,
      local: true,
      note: 'Phone-friendly coding',
    ),
    LlmModel(
      id: 'qwen2.5-coder:3b',
      label: 'Qwen2.5 Coder 3B',
      provider: 'ollama',
      contextK: 32,
      local: true,
    ),
    LlmModel(
      id: 'qwen3:4b',
      label: 'Qwen3 4B',
      provider: 'ollama',
      contextK: 32,
      local: true,
      note: 'Best small agent',
    ),
    LlmModel(
      id: 'nemotron-mini',
      label: 'Nemotron Mini 4B',
      provider: 'ollama',
      contextK: 4,
      local: true,
      note: 'NVIDIA · tools',
      pullTag: 'nemotron-mini',
    ),
    LlmModel(
      id: 'nemotron',
      label: 'Nemotron',
      provider: 'ollama',
      contextK: 128,
      local: true,
      note: 'NVIDIA · long ctx',
      pullTag: 'nemotron',
    ),
    LlmModel(
      id: 'gemma3:4b',
      label: 'Gemma 3 4B',
      provider: 'ollama',
      contextK: 128,
      local: true,
    ),
    LlmModel(
      id: 'llama3.2:3b',
      label: 'Llama 3.2 3B',
      provider: 'ollama',
      contextK: 128,
      local: true,
    ),
  ];

  static List<LlmModel> forProvider(String provider) =>
      models.where((m) => m.provider == provider).toList();

  static LlmModel? byId(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }

  static String defaultModel(String provider) {
    final list = forProvider(provider);
    return list.isEmpty ? '' : list.first.id;
  }
}
