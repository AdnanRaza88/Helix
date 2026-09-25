# Helix Master Plan

See the full plan in the project docs. Phase status as of 2026-09-25:

## Phase A — Foundation (done)
- [x] Split `main.dart` into `ui/` modules
- [x] Add `sqflite` + migrations (`data/db.dart`)
- [x] Port sessions/messages to SQLite
- [x] Bootstrap `docs/CODE_CONNECTION_MAP.md`
- [x] Quarantine root web stubs (`archive/web-stub/`)
- [x] Bump version `1.3.0+4`

## Phase B — Agent core
- [ ] `system_prompt.dart`
- [ ] `context_compactor.dart`
- [ ] `tool_router.dart` + Gemini function calling
- [ ] Phase 1 `github_ops` tools
- [ ] Confirm UI sheet for mutations

## Phase C — Chat UX
- [ ] Streaming bubbles
- [ ] Edit / resend / copy / delete / retry / stop
- [ ] Markdown rendering
- [ ] Attachment upload
- [ ] Tool-run chips

## Phase D — GitHub Master expansion
- [ ] Phase 2 tools (PR, branch, Actions)
- [ ] Code review format
- [ ] Active repo in session meta

## Phase E — Surfaces
- [ ] `release.yml` + real `apk_url`
- [ ] HTML status + `pages.yml`

## Phase F — Polish
- [ ] Phase 3 destructive tools with hard confirm
- [ ] Session export
- [ ] Basic tests
- [ ] App icon + splash
