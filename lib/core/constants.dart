/// Static configuration for the app.
///
/// There are no secrets in this file. The WikiTree API is keyless and the
/// Firebase configuration files are public by design - see README.md.
abstract final class ApiConfig {
  static const String endpoint = 'https://api.wikitree.com/api.php';

  /// Sent with every request. WikiTree uses it to tell apps apart; requests
  /// without one are subject to much stricter rate limits.
  static const String appId = 'WikiTreeViewer';

  static const Duration requestTimeout = Duration(seconds: 20);

  /// WikiTree allows 200 requests per minute and 4000 per hour. The client
  /// stays well below that with a minimum gap between requests.
  static const Duration minRequestSpacing = Duration(milliseconds: 150);

  /// How long the refresh button rests after a refresh that worked.
  ///
  /// Refresh is the only thing in the app that throws away answers WikiTree has
  /// already given, so it is the only thing that could become polling: a reader
  /// watching a relative edit a profile would tap it every few seconds. Thirty
  /// seconds allows following that, and caps one device at 120 refreshes an hour.
  /// Each refresh costs at most three requests - the family cone, the relatives,
  /// and the look below - so 360 an hour against WikiTree's 4000, and never more
  /// than a few a minute against its 200. WikiTree counts those limits per user,
  /// so this is one device's budget and not one the whole app shares.
  static const Duration refreshCooldown = Duration(seconds: 30);

  /// Generations loaded around the starting person. More are fetched on demand
  /// when the user asks for them.
  static const int ancestorsDepth = 3;
  static const int descendantsDepth = 2;

  /// How many generations one tap of a load-more pill adds.
  ///
  /// There is no ceiling on how far a tree can be grown: somebody browsing a line
  /// of kings wants to reach the bottom of it, however far that is. What is
  /// bounded is the *step*, because each extra generation can double the number
  /// of people - one generation at a time would mean a new request and a wider
  /// tree for every tap, and ten at a time would answer a question nobody asked.
  /// Two keeps a tap worth making and the requests few.
  static const int growthStep = 2;

  /// How many people one request may ask about.
  ///
  /// WikiTree answers a request for too many keys with a server error rather than
  /// a partial answer: measured on this project, 40 keys came back fine and 124
  /// keys failed. Growing the tree from its edge asks about a whole row at once,
  /// so the row is sent in batches of this many.
  static const int keyBatchSize = 40;
}

abstract final class WebConfig {
  static const String siteBase = 'https://www.wikitree.com';

  /// The public profile page. The WikiTree ID is the part after /wiki/.
  static String profileUrl(String wikiTreeId) => '$siteBase/wiki/$wikiTreeId';

  /// Photo thumbnails arrive as relative paths such as
  /// `/photo.php/thumb/0/08/name.jpg/75px-name.jpg`.
  ///
  /// WikiTree's app policies allow images to be shown only in this 75-pixel
  /// thumbnail form, with a link back to WikiTree for the full image.
  static String photoUrl(String relativePath) =>
      relativePath.startsWith('http') ? relativePath : '$siteBase$relativePath';
}

abstract final class AppInfo {
  /// A brand, not a piece of prose: the same in every language.
  static const String displayName = 'WikiTree Viewer';

  /// The emblem, declared in pubspec.yaml. The launcher icons are rendered from
  /// this same artwork (see tool/make_launcher_icons.dart).
  /// The app icon - the art the launcher and the store show - used as the
  /// emblem on the first screen. A PNG rather than the source SVG because the
  /// icon carries its rounded mask; `art/wikitree-reader-logo.svg` stays the
  /// master the launcher icons are rendered from (see README.md).
  static const String appIconAsset = 'art/app_icon512.png';

  /// The first example the lookup screen offers: Queen Elizabeth II.
  ///
  /// A family people already recognise, so the tree the example opens is worth
  /// looking at rather than merely valid - and next to [secondExampleKey] it
  /// shows that the surname is part of the code.
  static const String exampleKey = 'Windsor-1';

  /// A second worked example, offered next to [exampleKey] so the suggestion on
  /// the lookup screen reads as "codes look like this" rather than "this is the
  /// only person the app knows".
  static const String secondExampleKey = 'Kennedy-96';

  /// The two examples per language, because a family the app's own readers
  /// recognise is worth more than a famous one from somewhere else: a German
  /// reader is offered Goethe, a Serbian one Karađorđević.
  ///
  /// Both are always full codes - surname and number - so the pair shows how a
  /// code is built, and both open a tree with several generations to look at.
  /// [examplesFor] falls back to English for a language that is not listed.
  ///
  /// Every code here was opened against the live API, because an example that
  /// does not open is worse than none. Two needed looking up rather than
  /// guessing: Goethe is `Goethe-22` (there is no `Goethe-1`), and Victor Hugo is
  /// `Hugo-215` - `Hugo-216` is a different family entirely. Bolívar's code
  /// carries its accent, because that is the id WikiTree uses.
  static const Map<String, List<String>> _examples = <String, List<String>>{
    'en': <String>[exampleKey, secondExampleKey],
    'de': <String>['Goethe-22', 'Van_Beethoven-1'],
    'es': <String>['Borges-69', 'Bolívar-11'],
    'fr': <String>['Hugo-215', 'Bonaparte-1'],
    'pt': <String>['Senna_da_Silva-1', 'Bragança-8'],
    'sr': <String>['Karađorđević-13', 'Tesla-1'],
  };

  /// The pair of example codes for [languageCode], e.g. `de`.
  static List<String> examplesFor(String languageCode) =>
      _examples[languageCode] ?? _examples['en']!;

  /// Where the app's own share link points: `https://<host><path>?id=<code>`.
  ///
  /// An ordinary https link is the only kind messengers and note apps turn into
  /// something tappable, so this is what gets shared instead of a custom scheme.
  /// Android hands it to the app once App Links verification has passed (see
  /// docs/app-links/README.md). Changing either value means changing the intent
  /// filter in android/app/src/main/AndroidManifest.xml, the parser in
  /// lib/data/key_parser.dart and the page in docs/open/index.html.
  static const String appLinkHost = 'under3415.github.io';
  static const String appLinkPath = '/wikitree-viewer/open/';

  /// Registered for links that open the app: `wikitreeviewer://person/<id>`.
  /// See lib/core/deep_links.dart. Changing it also means changing
  /// android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist.
  static const String deepLinkScheme = 'wikitreeviewer';

  /// Where the app can be installed, used in shared messages so somebody who
  /// does not have it yet has somewhere to go.
  static const String installUrl =
      'https://play.google.com/store/apps/details'
      '?id=io.github.under3415.wikitreeviewer';
}
