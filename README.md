# Helix VIP

Glassmorphism GitHub agent for Android with Gemini chat control.

Version **1.3.0+4** — Phase A foundation: SQLite sessions, split UI modules.

## Features
- Glassmorphism UI
- GitHub live control via PAT
- Gemini chat
- Sessions stored in SQLite (migrates old SharedPreferences chats)
- Simulation mode when keys are empty

## Setup keys
1. Open Settings
2. Paste GitHub PAT (`repo` + `user` scopes)
3. Paste Gemini API key from aistudio.google.com/apikey
4. Save → Chat tab becomes live

## APK
GitHub Actions builds `app-release.apk` on every push to `mobile/` or manual dispatch.
Download from the Actions run → Artifacts → **helix-apk**.

## Local
```bash
cd mobile
flutter pub get
flutter build apk --release
```
