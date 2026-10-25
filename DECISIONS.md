# DECISIONS.md

Newest first. One entry per notable decision: what, why, and what would change it.

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
