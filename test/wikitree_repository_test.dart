import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/core/failures.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/data/wikitree_api.dart';
import 'package:wikitree_viewer/data/wikitree_repository.dart';

class _FakeApi implements WikiTreeApi {
  _FakeApi(this.people);

  final Map<String, PeopleResponse> people;

  /// What a request for one profile on its own answers, when that differs from
  /// the family cone in [people]. WikiTree leaves a private person out of their
  /// own cone, so the app has to ask for them separately.
  Map<String, PeopleResponse> solo = const <String, PeopleResponse>{};
  final List<String> requestedKeys = <String>[];
  RelativesResponse relatives = const RelativesResponse(
    groups: <RelativeGroup>[],
  );
  WikiTreeFailure? relativesFailure;
  Map<String, List<int>?> childIds = const <String, List<int>?>{};
  final List<List<String>> probedKeys = <List<String>>[];

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    requestedKeys.add(key);
    final plain = ancestors == 0 && descendants == 0;
    final response = (plain ? solo[key] : null) ?? people[key];
    if (response == null) throw const NotFoundFailure();
    return response;
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async {
    final failure = relativesFailure;
    if (failure != null) throw failure;
    return relatives;
  }

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async {
    probedKeys.add(keys);
    return childIds;
  }

  @override
  void close() {}
}

const Person _samuel = Person(
  id: 5185,
  wikiTreeId: 'Clemens-1',
  firstName: 'Samuel',
  middleName: 'Langhorne',
  lastNameAtBirth: 'Clemens',
  birthDate: '1835-11-30',
  deathDate: '1910-04-21',
  fatherId: 5186,
  motherId: 5188,
  privacyIsAtLeastPublic: true,
);

const Person _father = Person(
  id: 5186,
  wikiTreeId: 'Clemens-2',
  firstName: 'John',
  lastNameAtBirth: 'Clemens',
  birthDate: '1798-08-11',
);

const Person _mother = Person(
  id: 5188,
  wikiTreeId: 'Lampton-1',
  firstName: 'Jane',
  lastNameAtBirth: 'Lampton',
  birthDate: '1803-06-18',
);

const Person _sibling = Person(
  id: 5191,
  wikiTreeId: 'Clemens-3',
  firstName: 'Orion',
  lastNameAtBirth: 'Clemens',
  birthDate: '1825-10-06',
  fatherId: 5186,
  motherId: 5188,
);

const Person _child = Person(
  id: 3586,
  wikiTreeId: 'Clemens-10',
  firstName: 'Samuel',
  lastNameAtBirth: 'Clemens',
  birthDate: '1873-00-00',
  fatherId: 5185,
  motherId: 5256,
);

final PeopleResponse _clemens = PeopleResponse(
  people: const <Person>[_samuel, _father, _mother, _child],
  resolvedId: 5185,
);

const Person _livingParent = Person(
  id: 7000,
  wikiTreeId: 'Living-1',
  firstName: 'Robin',
  lastNameAtBirth: 'Reader',
  isLiving: true,
  privacy: 40,
  privacyIsPrivate: true,
);

const Person _livingChild = Person(
  id: 7001,
  wikiTreeId: 'Living-2',
  firstName: 'Sam',
  lastNameAtBirth: 'Reader',
  isLiving: true,
  privacy: 40,
  privacyIsPrivate: true,
  fatherId: 7000,
);

