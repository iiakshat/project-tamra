# CLAUDE.md — Game #1: TAMRA

> Live file. Claude keeps this current: update it whenever a decision, status or rule changes, in the same session. The parent file `../CLAUDE.md` holds the business strategy and general rules. This file holds project specifics. If they conflict, the owner's live instructions win, then this file, then the parent.

Last updated: 2026-11-05

## What this is

An offline Android **2D platformer with a story mode**, with **high-end visuals** in a **shadow-puppet + painted-sky** style. The theme is asura-flavoured Indian-epic inspiration: original names, characters and designs. **Gods are never named.** The mythology is evoked, not cited. No server, no forced ads.

- **Hero:** a young asura warrior who refuses the tyrant Smoke King and climbs out of the Ash Pits (a redemption arc). Fights with a copper-banded staff.
- **Signature mechanics:** **mantra gestures** (draw a sign on screen to cast) and **maya illusions** (decoys, false and hidden platforms).
- **Controls:** hybrid. Large left/right pads, a jump pad and a strike pad. Drawing anywhere else casts mantras. Time slows while drawing.
- **Progression:** 8 mantras. Levels teach some; others are bought with embers in the **Mantra Book**, which also has a practice pad and lets players **record their own sign** for any shape mantra. Only new embers bank, so replays can't farm.
- **Characters:** Tholu Bommalata-style leather puppets (`src/fx/puppet.gd`): dyed translucent pieces with punched holes, profile faces, crown and fan. Springs drive the joints (lean, squash and stretch, landing dip, recoil). Hair, sash and jewellery are Verlet chains. The puppet falls apart into pieces on death.
- **Language (owner, 2026-10-25):** voice-over and narration in **Hindi**, with **Sanskrit** used occasionally for effect (mantra invocations, key story beats). On-screen UI text is English for now. Ask the owner before switching UI text to Hindi; that needs a Devanagari font.

Design detail: `docs/GDD.md`. Build, test and release steps: `docs/RELEASE.md`.

The folder is still called `RaOne`. That name came from the discarded prototype and is a trademark risk (Ra.One / G.One are film IP). Do not use it in anything player-facing, in the package ID, or in the store listing. Rename the folder once the real name is chosen.

## Status

- **Round 8 (2026-11-05, v0.6.1):** neutral **age screen** before the data card (`src/ui/age_panel.gd`, `src/core/age_gate.gd`, tested; stores only `age_gate` = ask/ok/under, never the birth year; under 13 means no data sharing ever and no Share row in Settings) and the release build **removes the advertising ID permissions** (`tools/ci/tamra_manifest`; the release job fails if AD_ID returns). Also: Play Console answer sheet `docs/PLAY_CONSOLE.md`, store text `docs/STORE_LISTING.md`, store images in `../builds/store-listing/`. Developer account name is **axnex** (personal; identity verification pending as of 2026-11-05, Create app blocked until it finishes). **The 0.6.1 bundle is built and verified (`../builds/tamra-release-0.6.1/`: signed with the upload key, no AD_ID permission, real Firebase project); the 0.6.0 folder was renamed `...OLD-DO-NOT-UPLOAD`.** Debug arg `--panel=age`.

- **Round 7 (2026-10-28, v0.6.0): release prep**, after a market review (see DECISIONS.md 2026-10-28). (1) **Control options:** Settings > Pad size (S/M/L/XL) and Left-handed; geometry in `src/core/control_layout.gd` (tested). (2) **Analytics with consent:** `FirebaseAnalytics` (`src/platform/firebase_analytics.gd`) wraps the log service and sends to Firebase only when the Godotx Firebase plugin is in the build (release job only) **and** the player said yes on the one-time data card (`src/ui/consent_panel.gd`) or in Settings > Share play data (`share_data` = ask/yes/no). Events are cleaned to Firebase limits (`AnalyticsSanitizer`); `session_start` now carries phone model, Android version, GPU and screen; crash reports carry the level id. **Real release bundle built 2026-10-28** (Release bundle workflow, dry run off; Firebase project `tamra-3e246`; signed with the upload key; copy in `../builds/tamra-release-0.6.0/`). Analytics has **not** been seen working on a real phone yet. Privacy policy is live at https://iiakshat.github.io/tamra-privacy/. All four release secrets are in GitHub. (3) **Release bundle:** `Android Release` preset (AAB) and `.github/workflows/release-aab.yml` with a no-secrets dry-run; the owner-only steps are listed in `docs/RELEASE.md`. (4) `docs/PRIVACY.md` is a draft with `[...]` blanks. (5) Proposed kill/fix launch rules are in DECISIONS.md and need the owner's confirmation. **CI dry run verified 2026-10-28** (branch `release/round7-dryrun`): tests, gradle template, Firebase plugin (core, analytics, crashlytics), AAB export all succeed; the manifest has INTERNET and Firebase collection defaulted off. The dry-run AAB is 99 MB (arm64 + armv7, art and voice dominate), so size is worth watching. 92 tests pass.

