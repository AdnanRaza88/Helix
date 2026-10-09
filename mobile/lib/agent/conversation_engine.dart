import 'dart:async';
import 'dart:convert';

import 'tool_router.dart';

/// One model hop result inside the agent loop.
class ModelHop {
  const ModelHop({this.text = '', this.calls = const []});
  final String text;
  final List<ToolCallRequest> calls;
  bool get hasTools => calls.isNotEmpty;
}

class ToolCallRequest {
  const ToolCallRequest({
    required this.id,
    required this.name,
    required this.arguments,
  });
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

class ToolCallResult {
  const ToolCallResult({
    required this.id,
    required this.name,
    required this.content,
    this.ok = true,
  });
  final String id;
  final String name;
  final String content;
  final bool ok;
}

class LoopAbort {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

/// Provider-agnostic agent loop matching ChatGPT / Claude / Grok agent cycles:
/// prepare → model → tools? → append results → model … until final text or maxTurns.
class ConversationEngine {
  ConversationEngine({
    required this.router,
    this.maxTurns = 12,
  });

  final ToolRouter router;
  final int maxTurns;

  /// [callModel] must return text + optional tool calls for the current messages.
  /// [messages] is mutated in-place with assistant + tool rows in OpenAI shape.
  Future<String> run({
    required List<Map<String, dynamic>> messages,
    required Future<ModelHop> Function(
      List<Map<String, dynamic>> messages,
      List<Map<String, dynamic>> tools,
    ) callModel,
    required List<Map<String, dynamic>> tools,
    void Function(String delta)? onDelta,
    void Function(String toolName)? onTool,
    void Function(String toolName, String result)? onToolResult,
    LoopAbort? abort,
  }) async {
    final token = abort ?? LoopAbort();
    var lastText = '';

    for (var turn = 0; turn < maxTurns; turn++) {
      if (token.cancelled) {
        return lastText.isEmpty ? 'Stopped.' : lastText;
      }

      final hop = await callModel(messages, tools);
      if (token.cancelled) {
        return lastText.isEmpty ? 'Stopped.' : lastText;
      }

      if (hop.text.isNotEmpty) {
        lastText = hop.text;
        onDelta?.call(hop.text);
      }

      if (!hop.hasTools) {
        return lastText.isEmpty ? 'Empty response.' : lastText;
      }

      messages.add({
        'role': 'assistant',
        'content': hop.text.isEmpty ? null : hop.text,
        'tool_calls': hop.calls
            .map((c) => {
                  'id': c.id,
                  'type': 'function',
                  'function': {
                    'name': c.name,
                    'arguments': jsonEncode(c.arguments),
                  },
                })
            .toList(),
      });

      final results = await _runToolsParallel(hop.calls, token, onTool);
      for (final r in results) {
        onToolResult?.call(r.name, r.content);
        messages.add({
          'role': 'tool',
          'tool_call_id': r.id,
          'content': r.content,
        });
      }
    }

    return lastText.isEmpty
        ? 'Reached max agent turns ($maxTurns). Summarize with what you have.'
        : lastText;
  }

  Future<List<ToolCallResult>> _runToolsParallel(
    List<ToolCallRequest> calls,
    LoopAbort token,
    void Function(String toolName)? onTool,
  ) async {
    final futures = <Future<ToolCallResult>>[];
    for (final c in calls) {
      if (token.cancelled) break;
      onTool?.call(c.name);
      futures.add(() async {
        try {
          final out = await router.dispatch(c.name, c.arguments);
          return ToolCallResult(id: c.id, name: c.name, content: out);
        } catch (e) {
          return ToolCallResult(
            id: c.id,
            name: c.name,
            content: jsonEncode({'error': e.toString()}),
            ok: false,
          );
        }
      }());
    }
    if (futures.isEmpty) return const [];
    return Future.wait(futures);
  }
}
