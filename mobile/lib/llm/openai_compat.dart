import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../agent/context_compactor.dart';
import '../agent/conversation_engine.dart';
import '../agent/system_prompt.dart';
import '../agent/tool_router.dart';
import '../github.dart';
import '../mcp/mcp_host.dart';
import '../skills/github_ops.dart';

class StreamAbort {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class OpenAiCompatClient {
  OpenAiCompatClient({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.github,
    this.confirm,
    this.providerLabel = 'OpenAI',
    this.extraHeaders = const {},
  }) {
    mcp = McpHost(ops: GithubOps(github), confirm: confirm);
    engine = ConversationEngine(router: mcp.router, maxTurns: 12);
  }

  final String apiKey;
  final String baseUrl;
  final String model;
  final GitHubClient github;
  final MutationConfirm? confirm;
  final String providerLabel;
  final Map<String, String> extraHeaders;
  late final McpHost mcp;
  late final ConversationEngine engine;
  StreamAbort? activeAbort;
  String? activeRepo;

  bool get isLive => apiKey.isNotEmpty;
  ToolRouter get router => mcp.router;

  void bindConfirm(MutationConfirm fn) {
    mcp.router.confirm = fn;
  }

  void stop() {
    activeAbort?.cancel();
  }

  Future<String> chat(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) {
    return runWithTools(userMessage, history: history);
  }

  Future<String> runWithTools(
    String userMessage, {
    List<Map<String, String>> history = const [],
    void Function(String delta)? onDelta,
    void Function(String toolName)? onTool,
    StreamAbort? abort,
  }) async {
    activeAbort = abort ?? StreamAbort();
    final token = activeAbort!;
    if (!isLive) {
      final sim =
          '[$providerLabel SIM] Add API key in Settings for live tools.';
      onDelta?.call(sim);
      return sim;
    }

    final compacted = ContextCompactor.compact(history);
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': HelixPrompt.build(
          githubLive: github.isLive,
          activeRepo: activeRepo,
        ),
      },
    ];
    for (final m in compacted) {
      messages.add({
        'role': m['role'] == 'user' ? 'user' : 'assistant',
        'content': m['text'] ?? '',
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    final tools = mcp.openAiTools();
    final loopAbort = LoopAbort();

    return engine.run(
      messages: messages,
      tools: tools,
      abort: loopAbort,
      onDelta: onDelta,
      onTool: onTool,
      callModel: (msgs, tls) async {
        if (token.cancelled) {
          loopAbort.cancel();
          return const ModelHop();
        }
        return _chatHop(msgs, tls, token);
      },
    );
  }

  Future<ModelHop> _chatHop(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    StreamAbort abort,
  ) async {
    final uri = Uri.parse(
      baseUrl.endsWith('/')
          ? '${baseUrl}chat/completions'
          : '$baseUrl/chat/completions',
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      ...extraHeaders,
    };
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'stream': false,
      'temperature': 0.35,
    });

    final res = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 120));
    if (abort.cancelled) return const ModelHop();
    if (res.statusCode >= 400) {
      throw Exception('$providerLabel ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? const [];
    if (choices.isEmpty) return const ModelHop();
    final msg = choices[0]['message'] as Map<String, dynamic>? ?? {};
    final text = (msg['content'] as String?) ?? '';
    final calls = <ToolCallRequest>[];
    final toolCalls = msg['tool_calls'] as List? ?? const [];
    for (var i = 0; i < toolCalls.length; i++) {
      final c = toolCalls[i];
      if (c is! Map) continue;
      final fn = c['function'] as Map? ?? {};
      Map<String, dynamic> args = {};
      final rawArgs = fn['arguments'];
      if (rawArgs is String && rawArgs.isNotEmpty) {
        try {
          final d = jsonDecode(rawArgs);
          if (d is Map) args = Map<String, dynamic>.from(d);
        } catch (_) {}
      } else if (rawArgs is Map) {
        args = Map<String, dynamic>.from(rawArgs);
      }
      calls.add(ToolCallRequest(
        id: '${c['id'] ?? 'call_$i'}',
        name: '${fn['name'] ?? ''}',
        arguments: args,
      ));
    }
    return ModelHop(text: text, calls: calls);
  }
}
