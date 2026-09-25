# Helix

**Helix — GitHub command surface (Flutter mobile + web)**

Lightweight GitHub agent for Android. Browse repos, set a personal access token, and work in simulation or live mode.

## Mobile (Flutter APK)

### Build APK via GitHub Actions
1. Push any change under `mobile/` (or run the workflow manually).
2. Go to **Actions** tab → **Build Helix APK**.
3. Download the `helix-apk` artifact when the job finishes.

APKs are also available as workflow artifacts for 30 days.

### Local build
```bash
cd mobile
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

### Features
- Material 3 light theme
- Simulation mode (no token needed)
- Live GitHub mode with Personal Access Token
- Repo list sorted by recent activity
- Token stored via shared_preferences

## Web (React / Vite)
See root `package.json` and `src/` for the web command surface.

## License
Personal / private use.
