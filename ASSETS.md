# ASSETS.md

Every asset in the game must be listed here with its source and licence. Nothing is added to the build without an entry.

| Asset | Type | Source / tool | Licence / rights | Added |
|---|---|---|---|---|
| All visuals (sky, skylines, puppets, rocks, effects, HUD icons) | Procedural code | Written for this project (`src/fx/`, `src/ui/`) | Original, owned by the project | 2026-10-25 |
| `icon.svg` | Vector icon | Hand-written SVG for this project | Original, owned by the project | 2026-10-25 |
| UI font | Font | Godot engine's built-in default font | Ships with Godot, open licence. Confirm exact font and licence before release. | 2026-10-25 |
| Godot Engine | Engine | godotengine.org, 4.7.2 | MIT. **The licence notice must appear in the app (credits screen) before release.** | 2026-10-25 |

Rules:
- Original or properly licensed only. No names, art, icons, audio or listing text copied from other games or films.
- AI-generated art: record the tool, model and prompt. Keep the original files in a source-art folder outside the build. Check the tool's terms for commercial use.
- Fonts and audio need a licence that allows commercial use in an app.

Release to-dos:
- [ ] Credits screen with the Godot MIT notice and the licences of its bundled third-party libraries.
- [ ] Replace the default font with a chosen OFL font and log it here.
