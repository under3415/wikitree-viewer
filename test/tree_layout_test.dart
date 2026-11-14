import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/data/family_graph.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/data/wikitree_repository.dart';
import 'package:wikitree_viewer/ui/tree/tree_layout.dart';
import 'package:wikitree_viewer/ui/tree/tree_metrics.dart';

Person _person(
  int id, {
  int? father,
  int? mother,
  String? birth,
  String? death,
  bool limited = false,
}) {
  return Person(
    id: id,
    wikiTreeId: 'Test-$id',
    firstName: limited ? null : 'First$id',
    lastNameAtBirth: limited ? null : 'Test',
    birthDate: birth,
    deathDate: death,
    fatherId: father,
    motherId: mother,
  );
}

/// A four-generation family:
///
///       4     5      (grandparents)
///        \   /
///       2     3      (parents)
///        \   / \
///   8     1  -  9    (sibling, focus, spouse)
///   |     | \    10  (former spouse of the focus)
///    \    6
///          \
///           7
FamilyGraph _familyGraph({bool withHiddenSpouse = false}) {
  final graph = FamilyGraph()
    ..addAll(<Person>[
      _person(1, father: 2, mother: 3, birth: '1950-01-01'),
      _person(2, father: 4, mother: 5, birth: '1920-01-01'),
      _person(3, birth: '1922-01-01'),
      _person(4, birth: '1890-01-01'),
      _person(5, birth: '1892-01-01'),
      _person(6, father: 1, mother: 9, birth: '1975-01-01'),
      _person(7, father: 6, birth: '2000-01-01'),
      _person(8, father: 2, mother: 3, birth: '1948-01-01'),
      _person(9, birth: '1952-01-01'),
      _person(10, birth: '1955-01-01'),
      _person(11, birth: '1958-01-01'),
    ]);

  graph.addSpouses(1, <SpouseLink>[
    SpouseLink(person: graph.byId(9)!, marriageDate: '1974-06-01'),
    SpouseLink(
      person: graph.byId(10)!,
      marriageDate: '1990-06-01',
      marriageEndDate: '1995-06-01',
    ),
    if (withHiddenSpouse)
      SpouseLink(
        person: graph.byId(11)!,
        marriageDate: '1980-01-01',
        doNotDisplay: true,
      ),
  ]);
  return graph;
}

FocusBundle _bundle({
  bool withHiddenSpouse = false,
  int ancestors = 2,
  int descendants = 2,
}) {
  final graph = _familyGraph(withHiddenSpouse: withHiddenSpouse);
  return FocusBundle(
    focus: graph.byId(1)!,
    graph: graph,
    ancestorDepth: ancestors,
    descendantDepth: descendants,
  );
}

