# Conversation system (v1.10)

## Loop (ChatGPT / Claude / OpenAI Agents style)
1. System prompt + compacted history + user message
2. Model call with tools (tool_choice=auto)
3. If tool_calls → run tools (parallel) → append tool results → goto 2
4. If text only → final answer
5. Cap: 12 turns

## MCP host (in-process)
`mobile/lib/mcp/mcp_host.dart` exposes tools/list + tools/call over the same GithubOps surface used by Flutter clients. OpenAI and Gemini payloads are derived from the same declarations.

## Files
- agent/conversation_engine.dart
- mcp/mcp_host.dart
- llm/openai_compat.dart (uses engine)
- gemini.dart (parallel tools, 12 hops)
- agent/system_prompt.dart (Q&A + tool rules)
