# WikiTree Viewer
TLDR:
./tool/build.ps1 N


[![CI](https://github.com/under3415/wikitree-viewer/actions/workflows/ci.yml/badge.svg)](https://github.com/under3415/wikitree-viewer/actions/workflows/ci.yml)

An unofficial, read-only Flutter viewer for family trees on
[WikiTree](https://www.wikitree.com). No accounts, no editing, no ads, no
tracking - type or paste a WikiTree ID (or a profile link) and explore the
family around that person by tapping and scrolling.

**Not affiliated with WikiTree.com.** All family data comes from the public
WikiTree API and remains subject to WikiTree's terms.

## Status

Shipped on the Play Store and in daily use. The data layer, lookup flow, layout
engine, the interactive tree (pan, zoom, tap to re-centre, long-press for
details), photos, on-demand generations, deep links and the six languages are all
in place and tested.

| Area | State |
| --- | --- |
| WikiTree API client (appId, throttling, error mapping, session cache) | done |
| WikiTree ID / URL parsing | done |
| Person + family graph model | done |
| Lookup screen + person/family view | done |
| Tree layout engine (generations, ordering, edges) | done |
| Tree view widget, pan/zoom, re-centre on tap | done |
| Photos in the tree, on-demand generations | done |
| Details sheet (long-press) | done |
| First-run hints on the tree, once per install | done |
| Remembers the families opened recently, and suggests them while typing | done |
| Deep links (Android App Link + `wikitreeviewer://`) | done |
| Release hardening (signing, icons, store listings) | done |
| VoiceOver/TalkBack walk-through, iOS release | next |

## Using the tree

- **Tap** a person: they become the middle of the tree and their family is
  loaded around them. The **arrow** next to the X steps back to the person you
  were looking at before, so a walk through a family can be undone a step at a
  time - and Android's system back gesture does the same. iOS has no on-screen
  back button of its own, which is why the arrow is there: without it the only way
  out of a walk on an iPhone would be the X, which throws the trail away. The
  **X**, top-left, closes the tree from wherever the walk is and returns to the
  first screen.
- **Long-press** a person: their details. Long-press again on someone in that
  view to keep walking the family.
- **Drag** to pan and **pinch** to zoom. There are no zoom buttons: a pinch is
  the one gesture everybody already knows, and the view snaps back on its own if
  a drag ever leaves the tree out of sight.
- **Share** (bottom left) sends this family to somebody else - see below.
- **Refresh** (bottom left, beside share) re-reads this tree from WikiTree. The
  session cache is what makes tapping around free, and it also means an edit
  somebody else makes to a profile while it is open stays invisible until the app
  is restarted; this is the way out of that. It rests for 30 seconds after each
  use - see *How the app talks to WikiTree*.
- Each box shows the person's WikiTree 75-pixel thumbnail, or their initials
  when there is no photo.

### The first time: hints, and the families opened before

The first tree a user opens carries a dialog (`TreeTipsDialog`, in
`lib/ui/widgets/tree_tips.dart`) with one line and one icon per gesture: drag to
move around, pinch or spread to zoom, tap a person to re-centre, press and hold
for their details. It is shown once - dismissing it writes `treeTipsSeen` to
shared preferences - and never again, because a hint that keeps reappearing is a
nuisance rather than help.

The lookup box also comes back filled with the last family code that actually
opened (`lastFamilyCode`), so the second visit is one tap. Only a successful
lookup is remembered, and the canonical WikiTree ID is stored rather than what
was typed, so a pasted profile link leaves `Einstein-1` behind, and a typo never
greets the user next time.

Typing then offers the families opened before: `recentFamilyCodes` keeps the last
ten codes, newest first, and any of them that match what is in the box appear
underneath it (`_RecentSuggestions` in `lib/ui/screens/lookup_screen.dart`).
Tapping one opens it, because a suggestion that only filled the box would cost
the second tap it exists to save. Opening the same family again moves its code to
the front instead of adding a duplicate, and an empty box shows nothing - a list
of every code would be a menu, not a suggestion.

Those live behind `AppPreferences` (`lib/data/preferences.dart`): an interface,
`DevicePreferences` on top of `shared_preferences`, and an in-memory fake in the
widget tests. Along with `treeTipsSeen` they are the only things written to disk -
nothing about the people in a tree - which is what the privacy policy promises.

### Typing a family code

WikiTree IDs are case sensitive in the surname: `einstein-1` is accepted, but
`EINSTEIN-1` and `EiNsTeIn-1` come back as "Invalid profile" (measured against
the API). So the code box capitalises as you type - the first letter, and the
first letter after a hyphen, apostrophe or space - and never removes a character
you typed, which means it cannot stop you entering a code. Three fallbacks keep
older typing habits working:

* the lookup tries the code as typed, then with a capitalised surname, then
  all-lowercase (which WikiTree does resolve);
* a pasted link is left exactly as it is, capitals and all;
* a not-found message says to check the code or paste the profile link, rather
  than blaming capitals.

Surnames are not limited to A-Z either. `Marić-75` (Mileva Marić) is a real ID,
so any Unicode letter is accepted, both when typing and when the app follows a
tap inside the tree. There is a clear button in the box for starting again.

### The two characters no keyboard gives you

A WikiTree ID needs a hyphen (`Windsor-1`) and occasionally an underscore
(`Sachsen-Coburg_und_Gotha-4`). Both sit on a second layer of every phone
keyboard - the 123 layer on iOS, the symbols page on Gboard - and no Flutter app
can add keys to the system keyboard. So the app ships its own: while the box has
the keyboard, two keys sit under it, `-` and `_`, and each one inserts at the
cursor in a single tap (`_InsertKeys` in `lib/ui/screens/lookup_screen.dart`).
They disappear with the keyboard, because outside typing there is nothing for
them to do.

### Sharing a family, and opening links

The share button offers two things, because they suit different people:

* **Share with an app** - the system share sheet: messages, email, WhatsApp,
  Facebook, anything installed.
* **Copy the link** - the same text on the clipboard.

The shared text carries the person's name and dates, one https link that opens
the tree in the app, and the store page for whoever does not have the app yet:

```
View Albert Einstein's (1879–1955) family tree in WikiTree Viewer: https://under3415.github.io/wikitree-viewer/open/?id=Einstein-1

Don't have WikiTree Viewer? Get it here: https://play.google.com/store/apps/…
```

The link is deliberately `https://` rather than `wikitreeviewer://`: Viber,
OneNote, mail clients and forums only turn http(s) URLs into something tappable,
so a custom scheme arrives as dead text. The scheme is still registered and still
understood - `DeepLink.keyFrom` takes `wikitreeviewer://person/Einstein-1` and a
plain `https://www.wikitree.com/wiki/Einstein-1` as well - it is simply no longer
what gets shared.

An https link reaches the app through an **Android App Link**: the intent filter
in `AndroidManifest.xml` (`android:autoVerify="true"`, host `under3415.github.io`,
`pathPrefix="/wikitree-viewer/open"`) together with
`https://under3415.github.io/.well-known/assetlinks.json`, which lists the package
name `io.github.under3415.wikitreeviewer` and the signing certificates' SHA-256
fingerprints. Without the app installed, the same link shows the landing page in
`docs/open/index.html`, which carries the family code and an "Open in the app"
button, so a shared link is never a dead end.

Both of those live outside the app: the landing page is published by GitHub Pages
from `docs/` in this repository, and `assetlinks.json` has to sit at the *host*
root, which for a project site means a small `under3415.github.io` repository.
The exact steps - including where to copy Play App Signing's fingerprint from,
since Play re-signs the app with a key of its own - are in
`docs/app-links/README.md`; the file there already holds the upload key's
fingerprint.

iOS needs the matching piece when that build is made:
`apple-app-site-association` at the same host plus the
`com.apple.developer.associated-domains` entitlement
(`applinks:under3415.github.io`).

Flutter has a deep-link handler of its own, and it is **switched off** on purpose:
`flutter_deeplinking_enabled` is `false` in `AndroidManifest.xml` and
`FlutterDeepLinkingEnabled` is false in `Info.plist`, because `app_links` reads
the links. Left on - which is the Android default - a link is handed to the
framework a second time as a *named route* (`pushNamed('/wikitree-viewer/open/…')`),
nothing matches that name, and release builds died inside
`WidgetsApp._onUnknownRoute` with `Null check operator used on a null value`
(Crashlytics, 1.0.5, three devices). Flutter's deep-linking page says to opt out
for exactly this case: a plugin handling links itself. `MaterialApp.onUnknownRoute`
in `lib/app.dart` is the belt to that braces - it answers with the first screen,
so a stray named push can never reach the framework's null check again.

### Going further back or forward

The tree does **not** load every generation up front. It starts three
generations above and two below, and two small pills appear only while there is
something to load:

| Pill | Where | Meaning |
| --- | --- | --- |
| `▲ 16 more` | top right, in the app bar | WikiTree has 16 people recorded above the top row; tap to load two more generations |
| `▼ 5 more` | bottom right | 5 people are recorded below the bottom row; tap to load two more generations |
| `▼ More` | bottom right | somebody is below, but no exact count came back (a failed look, or a bottom row too wide to ask about in one request) |

Both pills disappear when there is nobody left, so their absence is the answer
that the tree has reached the end of the recorded family. Neither number is a
guess:

- above, WikiTree always sends `Father`/`Mother` ids, so the count is exact;
- below, a person's own record has no child list, so the app asks WikiTree
  directly (`getRelatives` with `getChildren=1` and `fields=Id,Children`). That
  answer is ids only, measured at a few hundred bytes per person on the bottom
  row - far cheaper than the generation it describes.

The bottom row means the bottom row of *this* person's descendants. Brothers,
sisters and in-laws share the middle row with the focus, and their children are
not part of this tree: counting them put a "2 more" pill under Nikola Tesla, who
has no descendants, and tapping it could only ever add nothing.

WikiTree keeps the children of a private profile out of that answer altogether, so
for a living person the app asks a different question instead: `getPeople` for
one generation below that row, which does include them as limited records (a
living parent with three children measured 2.2 KB). Either way the pill only
appears when somebody is really there - a button that loads nothing is worse
than no button.

Growth has **no ceiling**. Every tap adds two generations (`ApiConfig.growthStep`),
and the pill stays as long as asking brings somebody new, so a line of kings can
be followed to its end however far down that is. Two at a time rather than
everything is a courtesy to the phone and to WikiTree: each generation can double
the number of people (Habsburg-32 is 87 boxes four generations down and 293 six
generations down, on a canvas 24 000 px wide), and one request per tap is what
makes the growth feel immediate.

The probe that feeds the number is skipped when the bottom row is wider than
`_probeLimit` people: that would be one key per person in a single request for a
number nobody needs, so the pill says `More` instead - and it still works.



## Requirements

- Flutter 3.47+ / Dart 3.13+
- Android SDK for Android builds; a Mac for iOS builds
- Firebase project `wikitree-viewer` (crash reporting only)

## Run

```powershell
flutter pub get
flutter run
```

Quality gate:

```powershell
flutter analyze
flutter test
```

## Release builds

Store builds are obfuscated, with the Dart symbols split out so a crash can still be
read. `tool/build.ps1` does the whole release for a version you name:

```powershell
./tool/build.ps1 -Version 3                      # version 1.0.3, versionCode 3
./tool/build.ps1 -Version 3 -DryRun              # show the plan, change nothing
```

`-Version` is one number: it becomes the last part of the version and the versionCode
at the same time, so `3` on a 1.0.x project means Flutter's `--build-name=1.0.3
--build-number=3`. The major and minor parts come from `pubspec.yaml`, and a number
that is not above the current versionCode is refused, because Play would reject the
upload.

It checks that the upload key is configured, runs `flutter pub upgrade
--major-versions`, builds the release App Bundle, keeps the symbol map of that exact
build, records the version in `pubspec.yaml`, commits everything as `Release
<version>` and pushes it to origin, and only then uploads the symbols to
Crashlytics. Nothing else is produced: Play takes the `.aab`, and there is no APK to
keep in sync.

Three things worth knowing about that order:

* the commit stages the whole working tree (`git add --all`), so any other work in
  progress is recorded with the release - start from a clean tree when that matters;
* it runs after the build, so a failed build leaves the repository untouched and
  what is committed is exactly the tree the bundle was built from;
* the Crashlytics upload runs after the commit and never fails the release. It tries
  three times, ten and then twenty seconds apart, because what goes wrong there is a
  request dying mid-upload, not bad symbols - and repeating it is harmless, since
  symbols are matched by the library's build id. If all three attempts fail the
  release stands, and the script prints the command to repeat together with
  `build/symbols/<version>/crashlytics-upload.log`, which keeps firebase's own
  output: on its own it reports nothing but `java command failed` and the arguments
  it used, and the reason is in the lines above that one.
  `-NoPush` commits locally without pushing (no network, no credentials), and
  `-DryRun` prints every command without running any of it.

The Crashlytics app id comes from `firebase.json`, so it cannot drift from the
configuration the app is compiled with; `-AppId` overrides it for a different Firebase
app. The same thing by hand:

```powershell
flutter build appbundle --release --build-name=1.0.3 --build-number=3 --obfuscate --split-debug-info=build/symbols/1.0.3+3
firebase crashlytics:symbols:upload --app=1:810951891372:android:c0e8fd3f0704b47cee8209 build/symbols/1.0.3+3
```

`build/symbols/<version>/` then holds `app.android-arm.symbols`, `-arm64.symbols` and
`-x64.symbols` (about 3 MB each). They are the only way back from an obfuscated stack
trace, they are not in version control, and `flutter clean` deletes them - copy them
somewhere durable for every version you ship.

Why the script compiles into a throwaway folder first: Flutter only writes a symbol
map when it actually compiles Dart, and its build cache skips that when nothing
changed, which left the version folder empty on a rebuild. The `--split-debug-info`
path is part of the build fingerprint, so a fresh path per run forces a fresh compile,
and the maps are moved into `build/symbols/<version>/` afterwards.

Symbols and Crashlytics:
* The Java/Kotlin mapping file is uploaded by the Crashlytics Gradle plugin during the
  build, so those frames arrive readable with no extra step.
* The Dart maps *are* uploadable: `firebase crashlytics:symbols:upload` runs Breakpad's
  `dump_syms` over them, and the `.symbols` files Flutter writes for Android are
  unstripped ELF libraries, which is exactly what it wants. The upload names them after
  the app id, so the id has to be this project's
  (`1:810951891372:android:c0e8fd3f0704b47cee8209`); an id from another Firebase project
  uploads symbols that will never be matched to a crash. Symbols are matched by the
  library's build id, so re-running the upload for the same build is harmless.
* For a trace that was already pasted out of the console, `flutter symbolize` works on
  the same files:
  `flutter symbolize -i stack.txt -d build/symbols/1.0.3+3/app.android-arm64.symbols`
  (pick the ABI of the device: `arm64` for almost every phone).

Toolchain: AGP 9.5.1, Gradle 9.9.1 and Kotlin 2.4.21 (`android/settings.gradle.kts`,
`android/gradle/wrapper/gradle-wrapper.properties`). Flutter only validates the
minimums it knows (Gradle 9.5.0 / AGP 9.4 alongside it), so newer stable releases are
fine; if a future Flutter SDK starts refusing them, `-IgnoreToolchainCheck` passes
`--android-skip-build-dependency-validation` and lets the build run.

The Google plugins come from `android/settings.gradle.kts` too:
`com.google.gms.google-services` 4.6.0 and `com.google.firebase.crashlytics`
3.0.8. The Firebase Android SDK is the **BOM** version pinned once in
`android/build.gradle.kts` (`FlutterFire["FirebaseSDKVersion"]` = 35.2.0, which is
Crashlytics 21.1.0). No BOM is declared in `app/build.gradle.kts`: each FlutterFire
plugin already applies `platform("com.google.firebase:firebase-bom")` to itself and
reads that property, so the root build is the one place to move the whole
Core/Crashlytics/Sessions/Installations set. Bump it together with `firebase_core`
/ `firebase_crashlytics`, and keep the Crashlytics Gradle plugin compatible with the
Crashlytics SDK the BOM brings.

The Android SDK levels are the other half of the toolchain, and they are visible in
one place: `android/gradle.properties`.
`android/app/build.gradle.kts` reads `flutter.compileSdk`, `flutter.compileSdkMinor`,
`flutter.sdkExtension`, `flutter.minSdk`, `flutter.targetSdk`, `flutter.ndkVersion`
and `flutter.buildToolsVersion` from it, and lets `android/local.properties`
override any of them on one machine - that file is gitignored and already holds
`flutter.sdk`/`sdk.dir`, so a local toolchain can be pinned without touching the
repository. The defaults stay in the repository rather than in `local.properties`,
so a fresh clone and CI build the same app. Current values: compileSdk 37 with
minor 2 and extension 0 (platform `android-37.2`), minSdk 28, targetSdk 37, NDK
30.0.16248370, build-tools 37.0.0. Note that minSdk 28 is Android 9: devices on
Android 7 or 8 (API 24-27) can no longer install the app.

Release builds are signed with the upload key in `~/keys/wikitree-viewer-upload.jks`
(alias `upload`), read from `android/key.properties`. Both the keystore and that
properties file are gitignored: neither can be committed by accident, and a fresh
clone without them still builds (release falls back to the debug key). Keep the
`.jks` and its password somewhere safe outside this folder.

Certificate of the upload key, the same one to register with Firebase:

```
SHA-1   F2:5A:B8:97:5E:C8:59:16:62:5D:A5:E0:77:D5:14:69:B3:48:86:6B
SHA-256 D0:D6:D7:2C:EF:81:EC:85:F7:F9:18:53:13:4E:29:99:05:09:1D:3E:36:86:E6:7B:6A:AB:62:86:A9:A9:70:83
```

Flutter also prints "The generated ELF library contains unobfuscated DWARF debugging
information" on these builds. That is native debug information, kept so native frames
can be symbolised; the Dart identifiers are gone - checked by searching the shipped
`libapp.so` for class and method names from `lib/`, none survive.

## The repository

CI (`.github/workflows/ci.yml`) runs the formatting check, `flutter analyze` and
`flutter test` on every push to `main` and on every pull request, on a pinned
Flutter version. Everything it needs is committed: the tests use fixtures and
fakes, so there is no network and no Firebase involved.

Committed on purpose, although they look like secrets:

- `android/app/google-services.json` and `lib/firebase_options.dart` carry the
  Firebase **identifiers** - project id, app id, API key. Google's own guidance is
  that these are not secrets: every installed copy of the app ships them, and what
  protects the project is the API key restriction (this package name plus the
  signing certificate, see *Firebase / crash reporting*). Committing them means a
  fresh clone builds and reports crashes with no setup step.
- `test/fixtures/*.json` are real responses, copied from public profiles - the
  shapes the parser has to survive.

Never committed (the `.gitignore` covers them):

- the signing keystore (`*.jks`, `*.keystore`) and `android/key.properties`. This
  is the only genuine secret in the project: whoever holds them can publish an
  update that Android accepts as this app.
- `android/local.properties`, `.idea/`, build output, logs, `.env` files.

There is **no WikiTree API key** to leak: the API is keyless, and `appId` is just
a label that tells WikiTree who is calling.

The privacy policy lives in `docs/privacy/index.html`, in all six languages on
one page. Push it as-is and enable GitHub Pages (Settings → Pages → *Deploy from
a branch*, `main` / `/docs`), and it is served at
`https://under3415.github.io/wikitree-viewer/privacy/` - the URL both Play Console
and App Store Connect ask for. Replace the two highlighted placeholders (developer
name, contact e-mail) before submitting.

## Firebase / crash reporting

Only anonymous crash diagnostics are collected. There is no analytics, no
tracking and no user identifier. The app works normally if Firebase is missing
or fails to start, and collection is disabled in debug builds.

`android/app/google-services.json` and `lib/firebase_options.dart` were generated
by `flutterfire configure` for the Firebase Android app
`io.github.under3415.wikitreeviewer` (`1:810951891372:android:c0e8fd3f…`).

Registered on the Android app:

- SHA-1 `F0:6B:39:93:E2:EE:D8:72:DB:27:01:65:FB:90:0C:61:43:44:99:81`
  (this machine's debug keystore)
- SHA-256 of the same certificate

The Google Cloud API key used by the Android app is restricted to that package
name plus the debug SHA-1, and its service allowlist includes
`firebasecrashlytics.googleapis.com` and `firebaseinstallations.googleapis.com`
(the Crashlytics API is enabled on the project).

**Outstanding:** the upload key (`F2:5A:B8:97:…:86:6B`, see *Release builds*) is not
registered yet, so release builds installed outside Play - and Play installs once
App Signing is enrolled - will send no crash reports. Add its SHA-1 to the Firebase
Android app (Project settings → Your apps → Add fingerprint) and to the API key's
allowed applications, then repeat with Google's app-signing SHA-1 from Play Console →
*App integrity* after the first upload. Copying a fingerprint is instant; only the
API key change needs a minute under *Google Cloud console → APIs & Services →
Credentials → the Android key → Edit → Restrict usage*.

**iOS** is not registered yet. Run
`flutterfire configure --project=wikitree-viewer --platforms=ios` before the
first iOS build; until then `CrashReporter` stays disabled on iOS. The iOS key
needs an equivalent bundle-id restriction at that point.

To add another developer's machine, get its SHA-1 with:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey -storepass android -keypass android
```

then add it to both places (Firebase app and API key restriction).

## How the app talks to WikiTree

Every request carries `appId=WikiTreeViewer`; requests without one are rate
limited much more aggressively by WikiTree. The API allows 200 requests/minute
and 4000/hour; the client keeps a minimum gap between requests and caches
responses in memory for the session.

That cache is also why an edit somebody else makes while a tree is open stays
invisible - nothing asks WikiTree again. The round arrow beside the share button
is the way out: it throws the session away for that tree, cached answers **and**
the people built from them, then loads the person again at the depths on screen -
what killing the app and reopening them would do. Dropping the graph rather than
merging into it is the whole point: `Person.mergedWith` prefers the richer copy
and, on a tie, the older one, so a corrected birth date (same fields filled,
different values) would otherwise survive a refetch untouched
(`WikiTreeRepository.reload`). A refresh that fails puts the old graph back and
leaves the screen alone; one that works rests the button for 30 seconds
(`ApiConfig.refreshCooldown`), so it cannot become a polling loop - at most three
requests per tap, 360 an hour against WikiTree's 4000, and WikiTree counts those
limits per user rather than per app.

One starting person costs **two** requests:

1. `getPeople` with `ancestors`/`descendants` - the family cone.
2. `getRelatives` with `getSiblings`/`getSpouses` - siblings, spouses and
   marriage details.

`nuclear=1` is deliberately avoided: measured against the live API it inflated a
single lookup from 21 KB to 114 KB by pulling in every ancestor's siblings.

Asking for more is **incremental**, not a re-download: the tree asks for two
generations beyond the row on the screen, from that row (`WikiTreeRepository.grow`),
and merges the answer into the graph. The edge of a big tree can be wider than
WikiTree will answer about in one request - measured here, 40 keys came back fine
and 124 keys answered with a server error - so the edge goes out in batches of
`ApiConfig.keyBatchSize`. Nothing is fetched until the user asks, and a tap costs
the same whether the tree has 30 people or 1000.

What that replaced, and why: the old version re-asked for the whole cone at the
deeper depth on every tap. For Habsburg-32 that was 748 people in one answer at
ten generations down, and once the edge itself grew past the key limit the request
failed outright - which is what "WikiTree had a problem answering that" was.
Measured with the batched growth on the same family: taps reach 10 generations
down (752 boxes) and 9 up (1052 boxes) with no failure, 1-5 s per tap.

### How a row is laid out

People are placed by generation first, then each row is ordered so families stay
together - birth order to begin with, then a few passes that pull each person
towards the median position of their relatives, with couples finally moved next
to each other. Positions come next: every pass asks each box where it would like
to be, and the whole row is then laid out as **one block** centred on the median
of those wishes.

The block is what keeps the chart readable. An earlier version moved boxes one at
a time and only ever pushed them right to avoid overlapping, so a box whose
relatives sat far away jumped there and left the boxes before it behind: the
Bonaparte-1 row used to put Joséphine 14 px from the left margin, 2 700 px of
empty canvas away from Napoleon, with the couple's bar crossing all of it. The
same measurement now reads 26 px between every pair of neighbours (the standard
gap) and a canvas 3 449 px wide instead of 5 900.

The person the tree is about is not placed any differently: the focus row is laid
out like every other row, and only the card itself is marked. The ordering passes
end on the one that anchors a row to the row *above* it, because parents are what
define a sibling group - everyone keeps their birth place, a partner sits beside
their partner, and the person searched for is first in the row only when they are
genuinely the eldest there (Windsor-1 is: Elizabeth, Philip, Margaret; Bonaparte-1
is second of fourteen, because Joséphine was born six years before him).

### How the tree joins people

A card hangs from each of its parents with an elbow line. Siblings therefore
share those lines and are never joined to each other - a line between two
siblings would read as a marriage.

Two partners in the same row are joined by a straight couple bar, the horizontal
line family charts use, with the children descending from the partnership. The
bar does not claim a wedding: WikiTree sends `Spouses` only for a profile asked
for by name (that is `getRelatives`), so ancestors arrive with their children but
never their marriages. A couple is therefore also recognised by the child two
people share, exactly as a GEDCOM family is two partners plus their children. A
bar between two partners with a known marriage that ended is dashed, and a
marriage the couple marked `do_not_display` is left out entirely.

### Why there is no offline mode (yet)

The WikiTree app policies state that *"data must not be cached or preserved
beyond the user's session"*, and the API itself answers with
`Cache-Control: max-age=0, must-revalidate`. The app therefore keeps profile
data in memory only and never writes it to disk. `SessionResponseCache` is the
only wired implementation; a disk-backed one can be added behind the same
interface if WikiTree grants permission.

What that means in practice: navigating within a session costs no requests, and
a cold start costs two small requests. The refresh button on the tree screen is
the one exception - it empties `SessionResponseCache` and rebuilds the graph for
the tree on screen (see *How the app talks to WikiTree*).

### Content rules the app follows

- photos are displayed only as WikiTree's 75-pixel thumbnails, with a link back
- biographies are never requested or displayed - the app links to the profile
- marriages marked `do_not_display` are hidden
- private and living people appear as limited cards, never as errors
- a link WikiTree hides on a child but shows on the parent is kept: the son of a
  semi-private father is drawn under him rather than offered as "1 more" forever

## Languages

The app speaks English, German, Spanish, Portuguese, French and Serbian, and
follows the device language: `MaterialApp` picks the closest of the six, and
anything else falls back to English. Every word a user can see lives in
`lib/l10n/app_<code>.arb`.

- `app_en.arb` is the template. It carries the placeholders and the notes for
  translators, and a key exists only once it is in this file.
- `flutter gen-l10n` writes `lib/l10n/app_localizations*.dart`; `flutter pub get`
  and every build do it too, so those files are never edited by hand.
- The delegates `MaterialApp` needs come from `material_ui` and `cupertino_ui`
  (`lib/app.dart`), not from `AppLocalizations.localizationsDelegates`: since
  Flutter 3.47 the Material and Cupertino delegates in `flutter_localizations`
  are deprecated, and material_ui's widgets ignore them. The generator still
  emits that list, so `l10n.yaml` prepends a header to every generated file with
  the one `ignore_for_file` it needs.
- `l10n.yaml` also turns on the untranslated-messages report: anything missing
  from a translation is written to `l10n_untranslated.json` instead of quietly
  shipping English.

Three rules keep wording out of the data layer:

- `Person` and `SpouseLink` hold facts, not sentences. `PersonText`
  (`lib/ui/format/person_text.dart`) turns them into names, life spans and
  marriage lines in the reader's language - including month names, which come
  from `intl`, so a German card reads `14 Mär 1879` and a French one
  `14 mars 1879`.
- `WikiTreeFailure` carries a reason code rather than a message;
  `describeFailure` (`lib/ui/format/failure_text.dart`) supplies the two lines a
  screen shows, so the same failure reads correctly in all six languages.
- `shareMessage` is handed the localisations it needs, so a shared message
  arrives in the language of the person sending it.

Counts are real plurals - `{count, plural, =1{1 more} other{{count} more}}` - so
German gets `1 weitere Person` and `3 weitere Personen` rather than one wording
forced onto both. Serbian uses all three of its shapes: `još 1 osoba`,
`još 3 osobe`, `još 5 osoba`.

Serbian is written in Latin here, the same letters its family codes use. `intl`
answers plain `sr` in Cyrillic - and `sr_RS` too, since it drops the region - so
month names always come from its `sr_Latn` data (`_intlLocale` in
`lib/util/dates.dart`) and one screen never mixes the two scripts.

Both Serbian tags are declared to the platforms, `sr` **and** `sr-Latn`, in
`locales_config.xml` and `CFBundleLocalizations`. The tag decides which phones
reach the app; the ARB decides the script. A phone set to Serbian in Cyrillic -
the default in Serbia - reports `sr`, and declaring only `sr-Latn` is what would
send that reader to English. It gets the Latin wording, which is the honest answer
while there is one translation: nothing in the app changes with the phone's
script setting. Adding a Cyrillic translation later means turning `app_sr.arb`
into the Cyrillic text, adding `app_sr_Latn.arb` for these Latin strings, and
pointing the `sr` branch of `_intlLocale` at `sr`; the platform files already
list both tags, and the tests already cover `sr`, `sr-Cyrl`, `sr-Latn` and
`sr-RS`.

The two example codes on the first screen follow the language as well
(`AppInfo.examplesFor`, `lib/core/constants.dart`): Goethe and van Beethoven in
German, Borges and Bolívar in Spanish, Hugo and Napoléon in French, Senna and
Pedro I in Portuguese, Karađorđević and Tesla in Serbian, and the Windsors and the
Kennedys in English. Every one of them was opened against the live API before it
was written down: Goethe is `Goethe-22` because there is no `Goethe-1`, and Victor
Hugo is `Hugo-215` because `Hugo-216` is a different family.

To add a language, copy `app_en.arb` to `app_<code>.arb`, translate the values, and
run `flutter gen-l10n`; it appears in `supportedLocales`. Three more places then
need the code, or the language stays invisible outside the app itself:

- `android/app/src/main/res/xml/locales_config.xml` - what tells Android (and the
  Play Store, which reads the bundle) that the app speaks it. Dart strings travel
  inside the Flutter assets, not in `res/values-<code>/`, so without this file the
  bundle looks English-only however many languages ship. It also gives Android 13+
  *Settings → Apps → WikiTree Viewer → Language*.
- `ios/Runner/Info.plist` -> `CFBundleLocalizations` - the same declaration for
  iOS, and what the App Store reads.
- The **store listing**, which is separate from the bundle and never travels with
  it: Play Console → *Store listing → Manage translations → Select languages*.
  Uploading a bundle does not add a listing language, and a Serbian listing only
  appears once Serbian is selected there. The text to paste is in
  `store/listings.md`.

Serbian is the worked example of all four: `app_sr.arb`, both tags (`sr` and
`sr-Latn`) in the two platform files, and a `## Serbian (sr)` block in
`store/listings.md`.

## The emblem and the app icon

`art/wikitree-reader-logo.svg` is the WikiTree emblem with reading glasses added,
and it feeds the launcher icons on Android, iOS and the web. The first screen
shows the finished icon instead - `art/app_icon512.png`, the same 512-pixel image
the Play Store listing uses - so the thing on the home screen and the thing that
opens are the same picture, right down to the rounded mask.

Launchers want pixels, so the icon is a two-step build:

```bash
flutter test tool/make_launcher_icons.dart   # SVG -> art/icon/*.png (1024px masters)
dart run flutter_launcher_icons              # masters -> Android, iOS and web icons
```

`tool/make_launcher_icons.dart` rasterises with the same engine the app uses, so
the icon in the launcher and the emblem on the screen cannot drift apart; re-run
both commands after editing the art. Android gets an adaptive icon: the emblem
sits at 78% of the tile on a background that matches the disc's outer colour, so
the disc looks whole inside whatever shape the launcher crops it to.

The emblem is derived from WikiTree's own logo, which remains theirs, and this
app is not affiliated with WikiTree - the same note the app itself shows.

## Project layout

```
art/             the emblem: source SVG and the generated icon masters
lib/
  core/          constants, failure types, crash reporting, deep links, sharing
  data/          API client, response cache, models, key parser, repository
  l10n/          ARB files and the generated AppLocalizations
  ui/            theme, screens, widgets
    format/      people and failures in the reader's language
    tree/        layout engine, metrics, painter, pan-and-zoom view
  util/          date helpers, WikiTree ID capitalisation
test/
  fixtures/      real API response shapes used by the tests
  helpers/       localisations for tests that check wording
tool/            the launcher-icon renderer
store/           Play Store listing copy and data-safety answers
docs/privacy/    the privacy policy page, ready for GitHub Pages
```

## Data model notes

The API is inconsistent, so the parsing code is defensive by design:

- `Spouses[].Id` is a **string** while person `Id` is a number
- `Father`/`Mother` use `0` for "unknown"
- dates use `00` for unknown month/day (`1773-00-00`)
- `status` is `0` from some actions and `""` from others, and can carry a
  non-fatal notice (for example the `getAncestors` deprecation message)
- private profiles return only `Id`, `Name` and privacy flags
- a child of a semi-private parent comes back naming their parent `-3`, a
  placeholder for somebody the API will not identify - even when the app is
  looking at that very parent. The parent asked the other way round names the
  child plainly in its `Children` list, so `FamilyGraph.recordChild` keeps that
  link (`getRelatives` with `getChildren=1`, ids only). Without it a son already
  in memory has nobody to hang from: the tree cannot draw him, and "more
  descendants" counts him on every look. Measured on `Nakarada-1`, where the son's
  own record said `Father: -3` while his father's `Children` list named him
- `getPeople` does honour `Spouses` when it is named in `fields`, but each entry
  embeds a whole profile: asking for it took one 2-generation lookup from 6.5 KB
  to 16.2 KB. The `spouses=1` flag is accepted and silently ignored. The tree
  therefore infers couples from shared children instead (see *How the tree joins
  people*), which costs nothing extra

## Licence

MIT for the code. WikiTree data is not covered by that licence - see `LICENSE`.