void main() {
  const builder = TreeLayoutBuilder();

  test('assigns one generation per person around the focus', () {
    final layout = builder.build(_bundle());

    expect(layout.nodeFor(1)!.generation, 0);
    expect(layout.nodeFor(1)!.isFocus, isTrue);
    expect(layout.nodeFor(2)!.generation, 1);
    expect(layout.nodeFor(3)!.generation, 1);
    expect(layout.nodeFor(4)!.generation, 2);
    expect(layout.nodeFor(5)!.generation, 2);
    expect(layout.nodeFor(8)!.generation, 0);
    expect(layout.nodeFor(9)!.generation, 0);
    expect(layout.nodeFor(10)!.generation, 0);
    expect(layout.nodeFor(6)!.generation, -1);
    expect(layout.nodeFor(7)!.generation, -2);
    expect(layout.maxGeneration, 2);
    expect(layout.minGeneration, -2);
  });

  test('puts ancestors above and descendants below the focus', () {
    final layout = builder.build(_bundle());
    final focus = layout.focusNode.rect;

    for (final id in <int>[2, 3, 4, 5]) {
      expect(
        layout.nodeFor(id)!.rect.bottom,
        lessThan(focus.top),
        reason: 'ancestor $id should sit above the focus',
      );
    }
    for (final id in <int>[6, 7]) {
      expect(
        layout.nodeFor(id)!.rect.top,
        greaterThan(focus.bottom),
        reason: 'descendant $id should sit below the focus',
      );
    }
  });

  test('never overlaps two boxes in the same row', () {
    final layout = builder.build(_bundle());
    final rows = <int, List<TreeNodeLayout>>{};
    for (final node in layout.nodes) {
      rows.putIfAbsent(node.generation, () => <TreeNodeLayout>[]).add(node);
    }

    for (final row in rows.values) {
      for (var i = 0; i < row.length; i++) {
        for (var j = i + 1; j < row.length; j++) {
          expect(
            row[i].rect.overlaps(row[j].rect),
            isFalse,
            reason: 'boxes ${row[i].person.id} and ${row[j].person.id} overlap',
          );
        }
      }
    }
  });

  test('keeps every row in one piece, with nobody stranded at the margin', () {
    final layout = builder.build(_bundle());
    final rows = <int, List<TreeNodeLayout>>{};
    for (final node in layout.nodes) {
      rows.putIfAbsent(node.generation, () => <TreeNodeLayout>[]).add(node);
    }

    final gap = const TreeMetrics().horizontalGap;
    for (final row in rows.values) {
      row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
      for (var i = 1; i < row.length; i++) {
        expect(
          row[i].rect.left - row[i - 1].rect.right,
          closeTo(gap, 0.001),
          reason:
              '${row[i - 1].person.id} and ${row[i].person.id} should be '
              'neighbours: a row that tears leaves somebody alone at the margin',
        );
      }
    }
  });

  test('links every displayed parent to their child', () {
    final layout = builder.build(_bundle());

    bool hasParentEdge(int from, int to) => layout.edges.any(
      (edge) =>
          edge.kind == TreeEdgeKind.parentChild &&
          edge.fromId == from &&
          edge.toId == to,
    );

    expect(hasParentEdge(2, 1), isTrue);
    expect(hasParentEdge(3, 1), isTrue);
    expect(hasParentEdge(4, 2), isTrue);
    expect(hasParentEdge(5, 2), isTrue);
    expect(hasParentEdge(2, 8), isTrue);
    expect(hasParentEdge(1, 6), isTrue);
    expect(hasParentEdge(9, 6), isTrue);
    expect(hasParentEdge(6, 7), isTrue);
    expect(
      layout.edges.where((edge) => edge.kind == TreeEdgeKind.parentChild),
      hasLength(9),
    );
  });

  test('joins couples and marks marriages that ended', () {
    final layout = builder.build(_bundle());
    final bars = layout.edges
        .where((edge) => edge.kind != TreeEdgeKind.parentChild)
        .toList();

    // The focus with both spouses, and the two ancestor couples, for whom
    // WikiTree never sent a marriage at all.
    expect(bars, hasLength(4));
    expect(
      bars.where((edge) => edge.kind == TreeEdgeKind.marriage),
      hasLength(3),
    );
    expect(
      bars.where((edge) => edge.kind == TreeEdgeKind.endedMarriage),
      hasLength(1),
    );
  });

  test('draws the couple line above the focus without marriage records', () {
    final layout = builder.build(_bundle());

    bool hasBar(int a, int b) => layout.edges.any(
      (edge) =>
          edge.kind != TreeEdgeKind.parentChild &&
          ((edge.fromId == a && edge.toId == b) ||
              (edge.fromId == b && edge.toId == a)),
    );

    // Nobody asked WikiTree about 2, 3, 4 or 5, so the only thing that says they
    // are couples is the child each pair shares.
    expect(hasBar(2, 3), isTrue, reason: 'parents of the focus');
    expect(hasBar(4, 5), isTrue, reason: 'parents of the father');
    expect(
      hasBar(1, 9),
      isTrue,
      reason: 'the focus and the spouse WikiTree did send',
    );
  });

  test('never joins siblings', () {
    final layout = builder.build(_bundle());

    bool joinable(int id) => layout.edges.any(
      (edge) =>
          edge.kind != TreeEdgeKind.parentChild &&
          (edge.fromId == id || edge.toId == id),
    );

    expect(joinable(8), isFalse, reason: 'the sibling is not part of a couple');
    // Siblings hang from the same parents, which is how the chart says they
    // belong together; a line of their own would read as a marriage.
    expect(
      layout.edges.where(
        (edge) => edge.kind == TreeEdgeKind.parentChild && edge.toId == 8,
      ),
      hasLength(2),
    );
  });

  test('hides marriages flagged do_not_display', () {
    final layout = builder.build(_bundle(withHiddenSpouse: true));

    expect(layout.nodeFor(11), isNull);
    expect(
      layout.edges.where((edge) => edge.kind != TreeEdgeKind.parentChild),
      hasLength(4),
    );
  });

  test('respects the requested depth', () {
    final layout = builder.build(_bundle(ancestors: 1, descendants: 1));

    expect(layout.nodeFor(2), isNotNull);
    expect(layout.nodeFor(4), isNull);
    expect(layout.nodeFor(5), isNull);
    expect(layout.nodeFor(6), isNotNull);
    expect(layout.nodeFor(7), isNull);
    expect(layout.maxGeneration, 1);
    expect(layout.minGeneration, -1);
  });

  test('produces identical geometry every time', () {
    final first = builder.build(_bundle());
    final second = builder.build(_bundle());

    expect(first.size, second.size);
    expect(first.nodes, hasLength(second.nodes.length));
    for (var i = 0; i < first.nodes.length; i++) {
      expect(first.nodes[i].person.id, second.nodes[i].person.id);
      expect(first.nodes[i].rect, second.nodes[i].rect);
    }
    expect(first.edges.length, second.edges.length);
  });

  test('sizes the canvas around every box', () {
    final layout = builder.build(_bundle());
    const epsilon = Offset(0.01, 0.01);

    for (final node in layout.nodes) {
      expect(layout.contentBounds.contains(node.rect.topLeft), isTrue);
      expect(
        layout.contentBounds.contains(node.rect.bottomRight - epsilon),
        isTrue,
      );
    }
  });

  test('lays a single person in a padded canvas', () {
    final graph = FamilyGraph()..add(_person(1));
    final layout = builder.build(
      FocusBundle(
        focus: graph.byId(1)!,
        graph: graph,
        ancestorDepth: 2,
        descendantDepth: 2,
      ),
    );

    expect(layout.nodes, hasLength(1));
    expect(layout.edges, isEmpty);
    expect(layout.focusRect.width, 208);
    expect(layout.focusRect.left, 40);
    expect(layout.size.width, closeTo(288, 0.001));
    expect(layout.size.height, closeTo(172, 0.001));
  });

  test('reserves a photo slot and gives the rest of the box to the name', () {
    final layout = builder.build(_bundle());
    final focus = layout.focusNode;

    expect(focus.avatarRect.width, 44);
    expect(focus.avatarRect.height, 44);
    expect(focus.rect.left, closeTo(focus.avatarRect.left - 10, 0.001));
    expect(focus.labelRect.left, closeTo(focus.avatarRect.right + 8, 0.001));
    expect(focus.labelRect.right, lessThanOrEqualTo(focus.rect.right));
    expect(focus.labelRect.width, greaterThan(focus.avatarRect.width));

    // The photo sits inside the box, vertically centred.
    expect(focus.rect.contains(focus.avatarRect.center), isTrue);
    expect(focus.avatarRect.center.dy, closeTo(focus.rect.center.dy, 0.001));
  });

  test('says whether there is more family above', () {
    // The sample tree already reaches its oldest recorded parents.
    final complete = builder.build(_bundle());
    expect(complete.hasMoreAncestors, isFalse);
    expect(complete.hiddenAncestorCount, 0);

    // Stopping one generation lower leaves both of Hermann's... of person 2's
    // parents out of the tree, and person 3 has none recorded.
    final shallow = builder.build(_bundle(ancestors: 1));
    expect(shallow.maxGeneration, 1);
    expect(shallow.hasMoreAncestors, isTrue);
    expect(shallow.hiddenAncestorCount, 2);
  });

  test('grows boxes with the text scale, up to a limit', () {
    final normal = TreeMetrics.forTextScale(1);
    final large = TreeMetrics.forTextScale(1.5);

    expect(large.focusWidth, greaterThan(normal.focusWidth));
    expect(large.nodeHeight, greaterThan(normal.nodeHeight));
    expect(
      TreeMetrics.forTextScale(9).focusWidth,
      TreeMetrics.forTextScale(1.6).focusWidth,
    );
  });

  test('shows a shared ancestor once when both parents descend from them', () {
    final graph = FamilyGraph()
      ..addAll(<Person>[
        _person(1, father: 2, mother: 3),
        _person(2, father: 4),
        _person(3, father: 4),
        _person(4),
      ]);
    final layout = builder.build(
      FocusBundle(
        focus: graph.byId(1)!,
        graph: graph,
        ancestorDepth: 3,
        descendantDepth: 0,
      ),
    );

    expect(layout.nodes.where((node) => node.person.id == 4), hasLength(1));
    expect(layout.nodeFor(4)!.generation, 2);
    expect(layout.edges.where((edge) => edge.fromId == 4), hasLength(2));
  });

  test('marks limited profiles without inventing details', () {
    final graph = FamilyGraph()
      ..addAll(<Person>[
        _person(1, father: 2),
        _person(2, limited: true, birth: '1930-00-00'),
      ]);
    final layout = builder.build(
      FocusBundle(
        focus: graph.byId(1)!,
        graph: graph,
        ancestorDepth: 1,
        descendantDepth: 0,
      ),
    );

    expect(layout.nodeFor(2)!.hasDetails, isFalse);
    expect(layout.focusNode.hasDetails, isTrue);
  });

  test('puts couples side by side so their bar stays short', () {
    final layout = builder.build(_bundle());
    final row =
        layout.nodes
            .where((node) => node.generation == 0)
            .toList(growable: false)
          ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
    final order = row.map((node) => node.person.id).toList(growable: false);

    // 1 is the focus, 9 and 10 are the wife and the former wife.
    expect((order.indexOf(1) - order.indexOf(9)).abs(), 1);
    expect((order.indexOf(1) - order.indexOf(10)).abs(), 1);

    for (final edge in layout.edges.where(
      (edge) => edge.kind != TreeEdgeKind.parentChild,
    )) {
      expect(
        edge.points,
        hasLength(2),
        reason: 'a couple standing together needs no detour',
      );
    }
  });

  test('routes a bar around anybody standing between a couple', () {
    // Three wives: only two of them can stand beside their husband.
    final graph = FamilyGraph()
      ..addAll(<Person>[_person(1), _person(2), _person(3), _person(4)]);
    graph.addSpouses(1, <SpouseLink>[
      SpouseLink(person: graph.byId(2)!, marriageDate: '1900-01-01'),
      SpouseLink(person: graph.byId(3)!, marriageDate: '1910-01-01'),
      SpouseLink(person: graph.byId(4)!, marriageDate: '1920-01-01'),
    ]);
    final layout = builder.build(
      FocusBundle(
        focus: graph.byId(1)!,
        graph: graph,
        ancestorDepth: 0,
        descendantDepth: 0,
      ),
    );

    final bars = layout.edges
        .where((edge) => edge.kind != TreeEdgeKind.parentChild)
        .toList(growable: false);
    expect(bars, hasLength(3));

    final detours = bars.where((edge) => edge.points.length > 2).toList();
    expect(detours, hasLength(1));

    // The detour drops below the row rather than crossing a box.
    final lowest = detours.single.points
        .map((point) => point.dy)
        .reduce((a, b) => a > b ? a : b);
    expect(lowest, greaterThan(layout.focusRect.bottom));
  });
}
