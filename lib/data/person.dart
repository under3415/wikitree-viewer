import '../core/constants.dart';
import '../util/dates.dart';
import 'json_util.dart';

/// A person as returned by the WikiTree API.
///
/// Field names mirror the API: `Name` is the WikiTree ID (`Einstein-1`) while
/// `Id` is the numeric person id used by every relationship field. Parsing is
/// defensive on purpose - private profiles arrive with little more than an id
/// and a name, and the API mixes numbers, numeric strings and blanks.
class Person {
  const Person({
    required this.id,
    required this.wikiTreeId,
    this.pageId,
    this.firstName,
    this.middleName,
    this.lastNameAtBirth,
    this.lastNameCurrent,
    this.realName,
    this.prefix,
    this.suffix,
    this.nicknames,
    this.birthDate,
    this.deathDate,
    this.birthLocation,
    this.deathLocation,
    this.gender,
    this.isLiving = false,
    this.privacy = 0,
    this.privacyIsPrivate = false,
    this.privacyIsOpen = false,
    this.privacyIsAtLeastPublic = false,
    this.fatherId,
    this.motherId,
    this.photoThumbPath,
    this.photoPath,
    this.photoFileName,
  });

  final int id;
  final int? pageId;

  /// The WikiTree ID, e.g. `Einstein-1`. This is the public part of the profile
  /// URL and the key used for every API call.
  final String wikiTreeId;

  final String? firstName;
  final String? middleName;
  final String? lastNameAtBirth;
  final String? lastNameCurrent;
  final String? realName;
  final String? prefix;
  final String? suffix;
  final String? nicknames;

  final String? birthDate;
  final String? deathDate;
  final String? birthLocation;
  final String? deathLocation;
  final String? gender;

  final bool isLiving;
  final int privacy;
  final bool privacyIsPrivate;
  final bool privacyIsOpen;
  final bool privacyIsAtLeastPublic;

  final int? fatherId;
  final int? motherId;

  /// Relative path to the 75px thumbnail (`PhotoData.url`). This is the only
  /// photo the app displays, per WikiTree's app policies.
  final String? photoThumbPath;

  /// Relative path to the full-size image (`PhotoData.path`). Never displayed;
  /// only used to reach the image on WikiTree.
  final String? photoPath;

  final String? photoFileName;

  /// Returns null when the object cannot represent a person (no usable id or
  /// name), so callers can skip junk entries instead of crashing.
  static Person? tryFromJson(Object? json) {
    final map = asMap(json);
    if (map == null) return null;

    final id = asInt(map['Id']);
    final name = asString(map['Name']);
    if (id == null || id <= 0 || name == null) return null;

    final photo = asMap(map['PhotoData']);

    return Person(
      id: id,
      pageId: asInt(map['PageId']),
      wikiTreeId: name,
      firstName: asString(map['FirstName']),
      middleName: asString(map['MiddleName']),
      lastNameAtBirth: asString(map['LastNameAtBirth']),
      lastNameCurrent: asString(map['LastNameCurrent']),
      realName: asString(map['RealName']),
      prefix: asString(map['Prefix']),
      suffix: asString(map['Suffix']),
      nicknames: asString(map['Nicknames']),
      birthDate: asString(map['BirthDate']),
      deathDate: asString(map['DeathDate']),
      birthLocation: asString(map['BirthLocation']),
      deathLocation: asString(map['DeathLocation']),
      gender: asString(map['Gender']),
      isLiving: asBool(map['IsLiving']),
      privacy: asInt(map['Privacy']) ?? 0,
      privacyIsPrivate: asBool(map['Privacy_IsPrivate']),
      privacyIsOpen: asBool(map['Privacy_IsOpen']),
      privacyIsAtLeastPublic: asBool(map['Privacy_IsAtLeastPublic']),
      fatherId: asRelationshipId(map['Father']),
      motherId: asRelationshipId(map['Mother']),
      photoThumbPath: photo == null ? null : asString(photo['url']),
      photoPath: photo == null ? null : asString(photo['path']),
      photoFileName: asString(map['Photo']),
    );
  }

  /// True when WikiTree returned only the skeleton it shows for profiles the
  /// viewer is not allowed to see (living or private people).
  bool get isLimited => firstName == null && lastNameAtBirth == null;

  String get preferredFirstName {
    final preferred = realName;
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return firstName ?? '';
  }

  String get lastName {
    final current = lastNameCurrent;
    if (current != null && current.isNotEmpty) return current;
    return lastNameAtBirth ?? '';
  }

