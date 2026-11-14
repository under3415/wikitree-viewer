import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wikitree_viewer/core/failures.dart';
import 'package:wikitree_viewer/data/cache/response_cache.dart';
import 'package:wikitree_viewer/data/wikitree_api.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _json(String body, [int statusCode = 200]) => http.Response(
  body,
  statusCode,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'sends the required parameters and never asks for a biography',
    () async {
      late Uri captured;
      final api = HttpWikiTreeApi(
        client: MockClient((request) async {
          captured = request.url;
          return _json(_fixture('get_people.json'));
        }),
      );

      await api.getPeople(key: 'Clemens-1', ancestors: 3, descendants: 2);

      expect(captured.host, 'api.wikitree.com');
      expect(captured.queryParameters['action'], 'getPeople');
      expect(captured.queryParameters['keys'], 'Clemens-1');
      expect(captured.queryParameters['ancestors'], '3');
      expect(captured.queryParameters['descendants'], '2');
      expect(captured.queryParameters['appId'], 'WikiTreeViewer');
      expect(captured.queryParameters['resolveRedirect'], '1');
      expect(captured.queryParameters['fields'], contains('PhotoData'));
      expect(captured.queryParameters['fields'], contains('Father'));
      expect(captured.queryParameters['fields'], isNot(contains('Bio')));
      expect(captured.queryParameters.containsKey('nuclear'), isFalse);
    },
  );

  test('parses people and the resolved id', () async {
    final api = HttpWikiTreeApi(
      client: MockClient((request) async => _json(_fixture('get_people.json'))),
    );

    final response = await api.getPeople(key: 'Clemens-1');

    expect(response.people.length, 6);
    expect(response.resolvedId, 5185);
    expect(response.people.first.wikiTreeId, 'Clemens-1');
  });

  test('encodes letters outside ASCII in the request', () async {
    late Uri captured;
    final api = HttpWikiTreeApi(
      client: MockClient((request) async {
        captured = request.url;
        return _json(_fixture('get_people.json'));
      }),
    );

    // Mileva Marić is Marić-75 on WikiTree: the surname is not ASCII.
    await api.getPeople(key: 'Marić-75');

    expect(captured.queryParameters['keys'], 'Marić-75');
    expect(captured.query, contains('Mari%C4%87-75'));
  });

  test('maps an invalid key status to a not-found failure', () async {
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => _json(_fixture('status_invalid_key.json')),
      ),
    );

    await expectLater(
      api.getPeople(key: 'NotA-real-key'),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('reports a withheld family tree as a private profile', () async {
    // What WikiTree answers for an Unlisted profile: the id, a reason, and a
    // nameless placeholder in `people`. It used to surface as "not found".
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => _json(
          '{"status":"","resultByKey":{"Umićević-2":{"Id":49242991,'
          '"status":"Ancestor/Descendant permission denied."}},'
          '"people":{"-1":{"Id":-1,"PageId":54442844,"Privacy":10,'
          '"Father":-2,"Mother":-3}}}',
        ),
      ),
    );

    await expectLater(
      api.getPeople(key: 'Umićević-2', ancestors: 3, descendants: 2),
      throwsA(isA<PrivateProfileFailure>()),
    );
  });

  test('asks for child ids only when checking for descendants', () async {
    late Uri captured;
    final api = HttpWikiTreeApi(
      client: MockClient((request) async {
        captured = request.url;
        return _json(
          '[{"items":['
          '{"key":"Clemens-1","person":{"Id":5185,"Children":'
          '{"3586":{"Id":3586},"3587":{"Id":3587}}}},'
          '{"key":"Clemens-10","person":{"Id":3586,"Children":[]}}'
          '],"status":0}]',
        );
      }),
    );

    final children = await api.probeChildren(
      keys: <String>['Clemens-1', 'Clemens-10'],
    );

    expect(captured.queryParameters['action'], 'getRelatives');
    expect(captured.queryParameters['keys'], 'Clemens-1,Clemens-10');
    expect(captured.queryParameters['getChildren'], '1');
    expect(captured.queryParameters['getParents'], '0');
    expect(captured.queryParameters['getSiblings'], '0');
    expect(captured.queryParameters['getSpouses'], '0');
    // Ids only: the answer has to stay far smaller than the profile fields.
    expect(captured.queryParameters['fields'], 'Id,Children');
    expect(captured.queryParameters['appId'], 'WikiTreeViewer');

    expect(children['Clemens-1'], <int>[3586, 3587]);
    expect(children['Clemens-10'], isEmpty);
  });

  test('reads child ids given as a bare list', () async {
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => _json(
          '[{"items":[{"key":"Clemens-1",'
          '"person":{"Id":5185,"Children":[3586,3587]}}],"status":0}]',
        ),
      ),
    );

    final children = await api.probeChildren(keys: <String>['Clemens-1']);

    expect(children['Clemens-1'], <int>[3586, 3587]);
  });

  test('reports a withheld child list as unknown, not as empty', () async {
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => _json(
          '[{"items":[{"key":"Living-1","person":{"Id":7000}}],"status":0}]',
        ),
      ),
    );

    final children = await api.probeChildren(keys: <String>['Living-1']);

    // WikiTree leaves `Children` out entirely for a private profile, which is
    // not the same answer as an empty list.
    expect(children.containsKey('Living-1'), isTrue);
    expect(children['Living-1'], isNull);
  });

  test('asks nobody when given no keys', () async {
    final api = HttpWikiTreeApi(
      client: MockClient((request) async => throw StateError('no request')),
    );

    expect(await api.probeChildren(keys: const <String>[]), isEmpty);
  });

  test('maps rate limiting', () async {
    final api = HttpWikiTreeApi(
      client: MockClient((request) async => _json('{}', 429)),
    );

    await expectLater(
      api.getPeople(key: 'Clemens-1'),
      throwsA(isA<RateLimitFailure>()),
    );
  });

  test('maps server errors', () async {
    final api = HttpWikiTreeApi(
      client: MockClient((request) async => _json('{}', 503)),
    );

    await expectLater(
      api.getPeople(key: 'Clemens-1'),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('maps connection problems to a retryable network failure', () async {
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => throw http.ClientException('offline'),
      ),
    );

    await expectLater(
      api.getPeople(key: 'Clemens-1'),
      throwsA(
        isA<NetworkFailure>().having(
          (failure) => failure.retryable,
          'retryable',
          isTrue,
        ),
      ),
    );
  });

  test('maps unreadable bodies to a parse failure', () async {
    final api = HttpWikiTreeApi(
      client: MockClient((request) async => _json('not json')),
    );

    await expectLater(
      api.getPeople(key: 'Clemens-1'),
      throwsA(isA<ParseFailure>()),
    );
  });

  test('caches responses for the session', () async {
    var calls = 0;
    final api = HttpWikiTreeApi(
      cache: SessionResponseCache(),
      client: MockClient((request) async {
        calls++;
        return _json(_fixture('get_people.json'));
      }),
    );

    await api.getPeople(key: 'Clemens-1');
    await api.getPeople(key: 'Clemens-1');

    expect(calls, 1);
  });

  test('a refresh throws the session cache away', () async {
    var calls = 0;
    final api = HttpWikiTreeApi(
      cache: SessionResponseCache(),
      client: MockClient((request) async {
        calls++;
        return _json(_fixture('get_people.json'));
      }),
    );

    await api.getPeople(key: 'Clemens-1');
    // This is the whole mechanism behind the refresh button: without it the
    // cached answer would be served for the rest of the session.
    api.invalidate();
    await api.getPeople(key: 'Clemens-1');

    expect(calls, 2);
  });

  test('parses spouses, marriage details and hidden marriages', () async {
    final api = HttpWikiTreeApi(
      client: MockClient(
        (request) async => _json(_fixture('get_relatives.json')),
      ),
    );

    final response = await api.getRelatives(keys: <String>['Clemens-1']);

    expect(response.groups, hasLength(1));
    final group = response.groups.first;
    expect(group.person.wikiTreeId, 'Clemens-1');
    expect(group.siblings.map((person) => person.wikiTreeId), <String>[
      'Clemens-3',
      'Clemens-5',
    ]);
    expect(group.spouses, hasLength(3));

    final olivia = group.spouses.firstWhere(
      (link) => link.person.wikiTreeId == 'Langdon-1',
    );
    expect(olivia.person.id, 5256);
    expect(olivia.marriageYear, 1870);
    expect(olivia.marriageEnded, isFalse);
    expect(olivia.visible, isTrue);

    final hidden = group.spouses.firstWhere(
      (link) => link.person.wikiTreeId == 'Hidden-2',
    );
    expect(hidden.visible, isFalse);
  });

  test('requests relatives with the plural keys parameter', () async {
    late Uri captured;
    final api = HttpWikiTreeApi(
      client: MockClient((request) async {
        captured = request.url;
        return _json(_fixture('get_relatives.json'));
      }),
    );

    await api.getRelatives(keys: <String>['Clemens-1', 'Langdon-1']);

    expect(captured.queryParameters['action'], 'getRelatives');
    expect(captured.queryParameters['keys'], 'Clemens-1,Langdon-1');
    expect(captured.queryParameters['getSiblings'], '1');
    expect(captured.queryParameters['getSpouses'], '1');
    // `Father` and `Mother` are only ids; the relatives themselves arrive in
    // `Parents`, which WikiTree leaves out unless it is asked for.
    expect(captured.queryParameters['getParents'], '1');
  });
}
