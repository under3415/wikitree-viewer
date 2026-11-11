import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wikitree_viewer/l10n/app_localizations.dart';
import 'package:wikitree_viewer/ui/format/person_text.dart';

/// The wording of one language, for tests that check what the app says.
///
/// The app itself gets these from `MaterialApp`; a plain unit test has to ask
/// the generated delegate directly. `initializeDateFormatting` is what the app
/// does at startup, so month names come out in the right language here too.
Future<AppLocalizations> loadLocalizations(String code) async {
  await initializeDateFormatting(code);
  return AppLocalizations.delegate.load(Locale(code));
}

/// English wording, the language most tests assert on.
Future<AppLocalizations> loadEnglish() => loadLocalizations('en');

/// A [PersonText] for the language of [l10n].
PersonText textFor(AppLocalizations l10n, String code) =>
    PersonText(l10n, code);

/// English [PersonText], for dates and names.
PersonText englishText(AppLocalizations l10n) => PersonText(l10n, 'en');
