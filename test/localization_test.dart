import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/core/constants.dart';
import 'package:wikitree_viewer/core/failures.dart';
import 'package:wikitree_viewer/data/key_parser.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/l10n/app_localizations.dart';
import 'package:wikitree_viewer/ui/format/failure_text.dart';

import 'helpers/localizations.dart';

/// Every language the app ships.
const List<String> _languages = <String>['en', 'de', 'es', 'pt', 'fr', 'sr'];

const Person _albert = Person(
  id: 1,
  wikiTreeId: 'Einstein-1',
  firstName: 'Albert',
  lastNameAtBirth: 'Einstein',
  birthDate: '1879-03-14',
  deathDate: '1955-04-18',
);

const Person _living = Person(
  id: 2,
  wikiTreeId: 'Anon-2',
  firstName: 'Anon',
  birthDate: '1950-00-00',
  isLiving: true,
);

const Person _undated = Person(id: 3, wikiTreeId: 'Anon-3');

void main() {
  test('the app offers every language it ships', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(_languages),
    );
  });

  test('English comes first, so it is the fallback for other languages', () {
    expect(AppLocalizations.supportedLocales.first.languageCode, 'en');
  });

  test('each language has its own wording', () async {
    final submit = <String, String>{
      for (final code in _languages)
        code: (await loadLocalizations(code)).lookupSubmit,
    };

    expect(submit, <String, String>{
      'en': 'Show family tree',
      'de': 'Stammbaum anzeigen',
      'es': 'Ver árbol familiar',
      'pt': 'Ver árvore genealógica',
      'fr': "Afficher l'arbre familial",
      'sr': 'Prikaži porodično stablo',
    });
  });

  test('the refresh message is written in each language', () async {
    final done = <String, String>{
      for (final code in _languages)
        code: (await loadLocalizations(code)).refreshDone,
    };

    expect(done, <String, String>{
      'en': 'Updated from WikiTree',
      'de': 'Von WikiTree aktualisiert',
      'es': 'Actualizado desde WikiTree',
      'pt': 'Atualizado do WikiTree',
      'fr': 'Mis à jour depuis WikiTree',
      'sr': 'Ažurirano sa WikiTree-a',
    });
  });

  test('every language suggests families its readers recognise', () {
    for (final code in _languages) {
      final examples = AppInfo.examplesFor(code);
      expect(examples, hasLength(2), reason: code);
      expect(examples.toSet(), hasLength(2), reason: code);
      for (final example in examples) {
        // Typing the example has to work, so it has to parse as a family code -
        // including the ones with letters outside A-Z.
        expect(
          KeyParser.parse(example).wikiTreeId,
          example,
          reason: '$code: $example',
        );
      }
    }

    // A language the app does not speak falls back to the English pair.
    expect(AppInfo.examplesFor('it'), AppInfo.examplesFor('en'));
    // And the pair is not the same everywhere: that is the point.
    expect(AppInfo.examplesFor('de'), <String>['Goethe-22', 'Van_Beethoven-1']);
    expect(AppInfo.examplesFor('sr'), <String>['Karađorđević-13', 'Tesla-1']);
    expect(AppInfo.examplesFor('fr'), <String>['Hugo-215', 'Bonaparte-1']);
  });

  test('counts are pluralised the way each language does it', () async {
    final one = <String, String>{
      for (final code in _languages)
        code: (await loadLocalizations(code)).moreCount(1),
    };
    final three = <String, String>{
      for (final code in _languages)
        code: (await loadLocalizations(code)).moreCount(3),
    };

    expect(one['en'], '1 more');
    expect(three['en'], '3 more');
    expect(one['de'], '1 weitere Person');
    expect(three['de'], '3 weitere Personen');
    expect(one['fr'], '1 de plus');
    expect(three['fr'], '3 de plus');
    expect(three['es'], '3 más');
    expect(three['pt'], '3 a mais');
    // Serbian counts in three shapes: one, a few (two to four) and the rest.
    expect(one['sr'], 'još 1 osoba');
    expect((await loadLocalizations('sr')).moreCount(3), 'još 3 osobe');
    expect((await loadLocalizations('sr')).moreCount(5), 'još 5 osoba');
  });

  group('dates', () {
    test('months are written the way each language writes them', () async {
      final march = <String, String?>{};
      for (final code in _languages) {
        march[code] = textFor(
          await loadLocalizations(code),
          code,
        ).longDate('1835-03-00');
      }

      expect(march, <String, String?>{
        'en': 'Mar 1835',
        'de': 'Mär 1835',
        'es': 'mar 1835',
        'pt': 'mar. 1835',
        'fr': 'mars 1835',
        // Serbian month names come from `sr_Latn`: the app writes Serbian in
        // Latin, and plain `sr` would answer in Cyrillic.
        'sr': 'mar 1835',
      });

      // A tag that names its own script has to reach the same Latin data.
      // `sr-Latn` arrives with a dash from platform code and would otherwise find
      // no month data at all - which the fallback would quietly answer in English.
      final serbian = await loadLocalizations('sr');
      for (final tag in <String>['sr-Latn', 'sr_Latn', 'sr-Latn-RS', 'sr-RS']) {
        expect(
          textFor(serbian, tag).longDate('1835-03-00'),
          'mar 1835',
          reason: tag,
        );
      }
    });

    test('a full date keeps its day and year', () async {
      final text = textFor(await loadLocalizations('de'), 'de');
      expect(text.longDate('1879-03-14'), '14 Mär 1879');
      expect(text.longDate('1879-00-00'), '1879');
      expect(text.longDate(null), isNull);
    });

    test('a life span uses each language\'s abbreviations', () async {
      final spans = <String, List<String>>{};
      for (final code in _languages) {
        final text = textFor(await loadLocalizations(code), code);
        spans[code] = <String>[
          text.lifeSpan(_albert),
          text.lifeSpan(_living),
          text.lifeSpan(_undated),
        ];
      }

      expect(spans['en'], <String>[
        '1879\u20131955',
        'b. 1950',
        'Dates unknown',
      ]);
      expect(spans['de'], <String>[
        '1879\u20131955',
        'geb. 1950',
        'Daten unbekannt',
      ]);
      expect(spans['es'], <String>[
        '1879\u20131955',
        'n. 1950',
        'Fechas desconocidas',
      ]);
      expect(spans['pt'], <String>[
        '1879\u20131955',
        'n. 1950',
        'Datas desconhecidas',
      ]);
      expect(spans['fr'], <String>[
        '1879\u20131955',
        'n. 1950',
        'Dates inconnues',
      ]);
      expect(spans['sr'], <String>[
        '1879\u20131955',
        'rođ. 1950',
        'Datumi nepoznati',
      ]);
    });
  });

  test('error messages are translated, not copied', () async {
    final emptyKey = <String, String>{};
    final notFoundHint = <String, String>{};
    for (final code in _languages) {
      final l10n = await loadLocalizations(code);
      emptyKey[code] = describeFailure(
        l10n,
        const InvalidKeyFailure(InvalidKeyReason.empty),
      ).message;
      notFoundHint[code] = describeFailure(l10n, const NotFoundFailure()).hint;
    }

    expect(
      emptyKey['de'],
      'Geben Sie eine WikiTree-ID oder einen Profil-Link ein.',
    );
    expect(
      emptyKey['fr'],
      'Saisissez un identifiant WikiTree ou un lien de profil.',
    );
    expect(emptyKey['sr'], 'Unesite WikiTree ID ili link profila.');
    expect(notFoundHint['es'], 'Revisa el código o pega el enlace del perfil.');
    expect(notFoundHint.values.toSet().length, _languages.length);
  });
}