- **Round 6 (2026-10-27, v0.5.0):** story flow and ending, from the owner's request. A chapter's story (`c1_intro`, `c2_intro`, `c3_intro`) plays **every time its first level (1, 6, 11) is opened** from the map or Play, with Skip; levels 2-5 etc., retries and daily trials start straight away (logic in `src/core/story_flow.gd`, tested). The short after-level beats stay once-only. **First launch of a new install skips the cloud curtain**: the player goes straight into `c1_intro`, then level 1, and the curtain shows from the next app launch (first-run = no results and the opening story not yet finished or skipped). After the final level, the closing beat is followed by a **"To be continued…" card** (`src/ui/ending_screen.gd`, text in `config/game.json` "ending"). Bug fixed: the last level had no Next button, so its closing beat and an ending could never play; Next is now shown on every non-trial level. Debug args `--ending=1`, `--firstrun=1`. Version 0.5.0 (code 5).

- **Round 5 (2026-10-26, owner's 4th device test):** 15 levels (5 per chapter) with new illusion mechanics (phantom walls, false gates/doors, mirage and veiled guards, false floors, hidden stairs/bridges; see docs/LEVELS.md). UDAAN is a 1.6x leap + 1.5 s glide. Hearts persist (pits cost a heart, no refill on respawn; one rare heart pickup per level); 0 hearts restarts the level. Fatigue-driven panting (rare). JWALA kills burn to ash (src/fx/burn_fx.gd). Story: opening 5 scenes animated (plates + cast cut-outs via the Gemini Batch API, tools/gen_batch.py), progress bar, sound effects; chapter-closing beats moved to each chapter's last level. Launch intro (clouds part, camera pulls back from Tamra), wind in his hair on the title. Hindi level names on the map (config/names_hi.json). Gemini spend: owner wants it minimal — use the Batch API and confirm before large generations.

- **Round 4 (2026-10-26, v0.4.0)**, from the owner's third device test (marks in the approval page + log):
  - **Art:** Gemini-painted characters (hero, soldier, archer, brute, Maa, Smoke King) as frame strips (`src/fx/puppet.gd` keeps the old API); flat 2D chapter backdrops, textured ground with painted edges, painted props. **Owner art rule: flat 2D, no glow, no orange/yellow light, no 3D/AI-render look.** Pipeline: `tools/gen_image.py` → `tools/slice_sheet.py` / `build_chars.sh` / `actors_manifest.py` / `build_env.py`.
  - **Story:** rewritten for a 12-year-old Tamra; motion comic (`src/ui/story_screen.gd`, `config/story.json` v2, panels in `assets/story`). Voices: `tools/tts_story.py` (Gemini 3.1 TTS emotion tags) + `tools/voice_check.py`. Two finale lines are `voice_pending` (Gemini billing cap hit 2026-10-26).
  - **Feel:** jump apex ~230 px with a forgiving tap; aggressive enemies + brute; JWALA 2 dmg; slower prana; goal door walk-in with no danger after; goal arrow and death hints; fall scream only over real pits; softer UI/foley sounds; audible inhale/exhale synced to the chest animation.
  - **UI:** Material Symbols + game-icons.net icons (credited in Settings > Credits), copper/lacquer theme, journey map level select (`config/map.json`), self-explaining daily panel, badge bug fixed.
  - **Blocked:** the Google AI key fell to the free tier (image quota 0; earlier the monthly spend cap). Image/TTS generation fails until the owner restores billing at ai.studio/billing.
  - **Story animation (owner, 2026-10-26: "looks like a presentation, move the characters"):** `story_screen.gd` supports per-panel `actors` (cut-outs on an empty plate) and per-beat `do` actions (enter, move, pose, flip, exit, draw light strokes, beam, smoke, shake). Only scene 1 uses it so far (painted line erased, the sign drawn live, the chosen shape drawn live). The full version needs `tools/gen_story_plates.sh` + `tools/gen_story_cast.sh` (Gemini) then choreography in `config/story.json`. Offline cut-outs (`tools/story_cutout.py`, rembg) proved unreliable on most panels.

- **Round 3 (2026-10-25)**, from the owner's second device test and feedback:
  - Game name **TAMRA** (ताम्र), and the hero is called Tamra in the story.
  - The currency is **Jyoti** (light). Mantras cost **Prana** (energy, regenerates), so they are no longer unlimited.
  - Palette moved to indigo, crimson and jade (the owner found the orange "Claude-like"). The UI is **icons over words**; the owner hates verbosity, so keep text minimal.
  - The story is an **interactive puppet theatre** (`src/ui/story_screen.gd`, `config/story.json`). Choices are flavour only and every path converges. There is a short beat after every level. The cast: Tamra, Maa, the Smoke King, a guard.
  - 9 levels in 3 chapters (Ash Pits, Mirror Marsh, Palace Walls), and they are much harder. New hazards: spikes, flame jets, moving and crumbling ledges, archers. Design notes are in `docs/LEVELS.md`.
  - **Hooks:** a daily blessing (7-step cycle that never resets), 3 daily vows, a daily trial (a cleared level with a twist), stars per level, mantra upgrade ranks, and a skin shop.
  - Premium skins are placeholders behind `StoreService`, ready for in-app purchases. **Cosmetics only, never power for money.**
  - Mute toggles for music and sound. Vocals: jump grunt, fall scream, hurt, panting after long runs, idle breathing.
  - Voice: Gemini 2.5 TTS for story lines (one voice per character), Sarvam bulbul:v3 for the 8 battle cries. All voice is trimmed, OGG, and checked by transcription.
  - Voice pipeline: `tools/tts_gemini.ps1` / `tts_sarvam.ps1` / `tts_vocals.ps1` → `tools/trim_voice.gd` → `tools/tts_check.ps1` (needs WAV) → convert to OGG with `../_tools/ffmpeg/ffmpeg.exe`.

- **Phase 1, round 2 (2026-10-25):** 3 levels (c1_l1 Ash Pits, c1_l2 Chain Ladder, c2_l1 Mirror Marsh), 2 chapter stories, 8 mantras, the Mantra Book, combat (strike, guards with telegraphed spear attacks, health), the puppet characters, and SETU drawn as you draw it.
- Owner's first real-device test (Samsung S-series, 2026-10-25): 120 fps, 0 errors, finished level 1 twice. Their feedback drove this round: short SETU, stickman look, gesture scores of 0.73 to 0.77 just missing the old 0.78 cutoff.
- **Sound (merged 2026-10-25):** the `Audio` autoload plus 41 SFX ids (`config/sounds.json`). Gameplay calls `Sfx.play(id, pos)`, never `Audio` directly. Kenney CC0 foley and synthesized magic, fire and ambience (`tools/synth_audio.gd`), with a tanpura drone. Nobody has listened to it on a phone yet.
- **Voice:** story narration in Hindi (Sanskrit Upanishad openers), shown in Devanagari (Yatra One font) with English subtitles, auto-advancing. The hero speaks each mantra's name on cast (`call_<id>`). Generated with `tools/tts_gemini.ps1` (gemini-2.5-flash-preview-tts; 3.8-tts reads style prompts aloud) and verified by `tools/tts_check.ps1` transcription. Sarvam not used.
- **Verified locally:** 38 automated tests pass. Headless smoke runs are clean. Screenshots confirm the characters, mantras, book, marsh reveal and story.
- **CI verified (2026-10-25):** the "Android build" workflow passes (tests plus signed debug APK, about 1.5 min). The APK is 55 MB because it is a debug build covering both arm64 and armv7. Release AAB per-device downloads will be much smaller. Local copy: `../builds/project-tamra-debug.apk`.
- **Not yet verified:**
  - Feel on a real phone (the owner is testing the first APK).
  - Performance on low-end devices.
- **Diagnostics:** the `GameLog` autoload writes `user://logs/game.log` and flushes every line, so the log survives a crash. It captures every engine error and warning, plus analytics events, a perf sample every 10 s, and device and GPU info. A crashed previous session is flagged and kept as `game.prev.log`. Testers send logs without USB: **Settings → "Copy debug log"** (Settings is on the title screen and in Pause; after a crash the title screen also shows a red log button), then paste into any chat. Debug builds show a red error counter on the HUD.
- `ra_html.html`: discarded prototype. Git-ignored, reference only.

- **UI overhaul (2026-10-26):** themed with `assets/ui` textures (lacquer panel, copper medallions, pills) via `UiKit`; icons are SVGs in `assets/icons` from Material Symbols and game-icons.net (fetched by `tools/fetch_icons.ps1`; add a new icon there, then list it in `tests/test_ui_assets.gd`). Menu: drifting key art, title, Play pill, labelled Map / Mantras / Shop / Daily / Settings. Level select is the journey map (`src/ui/level_select.gd`, layout in `config/map.json`). Settings has Credits (keep `SettingsPanel.credits_text()` in step with ASSETS.md). Style rule: flat 2D, no glows or bloom, no orange.

## Open decisions (do not assume)

| Decision | State | Notes |
|---|---|---|
| Game name | **Tamra (owner, 2026-10-28)** | IP India search done 2026-10-28 (classes 9 and 41): no TAMRA mark for games or apps; unrelated class 9 TAMRA marks exist (cables, eyewear, batteries). Low risk, details in DECISIONS.md. Release package ID is `com.iiakshat.tamra` (permanent after the first Play upload); the debug preset keeps `com.iiakshat.projecttamra`. |
| Hero's name | OPEN | "Tamra" is a placeholder in `config/game.json`. |
| Engine | **Godot 4.7.2, Compatibility renderer** | Recommended by Claude. The owner said "start building", so the build went ahead with it. The owner can still overrule. |
| Play account type | **Personal (owner, 2026-10-28)** | 12 testers for 14 days before production. Target audience 13+ (13-15, 16-17, 18+ bands only). |
| Font | OPEN | Using Godot's built-in default font. Pick an OFL font with an Indian feel and log it in ASSETS.md. |

## Fixed decisions

See `DECISIONS.md` for the reasons.

## Tooling and commands

- The Godot editor/CLI lives **outside the repo** at `../_tools/godot/Godot_v4.7.2-stable_win64_console.exe` (shared by future games). There are no Android tools on the laptop; Android builds run in GitHub Actions.
- Import (after adding or renaming scripts): `godot --headless --path . --import`
- Tests: `godot --headless --path . --script res://tests/run_tests.gd`
- Debug args (debug builds only, after `--`, always `key=value`): `--level=c1_l1 --x=2500 --hold=move_right --cast=line --frames=N --screenshot=path --preview=puppets --book=1 --story=c2_intro --panel=map|daily|shop|settings --card=c2_l2 --focus=c3_l3`. See `src/main.gd`. Use `--fixed-fps 60` for deterministic runs. Delete `%APPDATA%\Godot\app_userdata\Project Tamra\save.json` to test as a new player.
- GDScript gotcha: `:=` on an untyped value (dictionary access, `event.pressed` on an `InputEvent`) is a parse error. Give it an explicit type.

## Code layout

- `src/core/`: pure logic, no scene nodes, unit tested (gesture recognizer, save, config).
- `src/platform/`: analytics, ads and storage interfaces plus their implementations. Swap SDKs here only.
- `src/autoload/`: `Services` (platform instances) and `Game` (configs, save, progression).
- `src/game/`: gameplay entities and the level runner. `src/fx/`: procedural art. `src/ui/`: screens and HUD.
- `config/`: all tuning numbers, levels, story text and mantra definitions.
- `tests/`: the headless test runner and suites.

## Git and accounts

- This project uses the GitHub account **iiakshat** (`jakshat569@gmail.com`), set in this repo's **local** config only (no `--global`).
- Remote: private repo `iiakshat/project-tamra`. Auth uses `GITHUB_TOKEN` in `.env` (classic PAT, `repo` + `workflow` scopes, owner-created 2026-10-25, expires in about 90 days). Pass it per command via an HTTP header. **Never store it in git config, a remote URL, or output.** The `gh` CLI is not installed; use the REST API.
- Getting the APK: push to `main`, wait for the "Android build" workflow, then download the `project-tamra-debug-apk` artifact through the API.
- Never commit keystores, `google-services.json` with real keys, API keys or `.env`. Signing material goes in GitHub Secrets.

## Art and sound sources

1. **Claude's own work:** code-driven effects, procedural silhouettes, UI. This is the current state.
2. **Internet assets with a clear commercial licence:** CC0 first (Kenney, OpenGameArt CC0, Freesound CC0). Log each one in `ASSETS.md`.
3. **Gemini** (`GOOGLE_API_KEY` in `.env`). The owner approved its use for images, characters, scenes and TTS. Record the model and prompt in `ASSETS.md`. Prefer it for painted backdrop layers and story narration. Be careful with character sprites: AI art is hard to keep consistent across animation, and the procedural puppets already animate.
4. **Sarvam** (`SARVAM_API_KEY` in `.env`): Hindi voice and TTS, a strong fit for Hindi narration.

## API usage rules (owner instructions)

- `.env` is git-ignored. Never print, log or commit key values. Keys are used only by local tooling scripts, never shipped in the game.
- **Sarvam: the key is shared with another project in development.** Send only occasional, spaced-out single REST requests, and only when truly needed. No loops, no parallel calls, no tight retries. Finish the script text first, then generate voice in one slow pass.
- Gemini: generate deliberately, not in bulk experiments.

## Content sensitivity

- **Never name gods** anywhere: game text, assets, file names, store listing, marketing. Real epic characters (heroes or villains) are not named either.
- No divine figures as enemies, no gambling or loot boxes tied to sacred imagery, no mocking tone.
- Original designs only. Re-check Google Play content policy before the store listing.

## Keeping this file current

Update this file when: a decision is made, the status changes, a rule is added, or something here turns out to be wrong. Bump "Last updated".
