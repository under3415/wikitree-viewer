/// Small, dependency-free date helpers.
///
/// WikiTree dates are `YYYY-MM-DD` strings where unknown parts are zero
/// (`1773-00-00`). Some records simply omit the field. Everything here treats
/// those cases as "unknown" rather than inventing a date.
library;

import 'package:intl/intl.dart';

/// English month names, used only when no date data is loaded for a language
/// (for instance in a unit test that never started the app's localisations).
const List<String> _fallbackMonthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// True when the value carries no usable date information.
bool isUnsetDate(String? value) {
  if (value == null) return true;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  return trimmed.startsWith('0000');
}

/// Extracts a four-digit year, or null when the year is unknown.
int? yearOf(String? value) {
  if (isUnsetDate(value)) return null;
  final trimmed = value!.trim();
  if (trimmed.length < 4) return null;
  final year = int.tryParse(trimmed.substring(0, 4));
  if (year == null || year <= 0) return null;
  return year;
}

/// Formats a WikiTree date as `30 Nov 1835`, `Nov 1835` or `1835`, returning
/// null when nothing is known.
///
/// The month is written the way [locale] writes it, so a German reader gets
/// `30 Nov. 1835` and a French one `30 nov. 1835`. The order stays day-month-year
/// because that is how a date of birth is read on a small card.
String? formatLongDate(String? value, {String locale = 'en'}) {
  if (isUnsetDate(value)) return null;
  final parts = value!.trim().split('-');
  final year = int.tryParse(parts.first) ?? 0;
  if (year <= 0) return null;
  if (parts.length < 2) return '$year';

  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return '$year';
  final monthName = _shortMonth(locale, month);
  if (parts.length < 3) return '$monthName $year';

  final day = int.tryParse(parts[2]) ?? 0;
  if (day < 1 || day > 31) return '$monthName $year';
  return '$day $monthName $year';
}

/// `Nov`, `Nov.` or `nov.`, depending on the language.
String _shortMonth(String locale, int month) {
  try {
    return DateFormat.MMM(locale).format(DateTime(2000, month));
  } catch (_) {
    // No month data for this language; English is a readable last resort.
    return _fallbackMonthNames[month - 1];
  }
}

/// Age in years at death, when both years are known and plausible.
///
/// Month and day are taken into account when both are known, so a person who
/// died shortly before their birthday is not reported a year older.
int? ageAtDeathYears(String? birthDate, String? deathDate) {
  final birth = _parseDate(birthDate);
  final death = _parseDate(deathDate);
  if (birth == null || death == null) return null;

  var age = death.year - birth.year;
  if (age < 0) return null;

  final bothHaveMonthAndDay =
      birth.month > 0 && death.month > 0 && birth.day > 0 && death.day > 0;
  if (bothHaveMonthAndDay) {
    final beforeBirthday =
        death.month < birth.month ||
        (death.month == birth.month && death.day < birth.day);
    if (beforeBirthday) age -= 1;
  }

  if (age < 0 || age > 130) return null;
  return age;
}

class _DateParts {
  const _DateParts(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;
}

_DateParts? _parseDate(String? value) {
  if (isUnsetDate(value)) return null;
  final parts = value!.trim().split('-');
  final year = int.tryParse(parts.first) ?? 0;
  if (year <= 0) return null;
  final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final day = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return _DateParts(year, month, day);
}
