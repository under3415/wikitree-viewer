import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/data/family_graph.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/ui/format/person_text.dart';

import 'helpers/localizations.dart';

Map<String, dynamic> _fixture(String name) {
  final decoded = jsonDecode(
    File('test/fixtures/$name').readAsStringSync(),
  ) as List<dynamic>;
  return decoded.first as Map<String, dynamic>;
}

FamilyGraph _buildGraph() {
  final graph = FamilyGraph();

  final people = _fixture('get_people.json')['people'] as Map<String, dynamic>;
  for (final entry in people.values) {
    final person = Person.tryFromJson(entry);
    if (person != null) graph.add(person);
  }

  final items = _fixture('get_relatives.json')['items'] as List<dynamic>;
  final personMap =
      (items.first as Map<String, dynamic>)['person'] as Map<String, dynamic>;

  final siblings = personMap['Siblings'] as Map<String, dynamic>;
  for (final entry in siblings.values) {
    final person = Person.tryFromJson(entry);
    if (person != null) graph.add(person);
  }

  final spouses = personMap['Spouses'] as Map<String, dynamic>;
  final links = <SpouseLink>[];
  for (final entry in spouses.values) {
    final link = SpouseLink.tryFromJson(entry);
    if (link != null) links.add(link);
  }
  graph.addSpouses(5185, links);

  return graph;
}

