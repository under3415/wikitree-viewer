import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/ui/format/person_text.dart';

import 'helpers/localizations.dart';

Map<String, dynamic> _peopleFixture() {
  final decoded = jsonDecode(
    File('test/fixtures/get_people.json').readAsStringSync(),
  ) as List<dynamic>;
  final first = decoded.first as Map<String, dynamic>;
  return first['people'] as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> people;
  late PersonText text;

  setUpAll(() async {
    people = _peopleFixture();
    text = englishText(await loadEnglish());
  });

  test('parses a complete profile', () {
    final person = Person.tryFromJson(people['5185'])!;
    expect(person.id, 5185);
    expect(person.pageId, 7146);
    expect(person.wikiTreeId, 'Clemens-1');
    expect(person.displayName, 'Samuel Clemens');
    expect(text.fullName(person), 'Samuel Langhorne Clemens');
    expect(text.lifeSpan(person), '1835\u20131910');
    expect(person.birthYear, 1835);
    expect(person.deathYear, 1910);
    expect(person.ageAtDeath, 74);
    expect(person.initials, 'SC');
    expect(person.fatherId, 5186);
    expect(person.motherId, 5188);
    expect(person.isLimited, isFalse);
  });

  test('builds WikiTree and 75px photo URLs', () {
    final person = Person.tryFromJson(people['5185'])!;
    expect(person.profileUrl, 'https://www.wikitree.com/wiki/Clemens-1');
    expect(
      person.photoUrl,
      'https://www.wikitree.com/photo.php/thumb/0/08/'
      '1871-Samuel_Clemens.jpg/75px-1871-Samuel_Clemens.jpg',
    );
    expect(person.photoThumbPath, contains('75px-'));
  });

  test('treats a missing photo as no photo', () {
    final person = Person.tryFromJson(people['5186'])!;
    expect(person.photoUrl, isNull);
    expect(person.initials, 'JC');
  });

  test('treats Father 0 as unknown', () {
    final person = Person.tryFromJson(people['5188'])!;
    expect(person.fatherId, isNull);
    expect(person.motherId, isNull);
    expect(text.lifeSpan(person), '1803\u20131890');
  });

  test('handles zero month and day', () {
    final person = Person.tryFromJson(people['3586'])!;
    expect(person.birthYear, 1873);
    expect(text.birthDescription(person), '1873');
    expect(text.lifeSpan(person), '1873\u20131909');
  });

  test('handles a privacy-limited profile', () {
    final person = Person.tryFromJson(people['9999'])!;
    expect(person.isLimited, isTrue);
    expect(text.displayName(person), 'Private profile');
    expect(text.lifeSpan(person), 'Dates unknown');
    expect(person.initials, '?');
    expect(person.privacyIsPrivate, isTrue);
  });

  test('rejects objects that cannot be a person', () {
    expect(Person.tryFromJson(null), isNull);
    expect(Person.tryFromJson(<String, dynamic>{'Name': 'Clemens-1'}), isNull);
    expect(
      Person.tryFromJson(<String, dynamic>{'Id': 0, 'Name': 'x-1'}),
      isNull,
    );
    expect(Person.tryFromJson('not a map'), isNull);
  });

  test('merging prefers the richer record and fills gaps', () {
    final full = Person.tryFromJson(people['5185'])!;
    const slim = Person(id: 5185, wikiTreeId: 'Clemens-1', privacy: 60);

    final merged = slim.mergedWith(full);
    expect(merged.displayName, 'Samuel Clemens');
    expect(merged.birthDate, '1835-11-30');
    expect(merged.photoUrl, isNotNull);

    final reverse = full.mergedWith(slim);
    expect(reverse.birthDate, '1835-11-30');
    expect(reverse.photoUrl, isNotNull);
  });

  test('merging ignores a different person', () {
    final samuel = Person.tryFromJson(people['5185'])!;
    final jane = Person.tryFromJson(people['5188'])!;
    expect(samuel.mergedWith(jane).id, samuel.id);
    expect(samuel.mergedWith(jane).displayName, 'Samuel Clemens');
  });
}
