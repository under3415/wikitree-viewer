# Android App Links for WikiTree Viewer

The app shares an ordinary `https://` link, because messengers and note apps
only turn http(s) URLs into something tappable:

```
https://under3415.github.io/wikitree-viewer/open/?id=Einstein-1
```

For Android to open that link in the app instead of a browser, three things have
to agree:

| Where | What |
| --- | --- |
| `android/app/src/main/AndroidManifest.xml` | the `autoVerify` intent filter for `https`, host `under3415.github.io`, `pathPrefix="/wikitree-viewer/open"` |
| `lib/core/deep_links.dart` | `DeepLink.webHost` / `DeepLink.webPath`, used to build and to parse the link |
| `https://under3415.github.io/.well-known/assetlinks.json` | this file, published by GitHub Pages |

## Publishing the files (one-time setup)

Two repositories are involved, because a project site (`/wikitree-viewer/`) can
never serve a file at the *host* root, and Android only reads
`https://<host>/.well-known/assetlinks.json`. The file is per host, not per path:
what is published at `under3415.github.io` therefore also verifies the links
under `/wikitree-viewer/open/`.

1. **`under3415/wikitree-viewer` (this repository) - the landing page.**
   Settings → Pages → Source: *Deploy from a branch*, branch `main`, folder
   `/docs`. That publishes:
   * `https://under3415.github.io/wikitree-viewer/open/` - the page people see
     when the app is not installed (`docs/open/index.html`).

2. **`under3415/under3415.github.io` (new, public) - the verification file.**
   The repository name has to be exactly `under3415.github.io`, because that is
   what makes GitHub serve it from the host root. It needs two files:

   ```
   .nojekyll                      (empty)
   .well-known/assetlinks.json    (the file in this folder)
   ```

   The `.nojekyll` is not optional: GitHub Pages runs Jekyll, and Jekyll skips
   every file and directory whose name starts with a dot, so without it
   `/.well-known/assetlinks.json` returns 404. Then Settings → Pages → *Deploy
   from a branch*, branch `main`, folder `/ (root)`.

   Nothing else is needed in that repository; it can hold only those two files.

3. **Fix the fingerprints.** `assetlinks.json` must list every certificate an
   installed copy of the app is signed with:

   * **Play App Signing key** - Play Console → *Test and release* → *App
     integrity* → *App signing key certificate* → SHA-256. Replace the
     `REPLACE_WITH_THE_SHA-256_FROM_PLAY_CONSOLE_APP_SIGNING` line with it. This
     is the one that matters for everybody who installs from the Play Store,
     because Google re-signs the app with that key.
   * **Upload key** - already filled in, and only needed for a build installed
     by hand (sideloaded): `keytool -list -v -keystore %USERPROFILE%\keys\wikitree-viewer-upload.jks -alias upload`.

   A fingerprint that does not match, or a JSON file that does not parse, makes
   verification fail silently - the links keep working, they just open in the
   browser, and Android may ask which app should handle them.

4. **Check it.** Open
   <https://under3415.github.io/.well-known/assetlinks.json> in a browser: it
   must show the JSON, not an error and not a page starting with `---`
   (front-matter would mean the file went through Jekyll). Then, with the app
   installed from a build that contains the intent filter:

   ```powershell
   adb shell pm get-app-links io.github.under3415.wikitreeviewer
   ```

   `under3415.github.io` should show `verified`. Reinstalling the app forces the
   check; Google's
   <https://developers.google.com/digital-asset-links/tools/generator> also
   reports what it finds at the URL.

### The one-repository alternative

If a domain is available, point the Pages site at it (Settings → Pages → Custom
domain, plus a `CNAME` file in `docs/`). The host root then *is* this
repository's `docs/` folder, so the file moves to `docs/.well-known/assetlinks.json`
with a `docs/.nojekyll` beside it - no second repository. It also means changing
`AppInfo.appLinkHost` / `AppInfo.appLinkPath`, the intent filter in
`AndroidManifest.xml` and the numbers in `docs/open/index.html`.

## What happens when somebody taps a shared link

* **App installed, link verified** - Android opens the tree directly. This works
  from Viber, OneNote, e-mail, anywhere: the OS intercepts the https link before
  any browser is involved.
* **App installed, not verified (or the tap happens inside an in-app WebView)** -
  the browser shows `docs/open/index.html`, which has an "Open in the app" button
  that uses an `intent://` URL, plus the family code to copy.
* **App not installed** - the same page explains what it is and links to the Play
  Store.

The `wikitreeviewer://person/<id>` scheme still works and is still registered, but
nothing shares it any more: most apps do not linkify custom schemes, so it was
dead text in Viber and OneNote.
