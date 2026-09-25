# Helix Master Plan

See the full plan in the project docs. Phase status as of 2026-09-26:

## Phase A — Foundation (done)
- [x] Split `main.dart` into `ui/` modules
- [x] Add `sqflite` + migrations (`data/db.dart`)
- [x] Port sessions/messages to SQLite
- [x] Bootstrap `docs/CODE_CONNECTION_MAP.md`
- [x] Quarantine root web stubs (`archive/web-stub/`)
- [x] Bump version `1.3.0+4`

## Phase B — Agent core (done)
- [x] `system_prompt.dart`
- [x] `context_compactor.dart`
- [x] `tool_router.dart` + Gemini function calling
- [x] Phase 1 `github_ops` tools
- [x] Confirm UI sheet for mutations
- [x] Version `1.4.0+5`

## Phase C — Chat UX (done)
- [x] Streaming bubbles
- [x] Edit / resend / copy / delete / retry / stop
- [x] Markdown rendering
- [x] Attachment upload
- [x] Tool-run chips
- [x] Version `1.5.0+6`

## Phase D — GitHub Master expansion (done)
- [x] Phase 2 tools (PR, branch, Actions)
- [x] Code review format
- [x] Active repo in session meta
- [x] Version `1.6.0+7`

## Phase E — Surfaces (done)
- [x] `release.yml` + real `apk_url`
- [x] HTML status + `pages.yml`
- [x] Version `1.7.0+8`

## Phase F — Polish (done)
- [x] Phase 3 destructive tools with hard confirm
- [x] Session export
- [x] Basic tests
- [x] App icon + splash
- [x] Version `1.8.0+9`
