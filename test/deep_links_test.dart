import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/core/constants.dart';
import 'package:wikitree_viewer/core/deep_links.dart';
import 'package:wikitree_viewer/core/sharing.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/l10n/app_localizations.dart';
import 'package:wikitree_viewer/ui/format/person_text.dart';

import 'helpers/localizations.dart';

const Person _albert = Person(
  id: 1,
  wikiTreeId: 'Einstein-1',
  firstName: 'Albert',
  lastNameAtBirth: 'Einstein',
  birthDate: '1879-03-14',
  deathDate: '1955-04-18',
);

void main() {
  group('DeepLink', () {
    test('builds the https link it shares', () {
      // https, not wikitreeviewer://: messengers and note apps only make https
      // links tappable, so this is the only shape worth sharing.
      expect(
        DeepLink.forKey('Einstein-1'),
        'https://under3415.github.io/wikitree-viewer/open/?id=Einstein-1',
      );
    });

    test('reads back the link it shares', () {
      final link = Uri.parse(DeepLink.forKey('Einstein-1'));

      expect(link.scheme, 'https');
      expect(DeepLink.keyFrom(link), 'Einstein-1');
    });

    test('reads the shared page in the shapes a link can arrive in', () {
      expect(
        DeepLink.keyFrom(
          Uri.parse('https://under3415.github.io/wikitree-viewer/open/Einstein-1'),
        ),
        'Einstein-1',
      );
      // Some apps keep the query but drop the trailing slash, some paste the
      // code into the fragment; both are cheap to understand.
      expect(
        DeepLink.keyFrom(
          Uri.parse('https://under3415.github.io/wikitree-viewer/open?id=Einstein-1'),
        ),
        'Einstein-1',
      );
      expect(
        DeepLink.keyFrom(
          Uri.parse('https://under3415.github.io/wikitree-viewer/open#Einstein-1'),
        ),
        'Einstein-1',
      );
    });

    test('ignores its own page when it carries no code', () {
      expect(
        DeepLink.keyFrom(
          Uri.parse('https://under3415.github.io/wikitree-viewer/open/'),
        ),
        isNull,
      );
      expect(DeepLink.keyFrom(Uri.parse('https://under3415.github.io/')), isNull);
    });

    test('still reads the app link it used to share', () {
      expect(
        DeepLink.keyFrom(Uri.parse('wikitreeviewer://person/Einstein-1')),
        'Einstein-1',
      );
    });

    test('reads the short form people will type', () {
      // Uri lowercases a host, so the app puts the capital back itself.
      expect(
        DeepLink.keyFrom(Uri.parse('wikitreeviewer://Einstein-1')),
        'Einstein-1',
      );
      expect(
        DeepLink.keyFrom(Uri.parse('wikitreeviewer://person/einstein-1')),
        'Einstein-1',
      );
    });

    test('reads a profile link handed over by a browser', () {
      expect(
        DeepLink.keyFrom(Uri.parse('https://www.wikitree.com/wiki/Clemens-1')),
        'Clemens-1',
      );
      expect(
        DeepLink.keyFrom(Uri.parse('https://wikitree.com/wiki/Clemens-1')),
        'Clemens-1',
      );
    });

    test('ignores links that are not ours', () {
      expect(
        DeepLink.keyFrom(Uri.parse('https://example.com/wiki/Thing-1')),
        isNull,
      );
      expect(DeepLink.keyFrom(Uri.parse('https://www.wikitree.com/')), isNull);
      expect(DeepLink.keyFrom(Uri.parse('wikitreeviewer://person')), isNull);
      expect(
        DeepLink.keyFrom(Uri.parse('wikitreeviewer://person/not-a-code')),
        isNull,
      );
      expect(DeepLink.keyFrom(Uri.parse('mailto:someone@example.com')), isNull);
    });
  });

  group('shareMessage', () {
    late AppLocalizations l10n;
    late PersonText text;

    setUpAll(() async {
      l10n = await loadEnglish();
      text = englishText(l10n);
    });

    test('carries the app link and the store page, and only one URL', () {
      final message = shareMessage(_albert, l10n: l10n, text: text);

      expect(
        message,
        contains(
          "View Albert Einstein's (1879–1955) family tree in "
          '${AppInfo.displayName}: ${DeepLink.forKey('Einstein-1')}',
        ),
      );
      expect(message, contains(AppInfo.installUrl));
      // The WikiTree profile URL used to sit on its own line. Two links in one
      // message left the reader guessing which one to tap.
      expect(message, isNot(contains('wikitree.com/wiki')));
      expect(message, isNot(contains('wikitreeviewer://')));
    });

    test('puts the link and the store page on their own lines', () {
      final lines = shareMessage(_albert, l10n: l10n, text: text).split('\n');

      expect(lines, hasLength(3));
      expect(lines.first, endsWith(DeepLink.forKey('Einstein-1')));
      expect(lines.last, endsWith(AppInfo.installUrl));
    });

    test('leaves the dates out when they are unknown', () {
      const person = Person(id: 9, wikiTreeId: 'Anon-9', firstName: 'Anon');

      final message = shareMessage(person, l10n: l10n, text: text);

      expect(
        message,
        contains("View Anon's family tree in ${AppInfo.displayName}:"),
      );
      expect(message, isNot(contains('()')));
    });
  });

  group('LinkInbox', () {
    test('holds a link that arrives before anybody is listening', () async {
      final inbox = LinkInbox();
      addTearDown(inbox.close);

      // The cold start: the launch link is known before the app is built.
      inbox.add('Einstein-1');

      expect(await inbox.keys.first, 'Einstein-1');
    });

    test('delivers later links as they arrive', () async {
      final inbox = LinkInbox();
      addTearDown(inbox.close);

      final received = <String>[];
      final subscription = inbox.keys.listen(received.add);
      addTearDown(subscription.cancel);

      inbox.add('Clemens-1');
      inbox.add('Einstein-1');
      await Future<void>.delayed(Duration.zero);

      expect(received, <String>['Clemens-1', 'Einstein-1']);
    });

    test('does not open the same person twice in a row', () async {
      final inbox = LinkInbox();
      addTearDown(inbox.close);

      final received = <String>[];
      final subscription = inbox.keys.listen(received.add);
      addTearDown(subscription.cancel);

      inbox.add('Einstein-1');
      inbox.add('Einstein-1');
      await Future<void>.delayed(Duration.zero);

      expect(received, <String>['Einstein-1']);
    });
  });
}