void main() {
  test('retries with a capitalised surname', () async {
    final api = _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens});
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('clemens-1');

    expect(api.requestedKeys, <String>['clemens-1', 'Clemens-1']);
    expect(bundle.focus.wikiTreeId, 'Clemens-1');
    expect(bundle.focus.displayName, 'Samuel Clemens');
  });

  test('follows the resolved id for merged profiles', () async {
    final api = _FakeApi(<String, PeopleResponse>{
      'Old-1': PeopleResponse(
        people: const <Person>[_father, _samuel],
        resolvedId: 5185,
      ),
    });
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('Old-1');

    expect(bundle.focus.id, 5185);
    expect(bundle.focus.displayName, 'Samuel Clemens');
  });

  test('centres on the person the cone left out', () async {
    // Reported with Umićević-3. Private children make WikiTree mask the
    // requested profile too, so `resultByKey` names an id that is not in
    // `people`, the key is not there either, and the first person left is a
    // grandchild - which is who the tree used to open.
    final api =
        _FakeApi(<String, PeopleResponse>{
            'Clemens-1': PeopleResponse(
              people: const <Person>[_child, _sibling],
              resolvedId: 5185,
            ),
          })
          ..solo = <String, PeopleResponse>{
            'Clemens-1': PeopleResponse(
              people: const <Person>[_samuel],
              resolvedId: 5185,
            ),
          };
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('Clemens-1');

    expect(bundle.focus.id, 5185);
    expect(bundle.focus.wikiTreeId, 'Clemens-1');
    // Asking for the profile again must not throw away the family the cone
    // already brought in.
    expect(bundle.children.map((person) => person.id), <int>[3586]);
    expect(api.requestedKeys, <String>['Clemens-1', 'Clemens-1']);
  });

  test('opens a profile whose whole family is private', () async {
    // Every relative masked means the cone holds no usable person at all. The
    // profile still exists and must open instead of being called not found.
    final api =
        _FakeApi(<String, PeopleResponse>{
            'Living-1': const PeopleResponse(
              people: <Person>[],
              resolvedId: 7000,
            ),
          })
          ..solo = <String, PeopleResponse>{
            'Living-1': const PeopleResponse(
              people: <Person>[_livingParent],
              resolvedId: 7000,
            ),
          };
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('Living-1');

    expect(bundle.focus.id, 7000);
    expect(bundle.parents, isEmpty);
  });

  test('merges siblings, spouses and parents into the graph', () async {
    final api = _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens})
      ..relatives = RelativesResponse(
        groups: <RelativeGroup>[
          RelativeGroup(
            person: _samuel,
            siblings: const <Person>[_sibling],
            parents: const <Person>[_father, _mother],
            children: const <Person>[_child],
            spouses: <SpouseLink>[
              SpouseLink(
                person: const Person(
                  id: 5256,
                  wikiTreeId: 'Langdon-1',
                  firstName: 'Olivia',
                  lastNameAtBirth: 'Langdon',
                ),
                marriageDate: '1870-02-02',
                marriageEndDate: '0000-00-00',
              ),
            ],
          ),
        ],
      );
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('Clemens-1');

    expect(bundle.parents.map((person) => person.id), <int>[5186, 5188]);
    expect(bundle.children.map((person) => person.id), <int>[3586]);
    expect(bundle.siblings.map((person) => person.id), <int>[5191]);
    expect(bundle.spouses, hasLength(1));
    expect(bundle.spouses.first.person.displayName, 'Olivia Langdon');
    expect(bundle.spouses.first.marriageYear, 1870);
  });

  test('still returns a tree when relatives cannot be loaded', () async {
    final api = _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens})
      ..relativesFailure = const NetworkFailure();
    final repository = WikiTreeRepository(api: api);

    final bundle = await repository.loadFocus('Clemens-1');

    expect(bundle.focus.id, 5185);
    expect(bundle.siblings, isEmpty);
  });

  test('reports an unknown person as not found', () async {
    final repository = WikiTreeRepository(
      api: _FakeApi(<String, PeopleResponse>{}),
    );

    await expectLater(
      repository.loadFocus('Nobody-1'),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('counts only children the tree has not loaded yet', () async {
    final api = _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens})
      ..childIds = <String, List<int>?>{
        'Clemens-1': <int>[3586, 4242, 4243],
      };
    final repository = WikiTreeRepository(api: api);
    final bundle = await repository.loadFocus('Clemens-1');

    final hidden = await repository.hiddenChildCount(<Person>[
      bundle.focus,
    ], shown: bundle.graph.people.map((person) => person.id).toSet());

    expect(api.probedKeys.single, <String>['Clemens-1']);
    // 3586 is already drawn; 4242 and 4243 are below the loaded tree.
    expect(hidden, 2);
  });

  test('asks nobody about an empty row', () async {
    final api = _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens});
    final repository = WikiTreeRepository(api: api);

    expect(
      await repository.hiddenChildCount(const <Person>[], shown: const <int>{}),
      0,
    );
    expect(api.probedKeys, isEmpty);
  });

  test('asks one generation down when the children are kept private', () async {
    // A private profile's children are simply absent from the probe - which
    // must not be mistaken for "no children".
    final api = _FakeApi(<String, PeopleResponse>{
      'Living-1': PeopleResponse(
        people: const <Person>[_livingParent, _livingChild],
        resolvedId: 7000,
      ),
    })..childIds = <String, List<int>?>{'Living-1': null};
    final repository = WikiTreeRepository(api: api);

    final count = await repository.hiddenChildCount(
      const <Person>[_livingParent],
      shown: const <int>{7000},
    );

    expect(api.probedKeys.single, <String>['Living-1']);
    expect(api.requestedKeys.last, 'Living-1');
    // The parent comes back in that answer too and must not be counted.
    expect(count, 1);
  });

  test('says nobody when the generation below really is empty', () async {
    final api = _FakeApi(<String, PeopleResponse>{
      'Living-1': PeopleResponse(
        people: const <Person>[_livingParent],
        resolvedId: 7000,
      ),
    })..childIds = <String, List<int>?>{'Living-1': null};
    final repository = WikiTreeRepository(api: api);

    final count = await repository.hiddenChildCount(
      const <Person>[_livingParent],
      shown: const <int>{7000},
    );

    expect(count, 0);
  });

  test('clear drops everything held in memory', () async {
    final repository = WikiTreeRepository(
      api: _FakeApi(<String, PeopleResponse>{'Clemens-1': _clemens}),
    );

    await repository.loadFocus('Clemens-1');
    expect(repository.graph.length, greaterThan(0));

    repository.clear();
    expect(repository.graph.length, 0);
  });
}
