# DECISIONS.md

Newest first. One entry per notable decision: what, why, and what would change it.

## 2026-11-05 — Neutral age screen before data sharing, advertising ID permissions removed (v0.6.1)
Context: the hero is a 12-year-old in a friendly painted style, so Google may judge Tamra as appealing to children even with a 13+ target. Its Families guidance for mixed audiences is a neutral age screen, and SDKs not approved for child-directed use should sit behind it.
- **Age screen** (`AgePanel`, logic in `AgeGate`, tested): asks for a birth year starting from 2000 (deliberately not near the cut-off), stores only "ok" or "under" (never the year), and leans cautious: only a birth year at least 14 years ago counts as certainly 13 or older. Under 13: data sharing is switched off for good, the data card and the Settings switch never appear, and the game plays the same. Dismissing without answering leaves the question open until next launch. Existing testers see it once. Re-asking after "under" is blocked by storing the result, so retrying does not unlock sharing; a reinstall still resets it, which is accepted.
- **Rule:** `Game.sharing_allowed()` is true only when age is "ok" and consent is "yes"; analytics is switched on or off from that alone. Settings > Share play data is shown only to players found to be 13 or older.
- **Advertising ID:** `tools/ci/tamra_manifest` (a tiny export plugin, release build only) removes `com.google.android.gms.permission.AD_ID` and `android.permission.ACCESS_ADSERVICES_AD_ID`, which Firebase adds. The release job fails if "AD_ID" is still in the manifest. Why: the game never reads the advertising ID and denies ad storage; with the permission gone the Play Console question is answered No and the privacy policy line stays true. If a rewarded-ad SDK is added later, this must be revisited (ads normally need it).
- Version 0.6.1 (code 7). The 0.6.0 bundle in `_local/builds/tamra-release-0.6.0/` still has the permission and no age screen: do not upload it.
- Privacy policy updated (live page and `docs/PRIVACY.md`).

## 2026-10-28 — Trademark search for TAMRA (IP India public search, owner-run) and what it means
Search: wordmark, classes 9 and 41 (exports `WordMarkReport*.xlsx`). Findings, read by Claude, not a legal opinion:
- **No TAMRA mark for games, apps or entertainment.** Class 41 has no TAMRA itself; the hits are education brands built on other words (TAMRAPARNI, TAMRALIPTA ..., PREETAM RAJASTHAN).
- **Class 9 has TAMRA marks for unrelated goods:** TAMRA / TAMRA (label) by Tamra Dhatu Udyog (electric wires and cables; one registered to 2036, one objected), TAMRA by Neena Ajmani (sunglasses, eyeglasses, laptop cases; objected), SF SONIC TAMRA by Exide (batteries), TAMRA by PSC Electronics (telephones; shows validity to 2000, so probably lapsed), TAMRA GOLD POLY (electrical; valid to 2023). "Tamra" is the Hindi word for copper, which is why metal and electrical firms use it.
- **Risk read:** low for a game, because the goods and services differ. It is not zero: class 9 is broad (it includes downloadable software) and a later filing by the owner could draw an objection or opposition from a same-name registrant. Phonetic variants (for example Tamara) were not searched; the Play Store and web were not searched by Claude beyond one quick pass.
- **Practical rules:** use "Tamra" only for the game (never for hardware or merchandise like cables, batteries, eyewear), keep the Devanagari ताम्र and the art as part of the brand, and consider filing the owner's own application in classes 9 and 41 (fee and timing to confirm on the IP India site) once the game is live. A trademark attorney can give a real opinion for a small fee if the game takes off.

