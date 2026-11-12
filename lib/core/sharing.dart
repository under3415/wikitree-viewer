import '../data/person.dart';
import '../l10n/app_localizations.dart';
import '../ui/format/person_text.dart';
import 'constants.dart';
import 'deep_links.dart';

/// The message behind the share button.
///
/// It carries three things deliberately: whose tree it is, a link that reopens
/// this app, and somewhere to get the app when it is not installed.
///
/// The link is the only URL in the message and it sits directly after the
/// sentence that introduces it, because chat apps and note apps turn https
/// links into something tappable and nothing else: a `wikitreeviewer://` link
/// pasted into Viber or OneNote stays dead text. See [DeepLink.forKey].
String shareMessage(
  Person person, {
  required AppLocalizations l10n,
  required PersonText text,
}) {
  final name = text.displayName(person);
  final hasDates = person.birthYear != null || person.deathYear != null;
  final link = DeepLink.forKey(person.wikiTreeId);
  final title = hasDates
      ? l10n.shareTitleWithDates(
          name,
          text.lifeSpan(person),
          AppInfo.displayName,
          link,
        )
      : l10n.shareTitle(name, AppInfo.displayName, link);

  return <String>[
    title,
    '',
    l10n.shareInstall(AppInfo.displayName, AppInfo.installUrl),
  ].join('\n');
}
