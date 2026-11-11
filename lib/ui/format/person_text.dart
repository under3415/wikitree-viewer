import 'package:flutter/widgets.dart';

import '../../data/person.dart';
import '../../l10n/app_localizations.dart';
import '../../util/dates.dart';

/// The words the app puts around a person: names, dates, and the notes that
/// stand in when WikiTree has nothing to show.
///
/// [Person] itself carries no phrasing, so the same record reads correctly in
/// every language; everything that reaches a screen, a painted label or a shared
/// message is built here.
class PersonText {
  const PersonText(this.l10n, this.locale);

  factory PersonText.of(BuildContext context) => PersonText(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toString(),
  );

  final AppLocalizations l10n;

  /// Used for month names, e.g. `en`, `de`, `pt_BR`.
  final String locale;

  /// First name plus surname, or a note when WikiTree released no name.
  String displayName(Person person) =>
      person.displayName.isEmpty ? l10n.privateProfile : person.displayName;

  /// The full name, mentioning a surname taken later in life.
  String fullName(Person person) {
    final base = person.nameAtBirth;
    final later = person.laterSurname;
    if (base.isEmpty) return later ?? displayName(person);
    if (later == null) return base;
    return l10n.nameLater(base, later);
  }

  /// `1835–1910`, `b. 1950`, `d. 1910` or `Dates unknown`.
  String lifeSpan(Person person) {
    final birth = person.birthYear;
    final death = person.deathYear;
    if (birth != null && death != null) return l10n.yearRange(birth, death);
    if (birth != null) {
      return person.isLiving ? l10n.bornYear(birth) : '$birth';
    }
    if (death != null) return l10n.diedYear(death);
    return l10n.datesUnknown;
  }

  /// The second line under a name in the tree: dates, or a note that WikiTree
  /// keeps the profile hidden.
  String treeSecondLine(Person person, {required bool hasDetails}) =>
      hasDetails ? lifeSpan(person) : l10n.notPublic;

  /// `30 Nov 1835` in the app's language, or null when the date is unknown.
  String? longDate(String? value) => formatLongDate(value, locale: locale);

  String birthDescription(Person person) =>
      longDate(person.birthDate) ?? l10n.unknown;

  String deathDescription(Person person) =>
      longDate(person.deathDate) ?? l10n.unknown;

  /// `m. 2 Feb 1870` or `m. 2 Feb 1870, ended 3 Mar 1880`.
  String marriageDescription(SpouseLink link) {
    final start = longDate(link.marriageDate);
    if (start == null) return '';
    if (!link.marriageEnded) return l10n.married(start);
    final end = longDate(link.marriageEndDate);
    return end == null ? l10n.married(start) : l10n.marriedAndEnded(start, end);
  }

  /// Screen-reader label for a photo or monogram.
  String photoLabel(Person person) =>
      l10n.personSemantics(displayName(person), lifeSpan(person));
}
