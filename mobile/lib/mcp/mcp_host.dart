import 'dart:convert';

import '../skills/github_ops.dart';
import '../skills/github_schemas.dart';
import '../agent/tool_router.dart';

/// In-process MCP-style tool host for Helix.
/// Exposes tools/list and tools/call so the agent loop and future remote MCP share one surface.
class McpHost {
  McpHost({required this.ops, this.confirm})
      : router = ToolRouter(ops: ops, confirm: confirm);

  final GithubOps ops;
  final MutationConfirm? confirm;
  final ToolRouter router;

  static const protocolVersion = '2024-11-05';
  static const serverName = 'helix-github';
  static const serverVersion = '1.0.0';

  Map<String, dynamic> initialize() => {
        'protocolVersion': protocolVersion,
        'serverInfo': {'name': serverName, 'version': serverVersion},
        'capabilities': {
          'tools': {'listChanged': false},
        },
      };

  List<Map<String, dynamic>> listTools() {
    return GithubSchemas.declarations.map((d) {
      final name = '${d['name'] ?? ''}';
      final desc = '${d['description'] ?? ''}';
      final params = d['parameters'] is Map
          ? Map<String, dynamic>.from(d['parameters'] as Map)
          : <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            };
      return {
        'name': name,
        'description': desc,
        'inputSchema': params,
      };
    }).toList();
  }

  /// OpenAI tools[] payload for chat.completions.
  List<Map<String, dynamic>> openAiTools() {
    return router.functionDeclarations
        .map((d) => {
              'type': 'function',
              'function': d,
            })
        .toList();
  }

  /// Gemini functionDeclarations payload.
  List<Map<String, dynamic>> geminiTools() {
    return [
      {'functionDeclarations': router.functionDeclarations},
    ];
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final raw = await router.dispatch(name, arguments);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'result': decoded};
    } catch (_) {
      return {'result': raw};
    }
  }

  Future<String> callToolRaw(
    String name,
    Map<String, dynamic> arguments,
  ) {
    return router.dispatch(name, arguments);
  }
}
