import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/core/failures.dart';
import 'package:wikitree_viewer/data/key_parser.dart';
import 'package:wikitree_viewer/ui/format/failure_text.dart';

import 'helpers/localizations.dart';

void main() {
  group('KeyParser accepts', () {
    const Map<String, String> cases = <String, String>{
      'Clemens-1': 'Clemens-1',
      '  Clemens-1  ': 'Clemens-1',
      'clemens-1': 'clemens-1',
      "O'Brien-1234": "O'Brien-1234",
      'Van_Der_Berg-12': 'Van_Der_Berg-12',
      'Smith-Jones-12': 'Smith-Jones-12',
      'Clemens-1 - WikiTree': 'Clemens-1',
      '"Clemens-1"': 'Clemens-1',
      'Clemens-1.': 'Clemens-1',
      'https://www.wikitree.com/wiki/Clemens-1': 'Clemens-1',
      'https://www.wikitree.com/wiki/Clemens-1?foo=bar#top': 'Clemens-1',
      'http://wikitree.com/wiki/Clemens-1': 'Clemens-1',
      'www.wikitree.com/wiki/Clemens-1': 'Clemens-1',
      'wikitree.com/wiki/Clemens-1': 'Clemens-1',
      'https://m.wikitree.com/wiki/Clemens-1': 'Clemens-1',
      'Van Der Berg-12': 'Van_Der_Berg-12',
      // Letters outside A-Z are real: Mileva Marić is Marić-75 on WikiTree.
      'Marić-75': 'Marić-75',
      'marić-75': 'marić-75',
      'https://www.wikitree.com/wiki/Marić-75': 'Marić-75',
      'Marić-75 - WikiTree': 'Marić-75',
      'Ångström-1': 'Ångström-1',
      // The link the app itself shares, which people do paste back in.
      'https://under3415.github.io/wikitree-viewer/open/?id=Clemens-1':
          'Clemens-1',
      'https://under3415.github.io/wikitree-viewer/open/?id=Clemens-1&utm=x':
          'Clemens-1',
      'https://under3415.github.io/wikitree-viewer/open/Clemens-1': 'Clemens-1',
      'https://under3415.github.io/wikitree-viewer/open/#Clemens-1': 'Clemens-1',
    };

    cases.forEach((input, expected) {
      test('"$input" becomes $expected', () {
        expect(KeyParser.parse(input).wikiTreeId, expected);
      });
    });
  });

  group('KeyParser rejects', () {
    void rejects(String input, InvalidKeyReason reason) {
      test('"$input" fails with ${reason.name}', () {
        expect(
          () => KeyParser.parse(input),
          throwsA(
            isA<InvalidKeyFailure>().having(
              (failure) => failure.reason,
              'reason',
              reason,
            ),
          ),
        );
      });
    }

    rejects('', InvalidKeyReason.empty);
    rejects('   ', InvalidKeyReason.empty);
    rejects('Clemens - 1', InvalidKeyReason.malformed);
    rejects('Space:My_Research_Page', InvalidKeyReason.spaceProfile);
    rejects(
      'https://example.com/wiki/Clemens-1',
      InvalidKeyReason.unsupportedHost,
    );
    rejects(
      'https://www.wikitree.com/genealogy/Clemens-1',
      InvalidKeyReason.noIdFound,
    );
    // The app's own page without a code in it.
    rejects(
      'https://under3415.github.io/wikitree-viewer/open/',
      InvalidKeyReason.noIdFound,
    );
    rejects('1835-1910', InvalidKeyReason.noIdFound);
    rejects('Clemens-1 and Langdon-1', InvalidKeyReason.ambiguous);
    rejects(List<String>.filled(400, 'x').join(), InvalidKeyReason.tooLong);
  });

  test('flags input that came from a URL', () {
    expect(
      KeyParser.parse('https://www.wikitree.com/wiki/Clemens-1').fromUrl,
      isTrue,
    );
    expect(KeyParser.parse('Clemens-1').fromUrl, isFalse);
  });

  test('error text never repeats what the user typed', () async {
    final l10n = await loadEnglish();
    const input = 'https://example.com/wiki/Somebody-1';
    try {
      KeyParser.parse(input);
      fail('expected an InvalidKeyFailure');
    } on WikiTreeFailure catch (failure) {
      final text = describeFailure(l10n, failure);
      expect(text.message.contains('Somebody'), isFalse);
      expect(text.hint.contains('Somebody'), isFalse);
      expect(failure.toString().contains('Somebody'), isFalse);
    }
  });
}
