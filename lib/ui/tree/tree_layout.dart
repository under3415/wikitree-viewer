import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../../data/family_graph.dart';
import '../../data/person.dart';
import '../../data/wikitree_repository.dart';
import 'tree_metrics.dart';

enum TreeEdgeKind {
  parentChild,

  /// A couple line: two partners in the same row, whether the marriage was
  /// recorded or they are simply the parents of the same child.
  marriage,

  /// The same line where the marriage is known to have ended; drawn dashed.
  endedMarriage,
}

/// Where one person sits in the tree.
class TreeNodeLayout {
  const TreeNodeLayout({
    required this.person,
    required this.generation,
    required this.isFocus,
    required this.rect,
    required this.avatarRect,
    required this.labelRect,
  });

  final Person person;

  /// 0 is the focus row, positive is ancestors, negative is descendants.
  final int generation;

  final bool isFocus;
  final Rect rect;

  /// The photo slot inside [rect], and the space left for the name and dates.
  /// Both are computed here so the painter and the photo widget agree.
  final Rect avatarRect;
  final Rect labelRect;

  Offset get center => rect.center;

  /// True when WikiTree shared enough to show a real name and dates.
  bool get hasDetails => !person.isLimited;
}

/// A line between two boxes, as a polyline so the painter only has to stroke a
/// path. Parent-child lines bend at the midpoint between the rows; marriage
/// lines are straight and horizontal.
class TreeEdgeLayout {
  const TreeEdgeLayout({
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.points,
  });

  final int fromId;
  final int toId;
  final TreeEdgeKind kind;
  final List<Offset> points;
}

/// The finished geometry for one tree.
class TreeLayout {
  const TreeLayout({
    required this.size,
    required this.nodes,
    required this.edges,
    required this.minGeneration,
    required this.maxGeneration,
    required this.hiddenAncestorCount,
  });

  final Size size;
  final List<TreeNodeLayout> nodes;
  final List<TreeEdgeLayout> edges;

  /// Lowest and highest generation present, so the viewer knows how far it can
  /// scroll in either direction.
  final int minGeneration;
  final int maxGeneration;

  /// Parents of the top row that WikiTree knows about but this tree has not
  /// loaded. Non-zero means there is more family above; zero means the top row
  /// really is the start of the recorded line.
  final int hiddenAncestorCount;

  bool get hasMoreAncestors => hiddenAncestorCount > 0;

  TreeNodeLayout? nodeFor(int personId) {
    for (final node in nodes) {
      if (node.person.id == personId) return node;
    }
    return null;
  }

  TreeNodeLayout get focusNode => nodes.firstWhere((node) => node.isFocus);

  Rect get focusRect => focusNode.rect;

  /// Boxes are laid out inside the returned size, with the padding included.
  Rect get contentBounds => Offset.zero & size;
}

/// Turns a [FocusBundle] into fixed geometry.
///
/// The algorithm is deliberately small and deterministic:
///   1. assign every displayed person to a generation (focus = 0);
///   2. order each row by the average position of its relatives, so families
///      stay grouped and lines cross less;
///   3. place rows top to bottom, then spread boxes within each row;
///   4. produce parent-child elbows and marriage bars.
class TreeLayoutBuilder {
  const TreeLayoutBuilder({this.metrics = const TreeMetrics()});

  final TreeMetrics metrics;

