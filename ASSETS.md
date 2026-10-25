# ASSETS.md

Every asset in the game must be listed here with its source and licence. Nothing is added to the build without an entry.

| Asset | Type | Source / tool | Licence / rights | Added |
|---|---|---|---|---|
| All visuals (sky, skylines, puppets, rocks, effects, HUD icons) | Procedural code | Written for this project (`src/fx/`, `src/ui/`) | Original, owned by the project | 2026-10-25 |
| `icon.svg` | Vector icon | Hand-written SVG for this project | Original, owned by the project | 2026-10-25 |
| UI font | Font | Godot engine's built-in default font | Ships with Godot, open licence. Confirm exact font and licence before release. | 2026-10-25 |
| Godot Engine | Engine | godotengine.org, 4.7.2 | MIT. **The licence notice must appear in the app (credits screen) before release.** | 2026-10-25 |
| `audio/foley/footstep_0-4.ogg` (footstep00-04), `footstep_heavy_0-4.ogg` (footstep05-09), `jump_0-3.ogg` (cloth1-4), `land_0-3.ogg` (dropLeather, bookPlace1-3), `enemy_windup_0-2.ogg` (creak1-3), `page_turn_0-2.ogg` (bookFlip1-3) | Audio (OGG), renamed, unedited | Kenney "RPG Sounds", uploaded by Kenney to https://opengameart.org/content/50-rpg-sound-effects (`RPGsounds_Kenney.zip`; kenney.nl itself was unreachable) | CC0 1.0 (licence file in the zip). Credit "Kenney.nl" optional; add to credits. | 2026-10-25 |
| `audio/ui/ui_click_0-2.ogg` (click_001-003), `ui_back_0-1.ogg` (back_001-002) | Audio (OGG), renamed, unedited | Kenney "Interface Sounds" 1.0, uploaded by Kenney to https://opengameart.org/content/interface-sounds (`kenney_interfaceSounds.zip`) | CC0 1.0 (licence file in the zip). Credit "Kenney.nl" optional; add to credits. | 2026-10-25 |
| `audio/synth/*.wav` (magic, fire, impacts, hurt/death, enemies, pickups, checkpoint, goal, wind and fire ambience, tanpura drone) | Audio (WAV, mono 22.05 kHz; loops 16 kHz) | Generated in code by `tools/synth_audio.gd` (no samples, no AI audio tools) | Original, synthesized by tools/synth_audio.gd; owned by the project | 2026-10-25 |

Rules:
- Original or properly licensed only. No names, art, icons, audio or listing text copied from other games or films.
- AI-generated art: record the tool, model and prompt. Keep the original files in a source-art folder outside the build. Check the tool's terms for commercial use.
- Fonts and audio need a licence that allows commercial use in an app.

Release to-dos:
- [ ] Credits screen with the Godot MIT notice and the licences of its bundled third-party libraries.
- [ ] Replace the default font with a chosen OFL font and log it here.
