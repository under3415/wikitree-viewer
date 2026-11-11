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
    test('builds the link it shares', () {
      expect(
        DeepLink.forKey('Einstein-1'),
        'wikitreeviewer://person/Einstein-1',
      );
    });

    test('reads the shared app link', () {
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

    test('carries the profile, the app link and the install page', () {
      final message = shareMessage(_albert, l10n: l10n, text: text);

      expect(message, contains('Albert Einstein (1879–1955) on WikiTree'));
      expect(message, contains('https://www.wikitree.com/wiki/Einstein-1'));
      expect(
        message,
        contains(
          'Open in ${AppInfo.displayName}: wikitreeviewer://person/Einstein-1',
        ),
      );
      expect(message, contains(AppInfo.installUrl));
    });

    test('leaves the dates out when they are unknown', () {
      const person = Person(id: 9, wikiTreeId: 'Anon-9', firstName: 'Anon');

      expect(
        shareMessage(person, l10n: l10n, text: text),
        contains('Anon on WikiTree'),
      );
      expect(
        shareMessage(person, l10n: l10n, text: text),
        isNot(contains('()')),
      );
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