  TreeLayout build(FocusBundle bundle) {
    final graph = bundle.graph;
    final generations = _assignGenerations(bundle);
    final focusId = bundle.focus.id;

    final rowGenerations = generations.values.toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // ancestors first

    final rows = <int, List<int>>{
      for (final generation in rowGenerations) generation: <int>[],
    };
    generations.forEach((personId, generation) {
      rows[generation]!.add(personId);
    });
    for (final row in rows.values) {
      row.sort((a, b) => _initialCompare(graph.byId(a)!, graph.byId(b)!));
    }

    _orderRows(rows, rowGenerations, graph);

    // Vertical placement: rows keep their order, and generations with nobody in
    // them take no space because they never appear in [rowGenerations].
    final rowTops = <int, double>{};
    var cursorY = metrics.padding;
    for (final generation in rowGenerations) {
      rowTops[generation] = cursorY;
      var rowHeight = 0.0;
      for (final personId in rows[generation]!) {
        rowHeight = math.max(rowHeight, _heightFor(personId, focusId));
      }
      cursorY += rowHeight + metrics.verticalGap;
    }

    final centres = _placeX(rows, rowGenerations, graph, focusId);

    final rects = <int, Rect>{};
    for (final generation in rowGenerations) {
      for (final personId in rows[generation]!) {
        final width = _widthFor(personId, focusId);
        final height = _heightFor(personId, focusId);
        final centre = centres[personId]!;
        rects[personId] = Rect.fromLTWH(
          centre - width / 2,
          rowTops[generation]!,
          width,
          height,
        );
      }
    }

    var minLeft = double.infinity;
    var maxRight = double.negativeInfinity;
    for (final rect in rects.values) {
      minLeft = math.min(minLeft, rect.left);
      maxRight = math.max(maxRight, rect.right);
    }

    // Shift everything right so the leftmost box respects the padding.
    final shiftX = metrics.padding - minLeft;
    final shifted = <TreeNodeLayout>[];
    var maxBottom = 0.0;
    for (final entry in rects.entries) {
      final rect = entry.value.shift(Offset(shiftX, 0));
      final avatar = metrics.avatarRectIn(rect);
      shifted.add(
        TreeNodeLayout(
          person: graph.byId(entry.key)!,
          generation: generations[entry.key]!,
          isFocus: entry.key == focusId,
          rect: rect,
          avatarRect: avatar,
          labelRect: metrics.labelRectFor(rect, avatar),
        ),
      );
      maxBottom = math.max(maxBottom, rect.bottom);
    }
    shifted.sort((a, b) => a.person.id.compareTo(b.person.id));

    final topGeneration = rowGenerations.first;
    return TreeLayout(
      size: Size(
        maxRight - minLeft + metrics.padding * 2,
        maxBottom + metrics.padding,
      ),
      nodes: List<TreeNodeLayout>.unmodifiable(shifted),
      edges: List<TreeEdgeLayout>.unmodifiable(_buildEdges(graph, shifted)),
      minGeneration: rowGenerations.last,
      maxGeneration: topGeneration,
      hiddenAncestorCount: _hiddenAncestors(shifted, topGeneration),
    );
  }

  /// Parents of the top row that are not part of this tree.
  ///
  /// WikiTree always sends `Father`/`Mother` ids, so this is exact: it tells the
  /// view whether to offer "more above" or to say that the line has ended.
  /// Parents can be missing because they were never fetched or because the
  /// depth limit left them out; both mean there is more to show.
  static int _hiddenAncestors(List<TreeNodeLayout> nodes, int topGeneration) {
    final shown = nodes.map((node) => node.person.id).toSet();
    final missing = <int>{};
    for (final node in nodes) {
      if (node.generation != topGeneration) continue;
      for (final id in <int?>[node.person.fatherId, node.person.motherId]) {
        if (id == null || shown.contains(id)) continue;
        missing.add(id);
      }
    }
    return missing.length;
  }

  double _widthFor(int personId, int focusId) =>
      metrics.widthFor(isFocus: personId == focusId);

  double _heightFor(int personId, int focusId) =>
      metrics.heightFor(isFocus: personId == focusId);

