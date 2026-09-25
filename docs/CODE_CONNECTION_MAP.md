# Code Connection Map — Helix

Last updated: 2026-09-26 01:05 PKT  
Status: Phase E complete

## 1. Entry Points
- `mobile/lib/main.dart` — Flutter `main()` → `HelixApp` → `ui/shell.dart` `Shell`
- `.github/workflows/build-apk.yml` — CI APK artifact build
- `.github/workflows/release.yml` — tag / dispatch GitHub Release + helix.apk
- `.github/workflows/pages.yml` — deploy `site/` to GitHub Pages
- `site/index.html` — public status surface
- `archive/web-stub/` — quarantined root web scaffolding (not product)

## 2. File Inventory (mobile hot path)

| Path | Role | Key exports | Depends on | Depended by |
|------|------|-------------|------------|-------------|
| `mobile/lib/main.dart` | App bootstrap | `HelixApp` | ui/shell, ui/theme | entry |
| `mobile/lib/ui/theme.dart` | Color tokens | `H` | flutter | all UI |
| `mobile/lib/ui/widgets/glass.dart` | Glass surfaces | `GlassCard`, `GradientBg` | theme | pages, shell |
| `mobile/lib/ui/widgets/update_banner.dart` | OTA banner | `UpdateBanner` | updater, theme | shell |
| `mobile/lib/ui/shell.dart` | Tabs + keys + clients + active repo | `Shell` | github, gemini, pages | main |
| `mobile/lib/ui/home_page.dart` | Home | `HomePage` | theme, glass | shell |
| `mobile/lib/ui/chat/chat_page.dart` | Chat UX + stream + session meta repo | `ChatPage` | gemini, sessions, flutter_markdown, file_picker | shell |
| `mobile/lib/ui/repos_page.dart` | Repo list + select active | `ReposPage` | theme, glass | shell |
| `mobile/lib/ui/settings_page.dart` | PAT / Gemini keys | `SettingsPage` | theme, glass | shell |
| `mobile/lib/sessions.dart` | SessionStore facade | `SessionStore` | data/session_repo | chat_page, shell |
| `mobile/lib/data/db.dart` | sqflite schema v1 | `HelixDb` | sqflite, path | session_repo |
| `mobile/lib/data/models.dart` | Session / message / meta repo | `ChatSession`, `ChatMessage` | dart:convert | sessions |
| `mobile/lib/data/session_repo.dart` | SQLite CRUD + tool/file encode | `SessionRepo` | db, models | sessions |
| `mobile/lib/github.dart` | REST client Phase 1+2 | `GitHubClient` | http | shell, github_ops |
| `mobile/lib/gemini.dart` | LLM + SSE stream + tools | `GeminiClient`, `StreamAbort` | http, agent, skills | shell, chat |
| `mobile/lib/agent/system_prompt.dart` | Canonical prompt | `HelixPrompt` | — | gemini |
| `mobile/lib/agent/context_compactor.dart` | History budget | `ContextCompactor` | — | gemini |
| `mobile/lib/agent/tool_router.dart` | Dispatch + confirm | `ToolRouter`, `MutationConfirm` | github_ops, schemas | gemini, chat |
| `mobile/lib/agent/review_format.dart` | Review skeleton | `ReviewFormat` | — | github_ops |
| `mobile/lib/skills/github_schemas.dart` | Gemini tool defs | `GithubSchemas` | — | tool_router, ops |
| `mobile/lib/skills/github_ops.dart` | Phase 1+2 tool impl | `GithubOps` | github, schemas, review_format | tool_router |
| `mobile/lib/updater.dart` | Remote version check | `UpdateChecker` | http | shell |
| `mobile/pubspec.yaml` | Deps / version | `1.7.0+8` | — | CI |
| `mobile/version.json` | OTA metadata | version 1.7.0 build 8 | — | updater |
| `site/index.html` | Public status | — | — | pages.yml |

## 3. Import / Call Graph
- `main` → ui/shell, ui/theme
- `shell` → github, gemini, updater, home, chat, repos, settings; writes `helix_active_repo`
- `repos_page.onSelect` → shell._setActiveRepo → gemini.activeRepo + prefs
- `chat_page` → sessions meta owner/repo, gemini.runWithTools
- `gemini` → HelixPrompt(activeRepo), ContextCompactor, ToolRouter → GithubOps → GitHubClient
- Phase 2 tools: list/get/create pull, list/create branch, list workflows/runs, trigger workflow, review_code
- `UpdateChecker` reads raw `mobile/version.json`; `apk_url` is latest-release download
- `release.yml` builds APK and attaches `helix.apk` to a GitHub Release
- `pages.yml` publishes `site/` via Actions Pages

## 4. Critical Shared Contracts
- Prefs keys: `github_token`, `gemini_key`, `helix_active_session_id`, `helix_sessions_sqlite_v1`, `helix_active_repo` (`owner/repo`)
- Session meta JSON: `{"owner":"...","repo":"..."}` via `ChatSession.setActiveRepo` / `activeRepo`
- SQLite schema version: `HelixDb.schemaVersion = 1`
- Gemini tools: names in `GithubSchemas.declarations` must match `GithubOps.run` switch
- Confirm required: `github_create_issue`, `github_put_file`, `github_create_pull`, `github_create_branch`, `github_trigger_workflow`
- Review output: `ReviewFormat` headings
- `ChatSession.historyForApi()` still `{role, text}`
- Tool/file sidecar encoded in message content as `__tools__:` / `__files__:` lines
- `version.json`: version, build, notes, apk_url
- Canonical APK URL: `https://github.com/AdnanRaza88/Helix/releases/latest/download/helix.apk`

## 5. Change Impact Rules
- Changing tool names/args → schemas + github_ops + this map
- Changing `GitHubClient` signatures → github_ops
- Changing session models → session_repo, sessions, chat_page
- Schema change → bump `HelixDb.schemaVersion` and add `onUpgrade`
- Bumping app version → `pubspec.yaml` + `version.json` together
- Changing APK filename → release.yml + version.json apk_url + site/index.html
- Multi-file edits must update this map same turn

## 6. Recent Changes Log
- 2026-09-26 — Phase E: release.yml, pages.yml, site/index.html, apk_url latest/download/helix.apk, version 1.7.0+8
- 2026-09-26 — Phase D: PR/branch/Actions tools, review format, active repo meta, version 1.6.0+7
- 2026-09-25 — Phase C: streaming, message actions, markdown, attachments, tool chips, version 1.5.0+6
- 2026-09-25 — Phase B: system prompt, compactor, function calling, Phase-1 ops, confirm sheet, version 1.4.0+5
- 2026-09-25 — Phase A: split UI, SQLite sessions, quarantine web stub, version 1.3.0+4
- 2026-09-25 — Initial map from live repo tree (pre Phase A)
- 2026-09-25 — HELIX_MASTER_PLAN.md written

## Related
- Full roadmap: `docs/HELIX_MASTER_PLAN.md`
- Prompt copy: `docs/SYSTEM_PROMPT.md`
- Skills: `github-agent`, `code-connection-map`
