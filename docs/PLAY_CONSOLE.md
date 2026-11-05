# Play Console answers for Tamra (as of 2026-11-05)

Answers to give in Play Console, based on what the game really does today. If the game changes (ads, purchases, accounts), revisit the marked rows. Google's wording and screens change; where a screen differs from this sheet, answer truthfully and ask.

## The file to upload
`Gems/builds/tamra-release-0.6.0/tamra-release.aab` (built by the "Release bundle" workflow, signed with the upload key). Package `com.iiakshat.tamra`, version name 0.6.0, version code 6. The package name is read from the file on upload; it is never typed into Play Console. Each later upload needs a higher version code (7, 8, ...).

## Create app
| Field | Answer |
|---|---|
| App name | Tamra |
| Default language | English (India); add a Hindi listing later |
| App or game | Game |
| Free or paid | Free (cannot be changed to paid later; in-app items are still allowed) |
| Declarations | Tick the Developer Program Policies and US export law boxes |
| Contact email (shown publicly) | jakshat569@gmail.com, to match the privacy policy |

## App content
| Section | Answer |
|---|---|
| Privacy policy URL | https://iiakshat.github.io/tamra-privacy/ |
| App access | All functionality is available without logging in |
| Ads | No ads today. Change to Yes when rewarded video is added |
| Target audience | 13-15, 16-17, 18+ only. Do not tick anything under 13 |
| Appeals to children? | Answer honestly. The hero is a 12-year-old, so this is the one to think about, not rush |
| Content rating (IARC) | Category: Game. Fantasy violence yes (stylised, no blood or gore). No sex, profanity, drugs, gambling, user chat, location sharing or purchases |
| News app, government app, financial features, health | No to all |
| Advertising ID | The bundle contains the AD_ID permission (added by Firebase). Either answer Yes with purpose Analytics, or rebuild without the permission and answer No. Pending decision |

## Data safety
Collection is optional (the player chooses on the first-run card). Declare:
| Data type | Why | Notes |
|---|---|---|
| App activity > App interactions | Analytics | Level starts, finishes, fails, mantra use |
| App info and performance > Crash logs, Diagnostics | Analytics, app functionality | Crashlytics |
| Device or other IDs | Analytics | Firebase app instance ID |
Not shared with third parties for their own use (Firebase processes it for us). Encrypted in transit: yes. Deletion: users can request it by email (see the privacy policy). No location, contacts, photos, name or email.

## Store listing (needs making)
- Icon 512x512: `assets/icon/icon_512.png` exists.
- Feature graphic 1024x500: not made yet.
- Phone screenshots (at least 2): can be captured with the debug `--screenshot` args.
- Short description (80 characters) and full description: not written yet.
- Never name gods; say "plays fully offline", not "no internet permission".

## Testing tracks
1. Closed testing: create an email list of 15-20 testers, send the opt-in link. 12 must stay opted in for 14 continuous days, and testers must install from Play (not sideload).
2. Production access can be requested only after that.
Unconfirmed: whether the 14 days can start while account identity verification is still pending. A closed test link may only be shareable after Google approves the release.
