# DECISIONS.md

Newest first. One entry per notable decision: what, why, and what would change it.

## 2026-10-26 — Art: painted characters, flat 2D worlds, story as a motion comic
Owner feedback on 0.3.0: puppets looked "very puppet, body parts scrambled"; the game "looks like a basic game"; the story had "no emotions, no animations, just standing and reading"; the voices whispered and Tamra (a kid) sounded deep. Then, seeing the first painted backdrops: "very bright, the AI orange glow, do not make it look 3D, keep it 2D".
- **Characters** are Gemini-generated painted frame strips (one reference per character, then pose sheets using it), cut and aligned by script. Springs still add squash/lean/recoil; a shader breathes the idle frame (inhale/exhale) and draws a thin rim so the hero reads on busy art. Frame animation was chosen over a cutout rig: AI parts don't joint cleanly, whole-pose sheets stay consistent.
- **Worlds and UI art are flat 2D** (paper-cut look, limited indigo/violet/teal/muted crimson palette, no glow, no orange or yellow light, no 3D). Prompts say so explicitly; reference images are only used for style when they don't get copied.
- **Story** is a motion comic: 16 flat painted panels, camera drift and push-ins, punch-ins with shake, flat particles, portraits and subtitles. Script rewritten for a 12-year-old Tamra with real stakes and a cliffhanger. Seen-flags carry the script version so returning players see the new story once.
- **Voices**: Gemini 3.1 flash TTS with inline emotion tags; every take is judged by Gemini listening (tags read aloud, whispering, age, accent) and retried. Tags like "hushed/distant/mysterious" cause whispering — avoid them.
Changes if: players find the flat worlds and painted characters clash (then flatten the characters too), or a better voice for a child appears.

## 2026-10-25 — Round 4 feel: higher, forgiving jump; difficulty from enemies, not pixels
Owner device test of 0.3.0: "couldn't jump to the upper platform", "villains just stand idle", repeated pit deaths. Cause: apex was ~160 px while levels asked for 150 px step-ups, and `jump_cut` 0.45 halved a short touch tap.
- **Jump:** apex ~230 px (gravity 2400, jump 1050). Releasing early still trims the jump, but never before 0.13 s, so a quick tap rises ~172 px (75%). Cut 0.7. Coyote 0.12 s, buffer 0.15 s. Releasing the jump pad no longer trims UDAAN.
- **Level rule:** a required plain step-up is at most 170 px (tap height), checked by `tests/test_config.gd`. Difficulty comes from enemies, timing and hazards. Maya pits that killed the owner got honest stones or warnings; long stretches got extra lamps.
- **Guidance:** an edge arrow points to the gate while it is off screen. Two deaths within 400 px show the sign of the mantra that crosses that stretch, derived from level data (`src/core/hint_finder.gd`).
- **Enemies:** soldiers see 520 px ahead and notice the hero 250 px behind (375 when he runs), chase at 230 px/s up to 650 px past their patrol, stop at pit edges, hop 130 px ledges, wind up 0.4 s, sometimes thrust twice, and after one stagger keep attacking through further hits for 1.4 s (no more stun-locking with the staff). Archers fire every 1.7 s, lead the hero by half his motion, and hop back or bash when he closes in. New **brute**: 5 HP, slow, ground slam with a 0.8 s red telegraph; its shield turns fire from the front into a stagger only. After a respawn, living guards return to their posts. Contact still does no damage.
- **JWALA:** 2 damage, not an instakill. Chapter 1 guards have 2 HP (one bolt), later guards 3. Prana regen slowed to 1.6/s after 2.5 s; JWALA costs 25; checkpoints refill prana so traversal mantras stay castable.
- **Goal gate:** reaching it ends danger at once. The hero walks into the doorway and the light takes him, then results show. Guards stand down and bolts vanish (the owner was killed behind the results screen).
Changes if: retention or level-fail analytics show the new enemies are too punishing (tune windup, chase speed, combo chance first).
## 2026-10-26 — UI overhaul: real icon sets, copper-and-lacquer theme, journey map
Owner feedback on 0.3.0: hand-drawn icons were unclear, the HUD looked "basic old game", level select should be a map, the daily panel did not say what it was for, the settings heart was confusing, and the gift badge stayed red after claiming. Changes: icons now come from Material Symbols (Apache 2.0) and game-icons.net (CC BY 3.0, credited), never from copyrighted sets (that would risk a Play takedown). Every screen uses the generated panel, medallion and pill textures, with icon + one or two word labels where an icon alone is ambiguous. Motion is flat: scale pulses, fades, a shimmer; no glows or bloom (owner art direction). Level select is a scrollable painted journey map whose node positions live in `config/map.json`, so new art needs no code. The badge bug: `daily_waiting()` counted an unplayed daily trial as "waiting"; a trial is something to play, not to claim, so the badge now shows only for a claimable blessing or finished vow (`DailyRules.claimable`, tested). Changes if: retention data shows the trial needs its own nudge (then a separate, non-red marker).

