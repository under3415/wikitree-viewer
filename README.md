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
details), photos, on-demand generations, deep links and the five languages are all
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
| Remembers the last family code (shared preferences) | done |
| Deep links (Android App Link + `wikitreeviewer://`) | done |
| Release hardening (signing, icons, store listings) | done |
| VoiceOver/TalkBack walk-through, iOS release | next |

## Using the tree

- **Tap** a person: they become the middle of the tree and their family is
  loaded around them. **Back** returns to the person you were looking at before,
  so a walk through a family can be undone a step at a time, and **home** (which
  appears once you have wandered) jumps straight back to where the tree started.
- **Long-press** a person: their details. Long-press again on someone in that
  view to keep walking the family.
- **Drag** to pan and **pinch** to zoom. There are no zoom buttons: a pinch is
  the one gesture everybody already knows, and the view snaps back on its own if
  a drag ever leaves the tree out of sight.
- **Share** (bottom left) sends this family to somebody else - see below.
- Each box shows the person's WikiTree 75-pixel thumbnail, or their initials
  when there is no photo.

### The first time: hints, and the last family

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

Both live behind `AppPreferences` (`lib/data/preferences.dart`): an interface,
`DevicePreferences` on top of `shared_preferences`, and an in-memory fake in the
widget tests. Those two values are the only things written to disk - nothing
about the people in a tree - which is what the privacy policy promises.

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

### Going further back or forward

The tree does **not** load every generation up front. It starts three
generations above and two below, and two small pills appear only while there is
something to load:

| Pill | Where | Meaning |
| --- | --- | --- |
| `▲ 16 more` | top right, in the app bar | WikiTree has 16 people recorded above the top row; tap to load the next generation |
| `▼ 5 more` | bottom right | 5 people are recorded below the bottom row; tap to load them |

Both pills disappear when there is nobody left, so their absence is the answer
that the tree has reached the end of the recorded family. Neither number is a
guess:

- above, WikiTree always sends `Father`/`Mother` ids, so the count is exact;
- below, a person's own record has no child list, so the app asks WikiTree
  directly (`getRelatives` with `getChildren=1` and `fields=Id,Children`). That
  answer is ids only, measured at a few hundred bytes per person on the bottom
  row - far cheaper than the generation it describes.

WikiTree keeps the children of a private profile out of that answer altogether, so
for a living person the app asks a different question instead: `getPeople` for
one generation below that row, which does include them as limited records (a
living parent with three children measured 2.2 KB). Either way the pill only
appears when somebody is really there - a button that loads nothing is worse
than no button.

Growth stops at six generations up and four down (`ApiConfig.maxAncestorDepth`,
`maxDescendantDepth`). Loading everything instead was rejected: each generation
can double the number of people (3 -> 6 generations is up to 8x the profiles),
and a tree that wide is unreadable on a phone even zoomed right out.



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
build, uploads those symbols to Crashlytics, records the version in `pubspec.yaml`,
then commits everything as `Release <version>` and pushes it to origin. Nothing else
is produced: Play takes the `.aab`, and there is no APK to keep in sync.

Two things worth knowing about that commit:

* it stages the whole working tree (`git add --all`), so any other work in progress
  is recorded with the release - start from a clean tree when that matters;
* it runs after the build and the upload, so a failed build leaves the repository
  untouched and what is committed is exactly the tree the bundle was built from.
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

The privacy policy lives in `docs/privacy/index.html`, in all five languages on
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

One starting person costs **two** requests:

1. `getPeople` with `ancestors`/`descendants` - the family cone.
2. `getRelatives` with `getSiblings`/`getSpouses` - siblings, spouses and
   marriage details.

`nuclear=1` is deliberately avoided: measured against the live API it inflated a
single lookup from 21 KB to 114 KB by pulling in every ancestor's siblings.

Asking for one more generation ("more ancestors above" / "more descendants") is
one more `getPeople` call at the deeper depth; the `getRelatives` call it repeats
is served from the session cache. Nothing is fetched until the user asks.

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
a cold start costs two small requests.

### Content rules the app follows

- photos are displayed only as WikiTree's 75-pixel thumbnails, with a link back
- biographies are never requested or displayed - the app links to the profile
- marriages marked `do_not_display` are hidden
- private and living people appear as limited cards, never as errors

## Languages

The app speaks English, German, Spanish, Portuguese and French, and follows the
device language: `MaterialApp` picks the closest of the five, and anything else
falls back to English. Every word a user can see lives in `lib/l10n/app_<code>.arb`.

- `app_en.arb` is the template. It carries the placeholders and the notes for
  translators, and a key exists only once it is in this file.
- `flutter gen-l10n` writes `lib/l10n/app_localizations*.dart`; `flutter pub get`
  and every build do it too, so those files are never edited by hand.
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
  screen shows, so the same failure reads correctly in all five languages.
- `shareMessage` is handed the localisations it needs, so a shared message
  arrives in the language of the person sending it.

Counts are real plurals - `{count, plural, =1{1 more} other{{count} more}}` - so
German gets `1 weitere Person` and `3 weitere Personen` rather than one wording
forced onto both.

To add a language, copy `app_en.arb` to `app_<code>.arb`, translate the values,
run `flutter gen-l10n`, and it appears in `supportedLocales`.

## The emblem and the app icon

`art/wikitree-reader-logo.svg` is the WikiTree emblem with reading glasses added.
One file feeds both places:

- the first screen shows it as vector art (`flutter_svg`), so it stays sharp at
  any text size;
- the launcher icon on Android, iOS and the web is rendered from it.

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
- `getPeople` does honour `Spouses` when it is named in `fields`, but each entry
  embeds a whole profile: asking for it took one 2-generation lookup from 6.5 KB
  to 16.2 KB. The `spouses=1` flag is accepted and silently ignored. The tree
  therefore infers couples from shared children instead (see *How the tree joins
  people*), which costs nothing extra

## Licence

MIT for the code. WikiTree data is not covered by that licence - see `LICENSE`.
