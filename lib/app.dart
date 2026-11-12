import 'package:flutter/material.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LookupScreen(
        repository: repository,
        preferences: preferences,
        links: links,
      ),
    );
  }
}
