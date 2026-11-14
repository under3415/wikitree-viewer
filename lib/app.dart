import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import '../data/preferences.dart';
import '../data/wikitree_repository.dart';
import 'l10n/app_localizations.dart';
import 'ui/screens/lookup_screen.dart';
import 'ui/theme/app_theme.dart';

class WikiTreeViewerApp extends StatelessWidget {
  const WikiTreeViewerApp({
    super.key,
    required this.repository,
    required this.preferences,
    this.links,
  });

  final WikiTreeRepository repository;

  /// What the app remembers between runs: the last family code, and whether the
  /// tree hints have been seen.
  final AppPreferences preferences;

  /// WikiTree IDs coming from links that opened the app.
  final Stream<String>? links;

  /// What `MaterialApp` needs in order to translate its own widgets.
  ///
  /// `AppLocalizations.localizationsDelegates` is deliberately not used:
  /// `flutter gen-l10n` still fills that list from `flutter_localizations`, whose
  /// Material and Cupertino delegates were deprecated in Flutter 3.47, and
  /// material_ui's widgets do not accept them - a German device came back with
  /// "No MaterialLocalizations found". [GlobalWidgetsLocalizations] is not
  /// deprecated and stays where it is.
  static const List<LocalizationsDelegate<dynamic>> _delegates =
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The title is a translation like any other, so it follows the device.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // The device language wins; every other language falls back to English.
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Flutter's own deep linking is switched off on both platforms (see
      // AndroidManifest.xml and Info.plist), so a named push should never arrive.
      // This is the net for one that does anyway: without a handler, a release
      // build dies inside the framework's `onUnknownRoute!` - a real null check
      // there, because asserts are compiled out - with "Null check operator used
      // on a null value". That is the fatal exception Crashlytics collected from
      // 1.0.5, where a link pushed its own path as a route name.
      //
      // The fallback is the first screen rather than a blank one: whatever the
      // name was, the reader can paste the family code there. It is built without
      // [links], a single-subscription stream the screen underneath already
      // listens to.
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) =>
            LookupScreen(repository: repository, preferences: preferences),
      ),
      home: LookupScreen(
        repository: repository,
        preferences: preferences,
        links: links,
      ),
    );
  }
}
