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

### Status of the release steps (2026-10-28)
| Step | State |
|---|---|
| Name | Tamra (owner). Trademark search still to do, see A below. |
| Release package ID | `com.iiakshat.tamra`, set in the `Android Release` preset. Permanent after the first Play upload. |
| Play account | Personal (12 testers, 14 days). |
| Target audience | 13+ |
| Upload signing key | Done. In `C:/Users/Akshat/tamra-signing/` (outside the repo) and in GitHub Secrets. **Back up that folder in two places** (the password is in KEEP-SAFE.txt). |
| GitHub secrets | All four done (`UPLOAD_KEYSTORE_B64`, `UPLOAD_KEYSTORE_USER`, `UPLOAD_KEYSTORE_PASSWORD`, `GOOGLE_SERVICES_JSON_B64`). Firebase project `tamra-3e246`, Android app `com.iiakshat.tamra`. |
| Privacy policy | Live at https://iiakshat.github.io/tamra-privacy/ (paste this URL into Play Console). |
| Real release bundle | Built 2026-10-28 by the "Release bundle" workflow (dry run off): signed with the upload key (checked), real package and Firebase project inside, 99 MB. Local copy: `_local/builds/tamra-release-0.6.0/tamra-release.aab`. |
| Trademark search | Done by the owner on IP India, results in DECISIONS.md. No conflicting mark found in games or software. Not a legal opinion. |
| Low-end phone test | Pending. Play Console's free pre-launch report also tests on real devices after the first upload. |

### Browser-only steps for the owner

**A. Trademark check (10 minutes).** Go to tmrsearch.ipindia.gov.in, choose "Wordmark", type TAMRA, Class 9 and again Class 41, and look at the results. Then search "Tamra" in the Play Store and on the web. Anything live in games or software under the same name is a problem; an unrelated word in another field is usually not.

**B. Create the Firebase project (about 10 minutes, free plan).**
1. Open console.firebase.google.com and sign in with a Google account (one you will keep).
2. **Create a project**, name it `Tamra`. Leave Gemini assistance off if asked. Keep **Google Analytics enabled**, pick or create an Analytics account, choose India as the location, and **untick every data-sharing option** (Google products, benchmarking, technical support, account specialists), so it matches the privacy policy.
3. Open the project, click the **Android icon** ("Add app"). Package name: `com.iiakshat.tamra` (exactly). Nickname: `Tamra`. Leave the SHA-1 box empty. Click Register app.
4. **Download `google-services.json`**. Skip the "add the SDK" screens (they do not apply to Godot) and finish.
5. Save the file in the game folder (`Gems/Tamra/google-services.json`; git ignores it) and tell Claude. Claude then stores it as the `GOOGLE_SERVICES_JSON_B64` secret and runs the real release build.
6. In the left menu open **Release & Monitor > Crashlytics** and click **Enable** if it offers to.

**C. Host the privacy policy.** Private repos cannot use free GitHub Pages, so the page needs a tiny *public* repo (for example `iiakshat/tamra-privacy`) containing only the policy. It will show the contact email `jakshat569@gmail.com`. Either create that repo yourself and tell Claude, or tell Claude it may create it. The policy URL then goes into Play Console.

**D. Play Console (after B and a real build).** Create the app (name Tamra, game, free), turn **Play App Signing** on, upload the AAB to **Closed testing**, add 15-20 tester emails (12 must stay opted in for 14 continuous days), and fill the forms below. Re-check Google's current rule on the day you start: https://support.google.com/googleplay/android-developer/answer/14151465

**E. Each new build:** bump `version/code` (+1 per upload) and `version/name` in **both** presets, and `config/version` in `project.godot`.

### Running the real release build
Actions tab > "Release bundle" > Run workflow > untick "Dry run". It refuses to run if a secret is missing, if the keystore does not open, or if `google-services.json` is for a different package. Download `tamra-release-aab` and upload it to Play yourself; nothing here publishes anything.

### Forms and answers to prepare
- **Data safety** must match what the game really does. With Firebase: App activity (in-app events), App info and performance (crash logs, diagnostics), Device or other IDs (Firebase app instance ID). Data is collected only if the player agrees, is encrypted in transit, is not shared with third parties for ads, and can be deleted on request. No ads ID, no location, no contacts, no account.
- **Content rating questionnaire:** fantasy violence (stylised, no blood), mythology theme, no gambling, no user-generated content. Re-read the sensitivity notes in CLAUDE.md first.
- **Target audience and Families policy:** decide before filling the form. The hero is a 12-year-old; if children under 13 could be the audience, Google's Families policy applies and Firebase/analytics choices change. The safe default is to target 13+ (or adults) and not use child-directed marketing.
- **Store text:** say "plays fully offline", not "no internet permission".

### Before the first public release
- Licence notices ship in `assets/licenses/` (Godot, Firebase plugin, fonts, icons). Keep `THIRD_PARTY.txt` in step with ASSETS.md.
- Test the release bundle on a real low-end phone (2-3 GB RAM): load time, frame rate, a full level, the data card, Settings, offline.
- Run the closed test with the launch rules from DECISIONS.md (2026-10-28) written down in advance.
