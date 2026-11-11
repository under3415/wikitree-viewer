# WikiTree Viewer

[![CI](https://github.com/under3415/wikitree-viewer/actions/workflows/ci.yml/badge.svg)](https://github.com/under3415/wikitree-viewer/actions/workflows/ci.yml)

An unofficial, read-only Flutter viewer for family trees on
[WikiTree](https://www.wikitree.com). No accounts, no editing, no ads, no
tracking - type or paste a WikiTree ID (or a profile link) and explore the
family around that person by tapping and scrolling.

**Not affiliated with WikiTree.com.** All family data comes from the public
WikiTree API and remains subject to WikiTree's terms.

## Status

Early development. The data layer, lookup flow, layout engine and the interactive
tree (pan, zoom, tap to re-centre) are in place and tested; accessibility
settings and the details sheet are next.

| Area | State |
| --- | --- |
| WikiTree API client (appId, throttling, error mapping, session cache) | done |
| WikiTree ID / URL parsing | done |
| Person + family graph model | done |
| Lookup screen + person/family view | done |
| Tree layout engine (generations, ordering, edges) | done |
| Tree view widget, pan/zoom, re-centre on tap | done |
| Photos in the tree, on-demand generations | done |
| Accessibility settings, onboarding, details sheet | next |
| Release hardening (signing, icons, store listings) | planned |

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

The shared text carries the person's name and dates, the WikiTree profile link
(so the information stays attributed and is readable without the app), an app
link that opens the tree directly, and a link to the store page for whoever does
not have the app yet:

```
Albert Einstein (1879–1955) on WikiTree
https://www.wikitree.com/wiki/Einstein-1

Open in WikiTree Viewer: wikitreeviewer://person/Einstein-1
Don't have WikiTree Viewer yet? https://play.google.com/store/apps/…
```

The `wikitreeviewer://` link works on **both Android and iOS** today: the scheme
is registered in `AndroidManifest.xml` and in `Runner/Info.plist`, and
`app_links` hands it to the app, which opens the tree. It also accepts a profile
link (`https://www.wikitree.com/wiki/Einstein-1`) if the system offers one.

What is *not* set up yet is a plain `https://` link on a domain of our own (an
Android **App Link** / iOS **Universal Link**), which is what makes a link
clickable inside other apps and browsers and opens the app instead of a website.
That needs a domain and two tiny files served from it:

* `https://<domain>/.well-known/assetlinks.json` listing the package name
  `io.github.under3415.wikitreeviewer` and the SHA-256 signing certificate
  (the same one registered with Firebase). Then add an `autoVerify` intent
  filter for `https` + that host + `pathPrefix="/person"` - the manifest has a
  comment where it goes.
* `https://<domain>/.well-known/apple-app-site-association` with the Apple Team
  ID and bundle ID, plus the `com.apple.developer.associated-domains`
  entitlement (`applinks:<domain>`) on the iOS target.

GitHub Pages can host both files if the project is public, which avoids paying
for anything. Until that exists, the scheme link is the working path and the
WikiTree link is the fallback every reader can open.

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

**Still to do before a release build:** create the upload keystore, then add its
SHA-1 both to the Firebase Android app and to the API key's allowed applications
(`gcloud services api-keys update`). If Play App Signing is used, add Google's
app-signing SHA-1 as well. Until then, release builds signed with a different key
will simply have no crash reporting - the app itself is unaffected.

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
store/           Play Store listing copy in the five languages
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
