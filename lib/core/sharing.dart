import '../data/person.dart';
import '../l10n/app_localizations.dart';
import '../ui/format/person_text.dart';
import 'constants.dart';
import 'deep_links.dart';

/// The message behind the share button.
///
/// It carries three things deliberately: where the person is on WikiTree (so the
/// information stays attributed and is readable without the app), a link that
/// reopens this app, and somewhere to get the app when it is not installed.
String shareMessage(
  Person person, {
  required AppLocalizations l10n,
  required PersonText text,
}) {
  final name = text.displayName(person);
  final hasDates = person.birthYear != null || person.deathYear != null;
  final title = hasDates
      ? l10n.shareTitleWithDates(name, text.lifeSpan(person))
      : l10n.shareTitle(name);

  return <String>[
    title,
    WebConfig.profileUrl(person.wikiTreeId),
    '',
    l10n.shareOpenIn(AppInfo.displayName, DeepLink.forKey(person.wikiTreeId)),
    l10n.shareInstall(AppInfo.displayName, AppInfo.installUrl),
  ].join('\n');
}
