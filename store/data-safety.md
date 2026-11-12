# Data safety answers

Google Play's *Data safety* form and Apple's *App Privacy* section must say the
same thing as `docs/privacy/index.html`, and all three must match what the code
actually does. This file is the copy to paste into both consoles.

## What the app sends, audited from `pubspec.yaml` and `lib/`

| Dependency | Leaves the device? |
| --- | --- |
| `firebase_core`, `firebase_crashlytics` | **Yes** - anonymous crash reports, release builds only, collection off in debug builds and when `CrashReporter.setUserEnabled(false)` is set |
| `http` | Only the WikiTree API request the user asked for (`api.wikitree.com`) |
| `flutter_svg`, images | Only WikiTree's 75 px thumbnails (`www.wikitree.com`) |
| `url_launcher` | Opens a WikiTree.com page in the user's browser - the app itself sends nothing |
| `share_plus` | Hands text to the system share sheet; the chosen app receives it, not us |
| `app_links`, `shared_preferences`, `intl` | Nothing off the device |

There is **no analytics, no advertising SDK, no attribution SDK, no social login,
no location, contacts, camera, microphone or storage permission**, and no
advertising identifier. Crash reports carry no WikiTree ID, no URL and no family
data - `CrashReporter` only ever passes a fixed tag such as `tree-focus`.

`shared_preferences` writes exactly two values to the device's own app storage:
the last family code the user opened (`lastFamilyCode`) and whether the how-to
hints on the tree have been shown (`treeTipsSeen`). Neither leaves the device, and
uninstalling the app removes both - which is what the "stays on your device"
section of the privacy page says.

## Google Play - App content -> Data safety

**Data collection and security**

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS only, no cleartext traffic) |
| Do you provide a way for users to request that their data is deleted? | **Yes** - give the contact e-mail from the privacy policy |

**Data types** - tick these two and nothing else:

| Category | Type | Collected | Shared | Processed ephemerally | Required or optional | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| App info and performance | **Crash logs** | Yes | No | No | Required | App functionality |
| Device or other IDs | **Device or other IDs** | Yes | No | No | Required | App functionality |

Everything else stays "not collected": location, personal info, financial info,
health, messages, photos and videos, audio, files and docs, calendar, contacts,
app activity (including in-app search history and installed apps), web browsing,
app info and performance (other than crash logs), and all other device IDs.

**Why "collected" but not "shared":** Firebase Crashlytics runs on our behalf as a
data processor, so Play counts it as collection by the developer. Nothing is handed
to anybody who may use it for their own purposes - Google, and only Google, and only
to store and show the crash.

**Why the IP address is not declared:** the two network destinations are WikiTree's
API and image host, contacted directly by the device to answer the user's own
request. The developer never receives, logs or stores an IP address, and WikiTree's
handling of it is theirs, which the privacy page says explicitly.

**Other App content answers that interact with this form**

- Ads: **No ads**.
- App access: every feature works without a login, so nothing to hand reviewers.
- Target audience: **13+**, not designed for children - which keeps the app out of
  the Families policy requirements.
- News, health, finance, government apps: no.

## Apple - App Store Connect -> App Privacy

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **Yes** |
| Do you use data for tracking? (ATT) | **No** - no prompt, no cross-app tracking |

**Data types collected** (both: *not linked to the user's identity*, *not used for
tracking*, purpose *App Functionality*):

- **Diagnostics -> Crash Data**
- **Identifiers -> Device ID** (the Firebase/Crashlytics installation identifier)

Everything else: not collected. Privacy policy URL: the GitHub Pages address from
`docs/privacy/`.

## Keeping them in sync

- Crash data is retained by Google for 90 days; our own systems keep nothing.
- If an in-app crash-reporting switch is added later, change "Required" to
  "Optional" in Play, answer the follow-up about users being able to turn collection
  off, and rewrite the last sentence of the crash section in the privacy page (it
  currently says to contact us).
- Any new SDK that talks to a server - analytics, ads, push, attribution - changes
  both forms and the policy. Update all three in the same commit.
