# Game design (working title "Project Tamra")

Short and living. Update when the design changes; log the reason in `DECISIONS.md`.

## Pitch
A shadow-puppet platformer about an asura warrior who refuses a tyrant's order and climbs out of the Ash Pits, using drawn mantras and maya illusions. Calm, fair, fully offline.

## Pillars
1. **Draw to cast.** The touchscreen is the instrument, not a fake gamepad.
2. **Trick, don't just fight.** Maya lets you fool guards and see through lies. Fire is not the only answer.
3. **Fair.** No energy timers, no forced ads, generous checkpoints, clear tutorials.
4. **Beautiful on cheap phones.** Silhouettes, light and atmosphere instead of heavy textures.

## Story (no gods or real epic characters named, ever)
- The Golden Isle is ruled by the **Smoke King**, who burns the forests of the mortal shore.
- The hero is asura-born, his best hunter. Ordered to burn a sleeping village, they refuse. Stripped and thrown into the Ash Pits, they climb using the old mantras their mother taught them and the maya in their blood.
- The goal is to end the tyranny, not to take the throne.

## Chapters (plan)
| # | Name | New mantra / idea | Status |
|---|---|---|---|
| 1 | The Ash Pits | SETU (bridge), CHHAYA (shadow-double), JWALA (fire) | Level 1 built |
| 2 | Mirror Marsh | DRISHTI (see through illusions): false and hidden platforms | Coded, no level yet |
| 3 | Forest of the Shore Folk | KAVACH (shield): protect villagers | Coded, no level yet |
| 4 | Bronze Foundries | Combining mantras under pressure | Planned |
| 5 | The Smoke King's Tower | Vertical climb, final confrontation | Planned |

## Mantras (numbers in `config/mantras.json`)
| Mantra | Sign | Effect |
|---|---|---|
| SETU (bridge) | Straight line, toward where you want it | Bridge of light at your feet. Also saves a fall. |
| CHHAYA (shadow) | V | Shadow-double runs ahead. Guards chase it and are dazed on contact. |
| JWALA (flame) | Lightning bolt | Fire bolt that burns guards and smoke-thorns. |
| KAVACH (armour) | Circle | Short shield. Guards bounce off dazed. |
| DRISHTI (sight) | Triangle | Reveals illusions: false platforms fade, hidden ones become solid. |

## Controls
Left and right pads at bottom-left, jump at bottom-right (large hit areas, slide between left and right). Draw anywhere else to cast; time slows to 35% while drawing. Keyboard and mouse also work for testing.

## Analytics events (feed the kill/fix rules in the parent strategy)
`session_start`, `story_view`, `level_start`, `level_fail` (cause, x), `level_complete` (time, deaths, embers), `mantra_cast`, `gesture_unrecognized` (score), `enemy_burned`.
Watch closely: unrecognized-gesture rate (is drawing frustrating?), deaths by x (difficulty spikes), D1/D7 retention once Firebase is in.

## Known gaps
- No audio yet (music, effects, Sarvam voice for the story).
- One level only. Needs about 5-6 levels for Chapter 1 before a closed test is meaningful.
- No settings screen (quality, vibration, left-handed layout).
- Firebase and AdMob are interfaces only.
