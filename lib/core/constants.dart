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

  /// Generations loaded around the starting person. More are fetched on demand
  /// when the user asks for them.
  static const int ancestorsDepth = 3;
  static const int descendantsDepth = 2;

  /// How far the app will grow a tree on request.
  ///
  /// Every extra generation can double the number of people, so this is a
  /// deliberate ceiling rather than the API's limit: past six generations up a
  /// tree is also too wide to read on a phone even when zoomed out.
  static const int maxAncestorDepth = 6;
  static const int maxDescendantDepth = 4;
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
  static const String logoAsset = 'art/wikitree-reader-logo.svg';

  static const String exampleKey = 'Einstein-1';

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
