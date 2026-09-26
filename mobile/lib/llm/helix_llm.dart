import '../gemini.dart' as g;
import '../github.dart';
import '../agent/tool_router.dart';
import 'openai_compat.dart' as oai;
import 'catalog.dart';

class HelixAbort {
  final g.StreamAbort _g = g.StreamAbort();
  final oai.StreamAbort _o = oai.StreamAbort();
  bool get cancelled => _g.cancelled || _o.cancelled;
  void cancel() {
    _g.cancel();
    _o.cancel();
  }
}

class HelixLlm {
  HelixLlm({
    required this.provider,
    required this.model,
    required this.github,
    this.geminiKey = '',
    this.groqKey = '',
    this.openRouterKey = '',
    MutationConfirm? confirm,
  }) {
    _rebuild(confirm: confirm);
  }

  String provider;
  String model;
  final GitHubClient github;
  String geminiKey;
  String groqKey;
  String openRouterKey;
  g.GeminiClient? _gemini;
  oai.OpenAiCompatClient? _oai;
  String? activeRepo;
  MutationConfirm? _confirm;

  bool get isLive {
    switch (provider) {
      case 'groq':
        return groqKey.isNotEmpty;
      case 'openrouter':
        return openRouterKey.isNotEmpty;
      default:
        return geminiKey.isNotEmpty;
    }
  }

  String get liveLabel {
    if (!isLive) return 'Simulation';
    final m = LlmCatalog.byId(model);
    final p = provider.isEmpty
        ? ''
        : '${provider[0].toUpperCase()}${provider.substring(1)}';
    return '$p · ${m?.label ?? model}';
  }

  void bindConfirm(MutationConfirm fn) {
    _confirm = fn;
    _gemini?.bindConfirm(fn);
    _oai?.bindConfirm(fn);
  }

  void stop() {
    _gemini?.stop();
    _oai?.stop();
  }

  void reconfigure({
    required String provider,
    required String model,
    String? geminiKey,
    String? groqKey,
    String? openRouterKey,
    String? activeRepo,
  }) {
    this.provider = provider;
    this.model = model;
    if (geminiKey != null) this.geminiKey = geminiKey;
    if (groqKey != null) this.groqKey = groqKey;
    if (openRouterKey != null) this.openRouterKey = openRouterKey;
    if (activeRepo != null) this.activeRepo = activeRepo;
    _rebuild(confirm: _confirm);
  }

  void setActiveRepo(String? repo) {
    activeRepo = repo;
    _gemini?.activeRepo = repo;
    _oai?.activeRepo = repo;
  }

  void _rebuild({MutationConfirm? confirm}) {
    _gemini = null;
    _oai = null;
    switch (provider) {
      case 'groq':
        _oai = oai.OpenAiCompatClient(
          apiKey: groqKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: model.isEmpty ? 'llama-3.1-8b-instant' : model,
          github: github,
          confirm: confirm,
          providerLabel: 'Groq',
        )..activeRepo = activeRepo;
        break;
      case 'openrouter':
        _oai = oai.OpenAiCompatClient(
          apiKey: openRouterKey,
          baseUrl: 'https://openrouter.ai/api/v1',
          model: model.isEmpty
              ? 'qwen/qwen2.5-coder-7b-instruct'
              : model,
          github: github,
          confirm: confirm,
          providerLabel: 'OpenRouter',
          extraHeaders: const {
            'HTTP-Referer': 'https://github.com/AdnanRaza88/Helix',
            'X-Title': 'Helix',
          },
        )..activeRepo = activeRepo;
        break;
      default:
        _gemini = g.GeminiClient(
          apiKey: geminiKey,
          github: github,
          confirm: confirm,
        )..activeRepo = activeRepo;
        break;
    }
  }

  Future<String> runWithTools(
    String userMessage, {
    List<Map<String, String>> history = const [],
    void Function(String delta)? onDelta,
    void Function(String toolName)? onTool,
    HelixAbort? abort,
  }) {
    final a = abort ?? HelixAbort();
    if (_oai != null) {
      return _oai!.runWithTools(
        userMessage,
        history: history,
        onDelta: onDelta,
        onTool: onTool,
        abort: a._o,
      );
    }
    return _gemini!.runWithTools(
      userMessage,
      history: history,
      onDelta: onDelta,
      onTool: onTool,
      abort: a._g,
    );
  }
}