  /// Short name for cards: first name plus current or birth surname.
  ///
  /// Empty when WikiTree released no name at all; the wording that stands in for
  /// such a person is a job for the UI layer, not for the record.
  String get displayName {
    final first = preferredFirstName;
    final last = lastName;
    if (first.isEmpty && last.isEmpty) return '';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  /// The name as recorded at birth, including prefix, middle name and suffix,
  /// e.g. `Samuel Langhorne Clemens`.
  String get nameAtBirth {
    final parts = <String>[
      ?prefix,
      ?firstName,
      ?middleName,
      ?lastNameAtBirth,
      ?suffix,
    ];
    return parts.join(' ').trim();
  }

  /// A surname taken later in life, when it differs from the birth surname.
  String? get laterSurname {
    final current = lastNameCurrent;
    if (current == null || current.isEmpty) return null;
    final atBirth = lastNameAtBirth;
    if (atBirth == null || atBirth.isEmpty) return current;
    return current.toLowerCase() == atBirth.toLowerCase() ? null : current;
  }

  int? get birthYear => yearOf(birthDate);
  int? get deathYear => yearOf(deathDate);

  String get initials {
    final first = preferredFirstName;
    final last = lastName;
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0].toUpperCase());
    if (last.isNotEmpty) buffer.write(last[0].toUpperCase());
    final value = buffer.toString();
    return value.isEmpty ? '?' : value;
  }

  String? get photoUrl {
    final path = photoThumbPath;
    return path == null ? null : WebConfig.photoUrl(path);
  }

  String get profileUrl => WebConfig.profileUrl(wikiTreeId);

  int? get ageAtDeath => ageAtDeathYears(birthDate, deathDate);

  /// Rough measure of how much information a record carries. Used when the same
  /// person arrives twice (once slim, once complete) so the richer copy wins.
  int get quality {
    var score = 0;
    if (firstName != null) score += 2;
    if (lastNameAtBirth != null) score += 2;
    if (birthDate != null) score += 1;
    if (deathDate != null) score += 1;
    if (birthLocation != null) score += 1;
    if (deathLocation != null) score += 1;
    if (gender != null) score += 1;
    if (photoThumbPath != null) score += 1;
    if (fatherId != null) score += 1;
    if (motherId != null) score += 1;
    return score;
  }

  /// Combines this record with another copy of the same person, preferring
  /// whichever copy is richer and filling any gaps from the other.
  Person mergedWith(Person other) {
    if (other.id != id) return this;
    final Person base;
    final Person extra;
    if (other.quality > quality) {
      base = other;
      extra = this;
    } else {
      base = this;
      extra = other;
    }

    return Person(
      id: id,
      pageId: base.pageId ?? extra.pageId,
      wikiTreeId: base.wikiTreeId,
      firstName: base.firstName ?? extra.firstName,
      middleName: base.middleName ?? extra.middleName,
      lastNameAtBirth: base.lastNameAtBirth ?? extra.lastNameAtBirth,
      lastNameCurrent: base.lastNameCurrent ?? extra.lastNameCurrent,
      realName: base.realName ?? extra.realName,
      prefix: base.prefix ?? extra.prefix,
      suffix: base.suffix ?? extra.suffix,
      nicknames: base.nicknames ?? extra.nicknames,
      birthDate: base.birthDate ?? extra.birthDate,
      deathDate: base.deathDate ?? extra.deathDate,
      birthLocation: base.birthLocation ?? extra.birthLocation,
      deathLocation: base.deathLocation ?? extra.deathLocation,
      gender: base.gender ?? extra.gender,
      isLiving: base.isLiving || extra.isLiving,
      privacy: base.privacy == 0 ? extra.privacy : base.privacy,
      privacyIsPrivate: base.privacyIsPrivate || extra.privacyIsPrivate,
      privacyIsOpen: base.privacyIsOpen || extra.privacyIsOpen,
      privacyIsAtLeastPublic:
          base.privacyIsAtLeastPublic || extra.privacyIsAtLeastPublic,
      fatherId: base.fatherId ?? extra.fatherId,
      motherId: base.motherId ?? extra.motherId,
      photoThumbPath: base.photoThumbPath ?? extra.photoThumbPath,
      photoPath: base.photoPath ?? extra.photoPath,
      photoFileName: base.photoFileName ?? extra.photoFileName,
    );
  }

  @override
  String toString() => 'Person($wikiTreeId)';
}

/// A spouse of a person, together with the marriage details WikiTree returns
/// alongside the spouse's profile.
class SpouseLink {
  const SpouseLink({
    required this.person,
    this.marriageDate,
    this.marriageEndDate,
    this.marriageLocation,
    this.doNotDisplay = false,
  });

  final Person person;
  final String? marriageDate;
  final String? marriageEndDate;
  final String? marriageLocation;

  /// WikiTree lets people hide a marriage; when set, it must not be shown.
  final bool doNotDisplay;

  static SpouseLink? tryFromJson(Object? json) {
    final map = asMap(json);
    if (map == null) return null;
    final person = Person.tryFromJson(map);
    if (person == null) return null;
    return SpouseLink(
      person: person,
      marriageDate:
          asString(map['MarriageDate']) ?? asString(map['marriage_date']),
      marriageEndDate:
          asString(map['MarriageEndDate']) ??
          asString(map['marriage_end_date']),
      marriageLocation:
          asString(map['MarriageLocation']) ??
          asString(map['marriage_location']),
      doNotDisplay:
          asBool(map['DoNotDisplay']) || asBool(map['do_not_display']),
    );
  }

  bool get visible => !doNotDisplay;

  /// True when the marriage ended (divorce, or the death of a spouse).
  bool get marriageEnded => !isUnsetDate(marriageEndDate);

  int? get marriageYear => yearOf(marriageDate);
}
