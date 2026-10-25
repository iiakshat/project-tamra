# CLAUDE.md — Game #1 (working title "Project Tamra")

> Live file. Claude keeps this current: update it whenever a decision, status or rule changes, in the same session. The parent file `../CLAUDE.md` holds the business strategy and general rules. This file holds project specifics. If they conflict, the owner's live instructions win, then this file, then the parent.

Last updated: 2026-10-25

## What this is

An offline Android **2D platformer with a story mode**, with **high-end visuals** in a **shadow-puppet + painted-sky** style. The theme is asura-flavoured Indian-epic inspiration: original names, characters and designs. **Gods are never named.** The mythology is evoked, not cited. No server, no forced ads.

- **Hero:** a young asura warrior who refuses the tyrant Smoke King and climbs out of the Ash Pits (a redemption arc).
- **Signature mechanics:** **mantra gestures** (draw a sign on screen to cast) and **maya illusions** (decoys, false and hidden platforms).
- **Controls:** hybrid. Large left/right pads and a jump pad. Drawing anywhere else casts mantras. Time slows while drawing.

Design detail: `docs/GDD.md`. Build, test and release steps: `docs/RELEASE.md`.

The folder is still called `RaOne`. That name came from the discarded prototype and is a trademark risk (Ra.One / G.One are film IP). Do not use it in anything player-facing, in the package ID, or in the store listing. Rename the folder once the real name is chosen.

## Status

- **Phase 1, vertical slice built:** Chapter 1 Level 1 "The Ash Pits", title screen, story intro, HUD, pause, results, save, analytics stub. Three mantras are live in the level (SETU, CHHAYA, JWALA). KAVACH and DRISHTI are coded but unlocked in later levels.
- **Verified locally:** 17 automated tests pass. Headless smoke runs are clean. Screenshots confirm rendering and all three mantras working end to end.
- **Not yet verified:**
  - The Android export: the CI workflow is written but has not run yet (no GitHub remote).
  - Feel on a real phone.
  - Performance on low-end devices.
- All art is procedural (code-drawn). No image or audio files yet.
- **Diagnostics:** the `GameLog` autoload writes `user://logs/game.log` and flushes every line, so the log survives a crash. It captures every engine error and warning, plus analytics events, a perf sample every 10 s, and device and GPU info. A crashed previous session is flagged and kept as `game.prev.log`. Testers send logs without USB: **Pause → "Copy debug log"** (or the button on the title screen), then paste into any chat. Debug builds show a red error counter on the HUD.
- **PENDING (owner asked, deferred on 2026-10-25): sound effects.** Jumping, running/footsteps, fighting (guard hits, JWALA impacts), mantra casts, pickups, UI, ambience. Do this next after the first APK. Plan: CC0 foley (e.g. Kenney packs) for physical sounds, synthesized tones for magic. Log every file in ASSETS.md.
- `ra_html.html`: discarded prototype. Git-ignored, reference only.

## Open decisions (do not assume)

| Decision | State | Notes |
|---|---|---|
| Game name | **OPEN** | Needs a trademark check (IP India public search, Play Store search). The package ID (`com.iiakshat.projecttamra` placeholder in `export_presets.cfg`) is permanent after the first Play upload. |
| Hero's name | OPEN | "Tamra" is a placeholder in `config/game.json`. |
| Engine | **Godot 4.7.2, Compatibility renderer** | Recommended by Claude. The owner said "start building", so the build went ahead with it. The owner can still overrule. |
| Play account type | OPEN | See parent file section 7. |
| Font | OPEN | Using Godot's built-in default font. Pick an OFL font with an Indian feel and log it in ASSETS.md. |

## Fixed decisions

See `DECISIONS.md` for the reasons.

## Tooling and commands

- The Godot editor/CLI lives **outside the repo** at `../_tools/godot/Godot_v4.7.2-stable_win64_console.exe` (shared by future games). There are no Android tools on the laptop; Android builds run in GitHub Actions.
- Import (after adding or renaming scripts): `godot --headless --path . --import`
- Tests: `godot --headless --path . --script res://tests/run_tests.gd`
- Debug args (debug builds only, after `--`): `--level=c1_l1 --x=2500 --hold=move_right --cast=line --frames=N --screenshot=path`. See `src/main.gd`. Use `--fixed-fps 60` for deterministic runs.
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
3. **Gemini image generation** (`GOOGLE_API_KEY` in `.env`). Record the model and prompt in `ASSETS.md`.
4. **Sarvam** (`SARVAM_API_KEY` in `.env`): Indian-language voice and TTS for story lines.

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
