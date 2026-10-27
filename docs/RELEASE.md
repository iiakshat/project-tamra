# Build, test and release

No USB, no Android Studio, no emulator. The laptop edits code; GitHub builds the app.

## Everyday loop
1. Change code or config. Run the tests locally:
   `..\_tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`
2. Optional, play on the laptop: run the same exe with `--path .` (opens a window). Keyboard: A/D or arrows move, Space jumps, Esc pauses. Draw mantras with the mouse.
3. Push to `main`. GitHub Actions ("Android build") runs the tests and builds `project-tamra-debug.apk`.
4. Open the run on GitHub, download the **project-tamra-debug-apk** artifact, unzip, and send the APK to your phone (Drive, Telegram, etc.).
5. On the phone, tap the APK and allow "install unknown apps" for that app once. Later builds install as updates and keep your save.

## Release (Play Store)

The release bundle (AAB) is built by `.github/workflows/release-aab.yml`. It installs the gradle template and the Firebase plugin on the build machine only (`tools/ci/`), so the repo and the debug build stay simple. Nothing uploads to Play automatically.

### What is already done
- `Android Release` preset in `export_presets.cfg`: AAB, gradle build, arm64 + armv7, INTERNET permission (Firebase needs it; the game still plays fully offline).
- Consent-gated analytics and crash reports, a data-sharing card and a Settings switch (see DECISIONS.md, 2026-10-28).
- A **dry-run** mode: push a branch named `release/<anything>` (or run the workflow by hand with "Dry run" ticked). It signs with a throwaway key and a placeholder Firebase config and proves the whole chain works. Its bundle is not uploadable.

### What only the owner can do (in this order)
1. **Pick the name** and check it (IP India public search, Play Store search, a web search). Then set `package/unique_name` in **both** presets in `export_presets.cfg` and `package/name`. **The package ID is permanent after the first Play upload.** Do not use anything with `RaOne`.
2. **Decide the Play account type** (personal needs the 12 testers for 14 days; organization is exempt but needs business verification, in India usually a D-U-N-S number). Re-check Google's current rule on the day you start: https://support.google.com/googleplay/android-developer/answer/14151465
3. **Create the Firebase project** at console.firebase.google.com (free Spark plan): add an Android app with the final package ID, turn on Analytics, download `google-services.json`. Never commit it (it is git-ignored). Encode it: `base64 -w0 google-services.json` (on Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json"))`).
4. **Create the upload key**, outside the repo: `keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`. Back it up in two places. Turn on **Play App Signing** in Play Console so a lost upload key can be reset.
5. **Add four GitHub repository secrets** (Settings > Secrets and variables > Actions): `UPLOAD_KEYSTORE_B64` (the keystore, base64), `UPLOAD_KEYSTORE_USER` (the alias, `upload`), `UPLOAD_KEYSTORE_PASSWORD`, `GOOGLE_SERVICES_JSON_B64`.
6. **Host the privacy policy**: finish `docs/PRIVACY.md` (name, contact email), publish it with GitHub Pages, and paste the URL into Play Console.
7. **Run the workflow** (Actions > Release bundle > Run workflow, untick "Dry run"). Download `tamra-release-aab`. It refuses to run if a secret is missing or `google-services.json` is for a different package.
8. **Play Console:** create the app, upload the AAB to **Closed testing**, add 15-20 testers (12 must stay opted in for 14 continuous days), fill in the forms below, and start the clock.
9. Bump `version/code` (+1 for every upload, in both presets) and `version/name` for each new build. `project.godot` `config/version` should match.

### Forms and answers to prepare
- **Data safety** must match what the game really does. With Firebase: App activity (in-app events), App info and performance (crash logs, diagnostics), Device or other IDs (Firebase app instance ID). Data is collected only if the player agrees, is encrypted in transit, is not shared with third parties for ads, and can be deleted on request. No ads ID, no location, no contacts, no account.
- **Content rating questionnaire:** fantasy violence (stylised, no blood), mythology theme, no gambling, no user-generated content. Re-read the sensitivity notes in CLAUDE.md first.
- **Target audience and Families policy:** decide before filling the form. The hero is a 12-year-old; if children under 13 could be the audience, Google's Families policy applies and Firebase/analytics choices change. The safe default is to target 13+ (or adults) and not use child-directed marketing.
- **Store text:** say "plays fully offline", not "no internet permission".

### Before the first public release
- Licence notices ship in `assets/licenses/` (Godot, Firebase plugin, fonts, icons). Keep `THIRD_PARTY.txt` in step with ASSETS.md.
- Test the release bundle on a real low-end phone (2-3 GB RAM): load time, frame rate, a full level, the data card, Settings, offline.
- Run the closed test with the launch rules from DECISIONS.md (2026-10-28) written down in advance.