  /// Every person appears exactly once, even when the same ancestor is reachable
  /// through both parents (pedigree collapse), because the graph is id-keyed.
  Map<int, int> _assignGenerations(FocusBundle bundle) {
    final graph = bundle.graph;
    final generations = <int, int>{bundle.focus.id: 0};
    final visited = <int>{bundle.focus.id};

    var frontier = <Person>[bundle.focus];
    for (
      var depth = 1;
      depth <= bundle.ancestorDepth && frontier.isNotEmpty;
      depth++
    ) {
      final next = <Person>[];
      for (final person in frontier) {
        for (final parent in graph.parentsOf(person)) {
          if (!visited.add(parent.id)) continue;
          generations[parent.id] = depth;
          next.add(parent);
        }
      }
      frontier = next;
    }

    frontier = <Person>[bundle.focus];
    for (
      var depth = 1;
      depth <= bundle.descendantDepth && frontier.isNotEmpty;
      depth++
    ) {
      final next = <Person>[];
      for (final person in frontier) {
        for (final child in graph.childrenOf(person)) {
          if (!visited.add(child.id)) continue;
          generations[child.id] = -depth;
          next.add(child);
        }
      }
      frontier = next;
    }

    for (final sibling in <Person>[
      ...bundle.siblings,
      ...bundle.halfSiblings,
    ]) {
      if (!visited.add(sibling.id)) continue;
      generations[sibling.id] = 0;
    }

    // Spouses sit beside their partner. Only the focus row gets in-laws: adding
    // every spouse in every generation would widen the tree without adding
    // information the eye can use.
    final focusRow = generations.entries
        .where((entry) => entry.value == 0)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final personId in focusRow) {
      for (final link in graph.visibleSpousesOf(personId)) {
        if (!visited.add(link.person.id)) continue;
        generations[link.person.id] = 0;
      }
    }
    // A partner recognised only through a shared child belongs beside the focus
    // as well, or the bar would have nowhere to go.
    for (final link in graph.partnersOf(bundle.focus.id)) {
      if (!visited.add(link.person.id)) continue;
      generations[link.person.id] = 0;
    }

