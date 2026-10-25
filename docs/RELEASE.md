# Build, test and release

No USB, no Android Studio, no emulator. The laptop edits code; GitHub builds the app.

## Everyday loop
1. Change code or config. Run the tests locally:
   `..\_tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`
2. Optional, play on the laptop: run the same exe with `--path .` (opens a window). Keyboard: A/D or arrows move, Space jumps, Esc pauses. Draw mantras with the mouse.
3. Push to `main`. GitHub Actions ("Android build") runs the tests and builds `project-tamra-debug.apk`.
4. Open the run on GitHub, download the **project-tamra-debug-apk** artifact, unzip, and send the APK to your phone (Drive, Telegram, etc.).
5. On the phone, tap the APK and allow "install unknown apps" for that app once. Later builds install as updates and keep your save.

## Release (Play Store). Not set up yet; do this when the name is final
1. Replace `package/unique_name` in `export_presets.cfg` with the final ID. **It can never change after the first upload.**
2. Create an **upload key**: `keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`
   - Keep it **out of the repo**. Back it up in two places (e.g. password manager plus offline drive).
   - Add it to GitHub Secrets as base64 (`UPLOAD_KEYSTORE_B64`, `UPLOAD_KEYSTORE_USER`, `UPLOAD_KEYSTORE_PASSWORD`).
3. Turn on **Play App Signing** in Play Console. Google then holds the real app-signing key, and a lost upload key can be reset.
4. Add an **"Android Release" preset**: AAB format, which needs `gradle_build/use_gradle_build=true` and the Android build template. Also add a release job that exports with `--export-release` using the `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars from those secrets.
5. Bump `version/code` (integer, +1 every upload) and `version/name`.
6. Upload the AAB to the **closed testing** track first (12+ testers for 14 days on a new personal account; see the parent CLAUDE.md).

## Before the first public release
- Credits screen with the Godot MIT notice (see ASSETS.md).
- Privacy policy URL (GitHub Pages is free). The Data safety form must match what the analytics SDK collects.
- Content rating questionnaire. Review the religious-content sensitivity notes in CLAUDE.md.
