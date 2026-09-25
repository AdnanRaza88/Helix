# Code Connection Map — Helix

Last updated: 2026-09-25 22:05 PKT  
Status: Phase B complete

## 1. Entry Points
- `mobile/lib/main.dart` — Flutter `main()` → `HelixApp` → `ui/shell.dart` `Shell`
- `.github/workflows/build-apk.yml` — CI APK build
- `archive/web-stub/` — quarantined root web scaffolding (not product)

## 2. File Inventory (mobile hot path)

| Path | Role | Key exports | Depends on | Depended by |
|------|------|-------------|------------|-------------|
| `mobile/lib/main.dart` | App bootstrap | `HelixApp` | ui/shell, ui/theme | entry |
| `mobile/lib/ui/theme.dart` | Color tokens | `H` | flutter | all UI |
| `mobile/lib/ui/widgets/glass.dart` | Glass surfaces | `GlassCard`, `GradientBg` | theme | pages, shell |
| `mobile/lib/ui/widgets/update_banner.dart` | OTA banner | `UpdateBanner` | updater, theme | shell |
| `mobile/lib/ui/shell.dart` | Tabs + keys + clients | `Shell` | github, gemini, pages | main |
| `mobile/lib/ui/home_page.dart` | Home | `HomePage` | theme, glass | shell |
| `mobile/lib/ui/chat/chat_page.dart` | Chat + confirm sheet | `ChatPage` | gemini, sessions | shell |
| `mobile/lib/ui/repos_page.dart` | Repo list | `ReposPage` | theme, glass | shell |
| `mobile/lib/ui/settings_page.dart` | PAT / Gemini keys | `SettingsPage` | theme, glass | shell |
| `mobile/lib/sessions.dart` | SessionStore facade | `SessionStore` | data/session_repo | chat_page |
| `mobile/lib/data/db.dart` | sqflite schema v1 | `HelixDb` | sqflite, path | session_repo |
| `mobile/lib/data/models.dart` | Session / message | `ChatSession`, `ChatMessage` | — | sessions |
| `mobile/lib/data/session_repo.dart` | SQLite CRUD | `SessionRepo` | db, models | sessions |
| `mobile/lib/github.dart` | REST client Phase 1 | `GitHubClient` | http | shell, github_ops |
| `mobile/lib/gemini.dart` | LLM + function calling | `GeminiClient` | http, agent, skills | shell, chat |
| `mobile/lib/agent/system_prompt.dart` | Canonical prompt | `HelixPrompt` | — | gemini |
| `mobile/lib/agent/context_compactor.dart` | History budget | `ContextCompactor` | — | gemini |
| `mobile/lib/agent/tool_router.dart` | Dispatch + confirm | `ToolRouter`, `MutationConfirm` | github_ops, schemas | gemini, chat |
| `mobile/lib/skills/github_schemas.dart` | Gemini tool defs | `GithubSchemas` | — | tool_router, ops |
| `mobile/lib/skills/github_ops.dart` | Phase 1 tool impl | `GithubOps` | github, schemas | tool_router |
| `mobile/lib/updater.dart` | Remote version check | `UpdateChecker` | http | shell |
| `mobile/pubspec.yaml` | Deps / version | `1.4.0+5` | — | CI |
| `mobile/version.json` | OTA metadata | version 1.4.0 build 5 | — | updater |

## 3. Import / Call Graph
- `main` → ui/shell, ui/theme
- `shell` → github, gemini, updater, home, chat, repos, settings
- `chat_page` → sessions, gemini.bindConfirm → modal confirm
- `gemini` → HelixPrompt, ContextCompactor, ToolRouter → GithubOps → GitHubClient
- Regex tool routing removed
- No Phase 2 tools yet (PR/branch/Actions)

## 4. Critical Shared Contracts
- Prefs keys: `github_token`, `gemini_key`, `helix_active_session_id`, `helix_sessions_sqlite_v1`
- SQLite schema version: `HelixDb.schemaVersion = 1`
- Gemini tools: names in `GithubSchemas.declarations` must match `GithubOps.run` switch
- Confirm required: `github_create_issue`, `github_put_file`
- `ChatSession.historyForApi()` still `{role, text}`
- `version.json`: version, build, notes, apk_url

## 5. Change Impact Rules
- Changing tool names/args → schemas + github_ops + this map
- Changing `GitHubClient` signatures → github_ops
- Changing session models → session_repo, sessions, chat_page
- Schema change → bump `HelixDb.schemaVersion` and add `onUpgrade`
- Bumping app version → `pubspec.yaml` + `version.json` together
- Multi-file edits must update this map same turn

## 6. Recent Changes Log
- 2026-09-25 — Phase B: system prompt, compactor, function calling, Phase-1 ops, confirm sheet, version 1.4.0+5
- 2026-09-25 — Phase A: split UI, SQLite sessions, quarantine web stub, version 1.3.0+4
- 2026-09-25 — Initial map from live repo tree (pre Phase A)
- 2026-09-25 — HELIX_MASTER_PLAN.md written

## Related
- Full roadmap: `docs/HELIX_MASTER_PLAN.md`
- Prompt copy: `docs/SYSTEM_PROMPT.md`
- Skills: `github-agent`, `code-connection-map`