    return generations;
  }

  static int _initialCompare(Person a, Person b) {
    final left = a.birthYear;
    final right = b.birthYear;
    if (left != null && right != null && left != right) {
      return left.compareTo(right);
    }
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    return a.id.compareTo(b.id);
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Orders each row by the average position of its relatives in the adjacent
  /// row. A few alternating sweeps are enough at this scale, and the sort keeps
  /// the previous order as a tiebreaker, so the result is deterministic.
  void _orderRows(
    Map<int, List<int>> rows,
    List<int> order,
    FamilyGraph graph,
  ) {
    // One row has nothing to reorder, but its couples still belong together.
    if (order.length < 2) return _groupCouples(rows, graph);

    bool reorder(List<int> row, List<int> reference) {
      if (row.length < 2) return false;
      final keys = <int, double>{};
      for (final personId in row) {
        final person = graph.byId(personId);
        if (person == null) continue;
        var total = 0.0;
        var count = 0;
        for (final neighbour in _neighbourIds(graph, person)) {
          final index = reference.indexOf(neighbour);
          if (index < 0) continue;
          total += index;
          count++;
        }
        if (count > 0) keys[personId] = total / count;
      }
      if (keys.isEmpty) return false;

      final originalIndex = <int, int>{
        for (var i = 0; i < row.length; i++) row[i]: i,
      };
      final before = List<int>.of(row);
      row.sort((a, b) {
        final left = keys[a];
        final right = keys[b];
        if (left != null && right != null && left != right) {
          return left.compareTo(right);
        }
        if (left != null && right == null) return -1;
        if (left == null && right != null) return 1;
        return originalIndex[a]!.compareTo(originalIndex[b]!);
      });
      return !_sameOrder(before, row);
    }

    // Five passes, so the last one to make a difference orders each row by the row
    // *above* it. That is the order brothers and sisters are defined by: they share
    // those parents, so they keep their birth places. Ending on the pass that looks
    // at the row below instead pushed whoever has children in this tree to the
    // front of their row - which is why the person the tree is about always ended
    // up on the left, with all the brothers and sisters trailing after him.
    for (var pass = 0; pass < 5; pass++) {
      var changed = false;
      if (pass.isEven) {
        for (var i = 1; i < order.length; i++) {
          changed = reorder(rows[order[i]]!, rows[order[i - 1]]!) || changed;
        }
      } else {
        for (var i = order.length - 2; i >= 0; i--) {
          changed = reorder(rows[order[i]]!, rows[order[i + 1]]!) || changed;
        }
      }
      if (!changed) break;
    }

    _groupCouples(rows, graph);
  }

  /// Moves couples next to each other, following marriage order.
  ///
  /// Run last, so the passes above cannot pull a couple apart again. Two
  /// marriages end up on either side of the person, which keeps both bars short
  /// - the case that matters, because a bar between distant boxes has to be
  /// routed around whatever stands between them.
  void _groupCouples(Map<int, List<int>> rows, FamilyGraph graph) {
    for (final row in rows.values) {
      if (row.length < 2) continue;
      _groupRow(row, graph);
    }
  }

  void _groupRow(List<int> row, FamilyGraph graph) {
    final members = row.toSet();
    final placed = <int>{};
    final grouped = <int>[];

    for (final personId in row) {
      if (placed.contains(personId)) continue;
      final spouses = <int>[
        for (final link in graph.partnersOf(personId))
          if (link.person.id != personId &&
              members.contains(link.person.id) &&
              !placed.contains(link.person.id))
            link.person.id,
      ];
      placed.add(personId);
      placed.addAll(spouses);

      if (spouses.length >= 2) {
        grouped
          ..add(spouses.first)
          ..add(personId)
          ..addAll(spouses.skip(1));
      } else {
        grouped
          ..add(personId)
          ..addAll(spouses);
      }
    }

    row
      ..clear()
      ..addAll(grouped);
  }

  /// Places boxes left to right within each row, keeping every row in one piece.
  ///
  /// Each pass asks every box where it would like to be - the median position of
  /// its relatives in the rows above and below - and then lays the whole row out
  /// as a single block centred on the median of those wishes. The block is what
  /// matters: an earlier version moved boxes one at a time, and a box whose
  /// relatives sat far away jumped there and left the boxes before it behind, so a
  /// row could tear into a lonely box at the margin with a marriage line crossing
  /// empty space towards the rest of the family.
  ///
  /// Nobody is placed differently because they are the focus: the focus row is
  /// laid out like every other row, and only the box itself is marked.
  Map<int, double> _placeX(
    Map<int, List<int>> rows,
    List<int> order,
    FamilyGraph graph,
    int focusId,
  ) {
    final centres = <int, double>{};

    for (final generation in order) {
      var cursor = 0.0;
      for (final personId in rows[generation]!) {
        final width = _widthFor(personId, focusId);
        centres[personId] = cursor + width / 2;
        cursor += width + metrics.horizontalGap;
      }
    }

    double desiredFor(int personId) {
      final current = centres[personId]!;
      final person = graph.byId(personId);
      if (person == null) return current;

      final values = <double>[];
      for (final neighbour in _neighbourIds(graph, person)) {
        if (neighbour == personId) continue;
        final centre = centres[neighbour];
        if (centre != null) values.add(centre);
      }
      if (values.isEmpty) return current;
      values.sort();
      return values[values.length ~/ 2];
    }

    for (var pass = 0; pass < 4; pass++) {
      final sequence = pass.isEven
          ? order
          : order.reversed.toList(growable: false);
      for (final generation in sequence) {
        final row = rows[generation]!;

        final wishes = <double>[
          for (final personId in row) desiredFor(personId),
        ]..sort();
        final anchor = wishes[wishes.length ~/ 2];

        var total = -metrics.horizontalGap;
        for (final personId in row) {
          total += _widthFor(personId, focusId) + metrics.horizontalGap;
        }

        var left = anchor - total / 2;
        for (final personId in row) {
          final width = _widthFor(personId, focusId);
          centres[personId] = left + width / 2;
          left += width + metrics.horizontalGap;
        }
      }
    }

    return centres;
  }

  Iterable<int> _neighbourIds(FamilyGraph graph, Person person) sync* {
    for (final parent in graph.parentsOf(person)) {
      yield parent.id;
    }
    for (final child in graph.childrenOf(person)) {
      yield child.id;
    }
    for (final link in graph.partnersOf(person.id)) {
      yield link.person.id;
    }
  }

  /// Parent-child edges bend halfway between the rows; the couple bar joins two
  /// boxes in the same row. A marriage that ended keeps its own kind so the
  /// painter can draw it dashed.
  List<TreeEdgeLayout> _buildEdges(
    FamilyGraph graph,
    List<TreeNodeLayout> nodes,
  ) {
    final byId = <int, TreeNodeLayout>{
      for (final node in nodes) node.person.id: node,
    };
    final edges = <TreeEdgeLayout>[];
    final seen = <String>{};

    for (final node in nodes) {
      for (final parent in graph.parentsOf(node.person)) {
        final parentNode = byId[parent.id];
        if (parentNode == null) continue;
        if (!seen.add('p:${parent.id}>${node.person.id}')) continue;

        final start = Offset(parentNode.rect.center.dx, parentNode.rect.bottom);
        final end = Offset(node.rect.center.dx, node.rect.top);
        final midY = (start.dy + end.dy) / 2;
        edges.add(
          TreeEdgeLayout(
            fromId: parent.id,
            toId: node.person.id,
            kind: TreeEdgeKind.parentChild,
            points: <Offset>[
              start,
              Offset(start.dx, midY),
              Offset(end.dx, midY),
              end,
            ],
          ),
        );
      }
    }

    for (final node in nodes) {
      for (final link in graph.partnersOf(node.person.id)) {
        final spouseNode = byId[link.person.id];
        if (spouseNode == null) continue;
        if (spouseNode.generation != node.generation) continue;

        final lowerId = math.min(node.person.id, spouseNode.person.id);
        final higherId = math.max(node.person.id, spouseNode.person.id);
        if (!seen.add('m:$lowerId-$higherId')) continue;

        final nodeIsLeft = node.rect.center.dx <= spouseNode.rect.center.dx;
        final left = nodeIsLeft ? node : spouseNode;
        final right = nodeIsLeft ? spouseNode : node;
        edges.add(
          TreeEdgeLayout(
            fromId: left.person.id,
            toId: right.person.id,
            kind: link.marriageEnded
                ? TreeEdgeKind.endedMarriage
                : TreeEdgeKind.marriage,
            points: _marriageBar(left, right, nodes),
          ),
        );
      }
    }

    return edges;
  }

  /// The line between two spouses.
  ///
  /// Couples that sit side by side get a short straight bar. When somebody else
  /// stands between them the bar dips below the row first, so it cannot be read
  /// as a marriage to the people it passes behind.
  List<Offset> _marriageBar(
    TreeNodeLayout left,
    TreeNodeLayout right,
    List<TreeNodeLayout> nodes,
  ) {
    final y = left.rect.center.dy;
    final start = Offset(left.rect.right, y);
    final end = Offset(right.rect.left, y);

    final blocked = nodes.any(
      (other) =>
          other.generation == left.generation &&
          other.person.id != left.person.id &&
          other.person.id != right.person.id &&
          other.rect.left < right.rect.left &&
          other.rect.right > left.rect.right,
    );
    if (!blocked) return <Offset>[start, end];

    final dip = math.max(left.rect.bottom, right.rect.bottom) + 16;
    return <Offset>[
      start,
      Offset(start.dx + 10, y),
      Offset(start.dx + 10, dip),
      Offset(end.dx - 10, dip),
      Offset(end.dx - 10, y),
      end,
    ];
  }
}
