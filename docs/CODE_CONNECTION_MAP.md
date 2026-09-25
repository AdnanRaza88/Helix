# Code Connection Map — Helix

Last updated: 2026-09-25 21:15 PKT  
Status: Phase A complete

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
| `mobile/lib/ui/chat/chat_page.dart` | Chat + sessions UI | `ChatPage` | gemini, sessions | shell |
| `mobile/lib/ui/repos_page.dart` | Repo list | `ReposPage` | theme, glass | shell |
| `mobile/lib/ui/settings_page.dart` | PAT / Gemini keys | `SettingsPage` | theme, glass | shell |
| `mobile/lib/sessions.dart` | SessionStore facade + prefs migrate | `SessionStore` | data/session_repo, models, shared_preferences | chat_page |
| `mobile/lib/data/db.dart` | sqflite open + schema v1 | `HelixDb` | sqflite, path | session_repo |
| `mobile/lib/data/models.dart` | Session / message models | `ChatSession`, `ChatMessage` | — | sessions, session_repo |
| `mobile/lib/data/session_repo.dart` | SQLite CRUD | `SessionRepo` | db, models, uuid | sessions |
| `mobile/lib/github.dart` | REST client | `GitHubClient` | http | shell, gemini |
| `mobile/lib/gemini.dart` | LLM + regex tools | `GeminiClient` | http, github | shell, chat |
| `mobile/lib/updater.dart` | Remote version check | `UpdateChecker` | http, package_info_plus | shell |
| `mobile/pubspec.yaml` | Deps / version | `1.3.0+4` | — | CI |
| `mobile/version.json` | OTA metadata | version 1.3.0 build 4 | — | updater |

## 3. Import / Call Graph
- `main` → ui/shell, ui/theme
- `shell` → github, gemini, updater, home, chat, repos, settings, update_banner
- `chat_page` → sessions.SessionStore → SessionRepo → HelixDb
- `sessions` migrates `helix_chat_sessions_v1` prefs JSON once into SQLite
- `gemini` → github (tools + mode flag)
- No `agent/` package yet (Phase B)

## 4. Critical Shared Contracts
- Prefs keys: `github_token`, `gemini_key`, `helix_active_session_id`, `helix_sessions_sqlite_v1`
- Legacy prefs JSON: `helix_chat_sessions_v1` (read-once migrate)
- SQLite schema version: `HelixDb.schemaVersion = 1` (`sessions`, `messages`, `tool_runs`, `attachments`)
- `ChatSession.historyForApi()` still `{role, text}` for Gemini
- `version.json`: version, build, notes, apk_url
- Tool surface today: regex in `gemini.runWithTools` (Phase B replaces)

## 5. Change Impact Rules
- Changing `GitHubClient` signatures → `gemini.dart` + future `github_ops`
- Changing session models → `session_repo`, `sessions`, `chat_page`
- Schema change → bump `HelixDb.schemaVersion` and add `onUpgrade`
- Bumping app version → `pubspec.yaml` + `version.json` together
- Multi-file edits must update this map same turn

## 6. Recent Changes Log
- 2026-09-25 — Phase A: split UI, SQLite sessions, quarantine web stub, version 1.3.0+4
- 2026-09-25 — Initial map from live repo tree (pre Phase A)
- 2026-09-25 — HELIX_MASTER_PLAN.md written

## Related
- Full roadmap: `docs/HELIX_MASTER_PLAN.md`
- Skills: `github-agent`, `code-connection-map`