## 2026-10-25 — Prana: mantras cost energy
The owner asked whether unlimited casting was intended (it wasn't). Their log showed Mirror Marsh cleared in 23 s with JWALA spam. Each mantra now costs Prana (max 100, regenerates 3/s after 1.5 s idle). Orbs and defeated guards refill it. Staff strikes matter again.

## 2026-10-25 — Daily hooks without dark patterns
The owner wants daily reasons to return and a willingness to pay later. The parent strategy forbids dark patterns. So: a blessing cycle that never resets, small vows, a daily trial, stars, upgrades and cosmetic skins. Missing a day costs nothing. Premium items are cosmetic and wait for Play Billing behind StoreService. Changes if: retention data says a stronger hook is needed. Even then, no energy timers and no pay-to-win.

## 2026-10-25 — Story as interactive puppet theatre
The owner wanted a real story told interactively, with choices that converge and the hero's name spoken. Shadow-puppet theatre is the native form for this art style. Sanskrit lines (Upanishad openers) stay as atmosphere.

## 2026-10-25 — Voices: Gemini for story, Sarvam for battle cries
The owner reported KAVACH sounded English-accented and UDAAN doubled. The cries moved to Sarvam's native Hindi voice (8 requests, spaced). Every take is trimmed and transcription-checked. The story keeps Gemini 2.5 TTS, because 3.8 reads style prompts aloud.

## 2026-10-25 — Palette: indigo night, crimson, jade
The owner said the orange read as "Claude-like". Fire stays orange in the world; the UI and skies moved off it.

## 2026-10-25 — SETU builds where you draw
Owner reported "drew a longer line, got a shorter bridge". It was a fixed 420 px bridge. Now the bridge follows the stroke's position, length (80 to 540 px) and slope (up to 40°, so it can be a ramp), anchored at the end nearer the hero, within 700 px. That's more expressive, and it is what the player expects.

## 2026-10-25 — Gesture cutoff 0.78 -> 0.72, RMS-normalized matching
Owner's log showed failures at 0.73 to 0.77. Strokes are now sized by RMS distance from their centroid (rotation-independent), so tilted shapes match. The recognizer also reports the closest guess, so feedback can say "Was that KAVACH?".

## 2026-10-25 — Mantra progression: levels teach, embers buy, players can re-sign
Answers "let users unlock and create their own casts". The Grimoire (`src/core/grimoire.gd`) holds the rules and is unit tested. A custom sign replaces the default (each mantra has one sign, which keeps it learnable). Signs are rejected if they are straight lines, inconsistent, or too close to another mantra's sign. Not done yet: element and form spell crafting. That's a much bigger design, worth doing only if players use custom signs.

## 2026-10-25 — Combat: telegraphed spear thrusts, no contact damage
Touching a guard no longer hurts. Guards wind up (spear glint plus sound) and thrust; a strike interrupts the wind-up. That's fairer on a touchscreen, and it gives fighting a rhythm: read, dodge, punish.

## 2026-10-25 — Characters: Tholu Bommalata leather puppets, procedural
The owner found the silhouettes "stickman, AI-looking". Coloured, perforated, jointed leather puppets are an authentic Indian art form and fit the shadow-play theme. Being procedural, they animate with physics at no asset cost. AI-generated sprites were considered and deferred, because consistency across animation is the hard part.

## 2026-10-25 — Ledges stay one-way
Owner noticed the hero passing up through a floating ledge. That's intended (standard platformer one-way ledges). The owner was told and can ask for solid ledges.

## 2026-10-25 — Diagnostics: crash-safe log file, copied to the clipboard from the game
Owner asked for logging "so you know what broke". We never touch testers' phones, and Android hides app files, so the log is copied to the clipboard from the pause menu or title screen and pasted into any chat app. That needs no USB, no server and no extra permission. Engine errors are captured with Godot's `Logger` API (4.5+). Changes if: a crash-reporting SDK (e.g. Firebase Crashlytics) is added with analytics. Keep the clipboard path anyway; it works offline.

## 2026-10-25 — Sound deferred to after the first APK
Owner instruction: sound is needed, but getting an installable build comes first.

## 2026-10-25 — Engine: Godot 4.7.2 with the Compatibility (OpenGL ES 3) renderer
Small exports, strong 2D, text-based scripts Claude can write and test headless, and free cloud export. The Compatibility renderer instead of Mobile/Vulkan because many low-end Android phones have poor or no Vulkan support. Cost: some effects (2D glow post-processing) are unavailable, so glows are additive sprites. Changes if: a real-device test shows the renderer is the bottleneck.

## 2026-10-25 — Art: procedural first, generated art later
Every visual is drawn in code: shader sky, parallax temple skylines, jointed shadow puppets, particles. The game is playable and good-looking with zero asset files, and the APK stays small. Gemini-generated art can replace pieces later without touching gameplay. Changes if: playtesters find the puppets too plain. Then the hero and enemies get generated art first.

## 2026-10-25 — Design: redeemed asura, mantra gestures + maya, hybrid controls
Owner's picks from the design questions. Gestures use the $1 Unistroke recognizer (orientation-sensitive) with straight lines detected separately. Gestures and on-screen hints come from one source (`GlyphShapes`), so what is taught is what is recognized. Time slows to 35% while drawing so casting mid-jump is fair on a phone.

## 2026-10-25 — Package ID placeholder: com.iiakshat.projecttamra
Needed for debug builds. Must be replaced with the real name's ID **before the first Play upload**; it is permanent after that.

## 2026-10-25 — Debug builds signed with a cached debug key in CI
The same key every build means a new APK installs over the old one and keeps the save. The debug key is not secret. The release (upload) key is separate and will live only in GitHub Secrets plus the owner's backups.

## 2026-10-25 — Genre: 2D platformer with story mode
Owner choice. Platformers show art and animation well, run fine on low-end phones in 2D, and story mode gives retention a structure (chapters). Risk: platformer controls on touchscreens are a common complaint, so control feel is the top design priority. Note: this skips the Phase 0 concept and ad test in the parent file. The owner made the call.

## 2026-10-25 — Theme: asura-flavoured, gods never named
Owner instruction. Evoke the mythology through world, costume and motifs. Never name divine figures anywhere. This lowers religious-sensitivity and trademark risk.

## 2026-10-25 — Asset sources: own work, licensed internet assets, Gemini, Sarvam
Owner instruction. Sarvam is used sparingly because its key is shared with another project (rate limits). All assets are logged in ASSETS.md.

## 2026-10-25 — Git identity: iiakshat / jakshat569@gmail.com, local config
Set on repo init. `.env` and the discarded prototype are git-ignored.

## 2026-10-25 — Discard the HTML prototype
Owner: it was throwaway work, not the target quality. `ra_html.html` stays on disk as reference only. Its name derives from film IP (Ra.One / G.One), so nothing from it ships.

## 2026-10-25 — Theme: mythological, original designs
Ramayana / Indian-epic inspiration. Original names and visuals to avoid trademark and copyright problems. Handle religious figures respectfully (see CLAUDE.md, Content sensitivity). Changes if: Play policy review or owner testing shows backlash risk.

## 2026-10-25 — Quality bar: high-fidelity visuals
Owner wants a visually strong game, not a minimal one. Tension with the low-end-phone and small-APK targets in the parent file. Resolve by choosing art-driven 2D (painted backgrounds, particles, lighting) before 3D unless the genre demands 3D. Revisit once genre is set and a size budget is chosen.

## 2026-10-25 — Offline, no server
No hosting budget, and the parent strategy is offline-first. All content is bundled in the app. Only a future rewarded ad needs internet, at the moment it is shown.

## 2026-10-25 — Cloud builds, no local Android toolchain
The dev laptop is weak. GitHub Actions builds the debug APK (sideloaded to the owner's phone for testing) and the release AAB (for Play). Cost: free for the expected volume. Trade-off: a slower test loop than an emulator. Changes if: the laptop is upgraded or builds exceed free minutes.

## 2026-10-25 — GitHub account: iiakshat, local git config only
Owner instruction. Identity is set per repo, never globally, so other projects keep their own account.

## 2026-10-25 — Ads later, behind an interface
Rewarded video only, AdMob, switchable. Stub from day one so adding the SDK needs no rewrite. Flag privacy and Families-policy issues before adding the SDK (parent file section 7.8).

## 2026-10-25 (superseded above) — Engine comparison that led to Godot
Why Godot 4: about 25-40 MB exports, strong 2D rendering with shaders, lights and particles, text-based scenes that Claude can author, headless export in CI, and an AdMob plugin exists. The editor is a single light executable and optional, since CI can build without it.
Why not Unity: heavy editor, licence activation in CI, large builds.
Why not a WebView stack (Phaser/Pixi in Capacitor): fastest iteration and trivial browser preview, but weaker on low-end phones for rich effects. Still the fallback if the owner wants quick browser preview over visual ceiling.
Confirm after the genre decision. Genre can change this (3D would shift the budget).