void main() {
  late PersonText text;

  setUpAll(() async => text = englishText(await loadEnglish()));

  late FamilyGraph graph;

  setUp(() => graph = _buildGraph());

  test('looks people up by id and by WikiTree ID, ignoring case', () {
    expect(graph.byId(5185)!.wikiTreeId, 'Clemens-1');
    expect(graph.byWikiTreeId('clemens-1')!.id, 5185);
    expect(graph.byWikiTreeId('CLEMENS-1')!.id, 5185);
    expect(graph.byWikiTreeId('nobody-1'), isNull);
    expect(graph.byId(null), isNull);
  });

  test('finds parents and children', () {
    final samuel = graph.byId(5185)!;
    expect(graph.parentsOf(samuel).map((person) => person.id), <int>[
      5186,
      5188,
    ]);
    expect(graph.childrenOf(samuel).map((person) => person.id), <int>[3586]);
  });

  test('children are ordered by birth year', () {
    final john = graph.byId(5186)!;
    expect(graph.childrenOf(john).map((person) => person.id), <int>[
      5191,
      5194,
      5185,
    ]);
  });

  test('distinguishes full and half siblings', () {
    final samuel = graph.byId(5185)!;
    expect(graph.fullSiblingsOf(samuel).map((person) => person.id), <int>[
      5191,
      5194,
    ]);
    expect(graph.halfSiblingsOf(samuel), isEmpty);

    graph.add(
      const Person(
        id: 7000,
        wikiTreeId: 'Test-1',
        fatherId: 5186,
        motherId: 1234,
        firstName: 'Half',
        lastNameAtBirth: 'Test',
        birthDate: '1830-01-01',
      ),
    );

    final halfSiblings = graph.halfSiblingsOf(samuel);
    expect(halfSiblings.map((person) => person.id), <int>[7000]);
    expect(graph.fullSiblingsOf(samuel).map((person) => person.id), <int>[
      5191,
      5194,
    ]);
  });

  test('has no siblings when parents are unknown', () {
    final jane = graph.byId(5188)!;
    expect(graph.fullSiblingsOf(jane), isEmpty);
    expect(graph.halfSiblingsOf(jane), isEmpty);
  });

  test('hides marriages flagged do_not_display and sorts by date', () {
    final spouses = graph.visibleSpousesOf(5185);
    expect(spouses.map((link) => link.person.wikiTreeId), <String>[
      'Langdon-1',
      'Jones-100',
    ]);
    expect(spouses.first.marriageEnded, isFalse);
    expect(spouses.last.marriageEnded, isTrue);
    expect(text.marriageDescription(spouses.first), 'm. 2 Feb 1870');
  });

  test('adds spouses as people, so they can be looked up', () {
    expect(graph.byWikiTreeId('Langdon-1'), isNotNull);
    expect(graph.length, greaterThanOrEqualTo(10));
  });

  group('partners', () {
    test('are recognised by a child two people share', () {
      // Nobody ever asked WikiTree about John, so there is no `Spouses` entry
      // for him - only the children he shares with Jane.
      final john = graph.byId(5186)!;
      expect(graph.visibleSpousesOf(john.id), isEmpty);

      final partners = graph.partnersOf(john.id);
      expect(partners.map((link) => link.person.wikiTreeId), <String>[
        'Lampton-1',
      ]);
      expect(
        partners.where((link) => link.person.id == 5188),
        hasLength(1),
        reason: 'three children, one couple',
      );
      expect(partners.first.marriageDate, isNull);
    });

    test('keep the marriage details WikiTree sent', () {
      final partners = graph.partnersOf(5185);
      expect(partners.first.person.wikiTreeId, 'Langdon-1');
      expect(partners.first.marriageYear, 1870);
      expect(partners.first.marriageEnded, isFalse);
      expect(partners.last.person.wikiTreeId, 'Jones-100');
      expect(partners.last.marriageEnded, isTrue);
    });

    test('never resurrect a marriage the couple hid', () {
      final jane = graph.byId(5188)!;
      graph.addSpouses(5186, <SpouseLink>[
        SpouseLink(person: jane, doNotDisplay: true),
      ]);

      final partners = graph.partnersOf(5186);
      expect(partners.map((link) => link.person.id), isNot(contains(5188)));
      expect(graph.visibleSpousesOf(5186), isEmpty);
    });

    test('ignore a partner who is not in the graph', () {
      graph.add(
        const Person(
          id: 7100,
          wikiTreeId: 'Test-2',
          firstName: 'Only',
          lastNameAtBirth: 'Child',
          fatherId: 7000,
          motherId: 99999,
        ),
      );

      expect(
        graph.partnersOf(7000).map((link) => link.person.id),
        isNot(contains(99999)),
      );
    });
  });

  test('merging a slim record does not lose details', () {
    graph.add(const Person(id: 5185, wikiTreeId: 'Clemens-1', privacy: 60));
    final samuel = graph.byId(5185)!;
    expect(samuel.firstName, 'Samuel');
    expect(samuel.birthDate, '1835-11-30');
  });

  group('a link only the parent knows', () {
    // WikiTree answers `Father: -3` for a child of a semi-private parent, even
    // when the app is looking at that parent, so the son arrives with no father.
    const father = Person(
      id: 9001,
      wikiTreeId: 'Nakarada-1',
      firstName: 'Radivoje',
      lastNameAtBirth: 'Nakarada',
    );
    const son = Person(
      id: 9002,
      wikiTreeId: 'Nakarada-Kordic-1',
      firstName: 'Dejan',
      lastNameAtBirth: 'Nakarada-Kordic',
    );

    test('hangs the child where WikiTree said they hang', () {
      final linkGraph = FamilyGraph()..addAll(<Person>[father, son]);
      expect(linkGraph.childrenOf(father), isEmpty);

      final revision = linkGraph.linkRevision;
      linkGraph.recordChild(parentId: father.id, childId: son.id);

      expect(linkGraph.childrenOf(father).map((person) => person.id), <int>[
        son.id,
      ]);
      expect(linkGraph.parentsOf(son).map((person) => person.id), <int>[
        father.id,
      ]);
      // Somebody already in memory can now be drawn, which is what the tree
      // watches for to lay itself out again.
      expect(linkGraph.linkRevision, revision + 1);

      // The same link twice is the same link.
      linkGraph.recordChild(parentId: father.id, childId: son.id);
      expect(linkGraph.linkRevision, revision + 1);
      expect(linkGraph.childrenOf(father), hasLength(1));
    });

    test('waits for a child who has not been fetched yet', () {
      final linkGraph = FamilyGraph()..add(father);
      final revision = linkGraph.linkRevision;
      linkGraph.recordChild(parentId: father.id, childId: son.id);

      // Nothing to draw yet, so nothing to redraw.
      expect(linkGraph.linkRevision, revision);
      expect(linkGraph.childrenOf(father), isEmpty);

      linkGraph.add(son);
      expect(linkGraph.childrenOf(father).map((person) => person.id), <int>[
        son.id,
      ]);
    });

    test('finds the other half of the union through the recorded link', () {
      // The mother is named by the son, the father only by his own Children list;
      // together they are the couple the son descends from.
      const mother = Person(
        id: 9003,
        wikiTreeId: 'Kordic-10',
        firstName: 'Branka',
        lastNameAtBirth: 'Kordic',
      );
      const sonOfBoth = Person(
        id: 9004,
        wikiTreeId: 'Nakarada-Kordic-1',
        firstName: 'Dejan',
        lastNameAtBirth: 'Nakarada-Kordic',
        motherId: 9003,
      );
      final linkGraph = FamilyGraph()
        ..addAll(<Person>[father, mother, sonOfBoth]);
      linkGraph.recordChild(parentId: father.id, childId: sonOfBoth.id);

      expect(
        linkGraph.partnersOf(father.id).map((link) => link.person.id),
        <int>[mother.id],
      );
      expect(
        linkGraph.partnersOf(mother.id).map((link) => link.person.id),
        <int>[father.id],
      );
    });

    test('ignores a link to nobody', () {
      final linkGraph = FamilyGraph()..add(father);
      linkGraph.recordChild(parentId: father.id, childId: father.id);
      linkGraph.recordChild(parentId: 0, childId: son.id);
      linkGraph.recordChild(parentId: father.id, childId: -3);
      expect(linkGraph.childrenOf(father), isEmpty);
    });
  });
}