## 2026-10-28 — Owner decisions for release: name Tamra, personal Play account, 13+, release package ID
- **Name: Tamra** (owner: "keep Tamra"). The trademark search (IP India public search, classes 9 and 41, plus Play Store search) still has to be done by the owner in a browser; a quick web search found no existing "Tamra" game, which is not a legal check.
- **Package ID for the release build: `com.iiakshat.tamra`.** The debug preset keeps `com.iiakshat.projecttamra` so test installs still update in place, and the two can sit side by side on a phone. **Permanent after the first Play upload.** Firebase's Android app must be registered with this exact ID. The release CI job now reads the ID from the release preset (it had been reading the first preset in the file).
- **Play account: personal.** So the closed test (12+ testers opted in for 14 continuous days, per app) is required before production.
- **Target audience: 13+.** Choose only the 13-15, 16-17 and 18+ bands in Play Console. Risk to watch: the hero is a 12-year-old and the art is a friendly painted style, so Google may judge the game as appealing to children anyway, which would bring the Families policy into play. If Play flags it, the answer is either to accept the Families requirements or to adjust the store presentation, not to hide it.
- **Upload signing key** created locally outside the repo (C:/Users/Akshat/tamra-signing/, with a KEEP-SAFE.txt holding the password) and stored as three GitHub secrets (UPLOAD_KEYSTORE_B64, UPLOAD_KEYSTORE_USER, UPLOAD_KEYSTORE_PASSWORD). It is a PKCS12 keystore made with Python's cryptography library, because the laptop has no Java; the release job opens it with keytool before building, so a bad key fails early. Play App Signing must be turned on so a lost upload key can be reset.
- **Still missing:** GOOGLE_SERVICES_JSON_B64 (needs the Firebase project, browser only), the hosted privacy policy URL, and the low-end phone check (owner expects it to be fine; Play's free pre-launch report tests on real devices and will tell).

## 2026-10-28 — Release prep: consent-gated Firebase analytics, control options, release bundle job, launch rules
Context: a market review found discovery and retention are the real risks and that controls and gesture recognition are the top complaint magnets for this kind of game. The owner said to go to production.
- **Analytics = Firebase (Analytics + Crashlytics) through the MIT "Godotx Firebase" plugin, release builds only.** Why: free, gives D1/D7, drop-off and crash-free rate with no server, and it is the SDK the parent plan names. The plugin and gradle template are installed by CI (`tools/ci/*.sh`) and are not in the repo, so debug builds, tests and the 55 MB debug APK are unchanged. Game code still only calls `Services.analytics`; `FirebaseAnalytics` wraps the log and does nothing when the plugin is absent.
- **Consent first.** A one-time card on the title screen asks "Share anonymous play data?"; Settings has a switch. Nothing is sent before a yes; a no switches collection off and drops the queue; ad storage, ad user data and ad personalisation are always denied; the plugin's "privacy-safe defaults" also turn collection off in the manifest until the game enables it. Why: Play Data safety, India's DPDP Act, and the brand promise. The choice is stored as "ask"/"yes"/"no" (a string, because JSON turns numbers into floats and the save loader rejects a type change). Cost: retention is measured only for players who say yes, so numbers are biased toward engaged players; treat D1/D7 as an upper bound. Changes if: consent rate is very low (then move to a no-consent, no-identifier design or ask later in the game).
- **INTERNET permission is now in the release build** (Firebase needs it). The game stays fully playable offline; the store text must say "works offline", not "no internet permission".
- **Crash context:** the current level id is attached to Crashlytics reports (with consent). Device facts (model, Android version, GPU, screen) are in the `session_start` event so low-end problems show up by phone model.
- **Controls:** Settings has Pad size (S/M/L/XL, 0.8x to 1.4x) and Left-handed (swaps the two pad clusters, keeping "left" left of "right"). Offsets scale from the screen corners with the radii, so pads never overlap and always fit (`ControlLayout`, tested). Why: virtual-button feel and fixed layouts are the most repeated platformer complaint. Not done: free dragging of pads.
- **Release bundle:** `Android Release` preset (AAB, gradle build, arm64 + armv7) and `.github/workflows/release-aab.yml` with a dry-run mode (throwaway key, placeholder Firebase config) that proves the chain without secrets. Version 0.6.0 (code 6). Nothing publishes to Play automatically.
- **Launch kill/fix rules (PROPOSED, owner to confirm before the closed test ends).** Measured on consenting players, after about 500 installs (roughly 250-350 with data): D1 at or above 30% healthy, 20-30% fix the first five minutes, below 20% fix or stop. D7 at or above 8% healthy, below 4% the game is a one-session story. Level 1 completion below 70% means the opening is too hard or unclear. `gesture_unrecognized` above 35% of draws means fix recognition before anything else. Crash-free users below 99% blocks the production release. Reference points: all-game median D1 is about 22-27% and "good" is about 35/15/5 for D1/D7/D30 (mid-2026 vendor benchmarks, directional). Changes if: the owner sets a different bar.
- **Not decided here:** game name and package ID (permanent), personal vs organization Play account, target age (the hero is 12; if children could be the audience, Google's Families policy and DPDP rules change the SDK choice).

## 2026-10-27 — Story plays on a chapter's first level every time; first launch goes straight to the story; "To be continued" ending
Owner request. Why: the story is the hook, and a new player should see it before any loading or menu. How: `StoryFlow.opening_story` plays a chapter's story whenever its first level is opened from the map or Play (skippable); other levels, retries and daily trials skip it. First-run (no progress and the opening story neither finished nor skipped) bypasses the cloud curtain and the menu: story, then level 1; the curtain shows from the next launch. The final level's Next button was missing, so the last beat could never play; Next now shows on every non-trial level and leads to `EndingScreen` after the last level. After-level beats stay once-only (my call; the owner only talked about chapter stories). Changes if: players find the repeated chapter story annoying (then: play it only until first cleared, keep it on the map's Story button).

## 2026-10-26 — Round 5 gameplay: hearts that last, flying UDAAN, earned tiredness, 15 levels of maya
Owner played 0.4.0 end to end (~30 min) and asked for these.
- **Hearts last the level** (`LifeRules`). A hit or a pit costs one; a pit returns you to the last lamp; respawns never refill; one rare heart pickup per level, placed high on a lone stone or behind a smoke wall; at zero the level restarts from the beginning after a short "Lives lost" (`level_restart` event). Pause > Restart is now a full restart too, or it would be a free heal. Why the owner saw "the life bar doesn't work": the code did drop a heart, but the spent heart was a dark shell almost invisible on the dark plate, with no feedback, and the jade prana bar right under it reads like a classic health bar (it never drops on a hit and refills easily). Hearts are now bigger, spent ones are crimson-rimmed shells, a lost heart bursts and the row shakes with a crimson edge flash. Changes if: retention data shows restarts drive players away (then: a checkpoint "second wind" once per level).
- **UDAAN** is 1.6x a jump (~368 px) plus a 1.5 s steerable glide (80 px/s sink), with flat pale wings, a turning ring and a whoosh. It now costs 30 prana with a 3.5 s cooldown so it does not replace SETU. TARANG-only walls were raised to 640 px so UDAAN cannot clear them.
- **Tiredness** (`Fatigue`, numbers in player.json): only after 6 s of non-stop running, a flurry of strikes, or 3+ jumps in 5 s; drains while walking or standing; the pant plays when he stops while tired, at most once per 20 s. Breath and pant clips normalised to -1 dB peak and raised to -9 / -3 dB.
- **Death effects**: the left-behind figure keeps the on-screen size (brutes were shrinking). JWALA kills burn: flat crimson-orange flash, a fire-coloured dissolve edge eating up from the feet over 1.2 s, flat flame tongues and square sparks, grey ash falling into a pile that fades after 3 s. No glow or bloom.
- **Levels 9 → 15** (two per chapter, ids appended so old ids and saves stay valid). New maya: phantom walls, false gates, mirage guards, veiled guards, a veiled gate; plus data-only combos (false floors over thorns, thorn hollows). Each is taught on safe ground under a prompt first; a test enforces it. Levels were laid out with a section script (kept out of the repo; the JSON is the source of truth).
Changes if: the new levels still finish too fast, or the illusions read as unfair in testing (then strengthen tells before adding more).

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
