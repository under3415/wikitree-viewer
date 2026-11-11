import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/data/family_graph.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/data/wikitree_repository.dart';
import 'package:wikitree_viewer/ui/theme/app_theme.dart';
import 'package:wikitree_viewer/ui/tree/tree_layout.dart';
import 'package:wikitree_viewer/ui/tree/tree_metrics.dart';
import 'package:wikitree_viewer/ui/format/person_text.dart';
import 'package:wikitree_viewer/ui/tree/tree_painter.dart';

import 'helpers/localizations.dart';

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

/// Parents, a child, a wife and an ex-wife, so every edge kind is painted.
FocusBundle _bundle() {
  final graph = FamilyGraph()
    ..addAll(<Person>[
      _person(1, father: 2, mother: 3, birth: '1950-01-01'),
      _person(2, father: 7, birth: '1920-01-01', death: '1990-00-00'),
      _person(3, birth: '1922-01-01'),
      _person(4, father: 1, birth: '1975-01-01'),
      _person(5, birth: '1952-01-01'),
      _person(6, birth: '1970-01-01'),
      _person(7, limited: true),
    ]);
  graph.addSpouses(1, <SpouseLink>[
    SpouseLink(person: graph.byId(5)!, marriageDate: '1974-06-01'),
    SpouseLink(
      person: graph.byId(6)!,
      marriageDate: '1990-06-01',
      marriageEndDate: '1995-06-01',
    ),
  ]);
  return FocusBundle(
    focus: graph.byId(1)!,
    graph: graph,
    ancestorDepth: 2,
    descendantDepth: 1,
  );
}

void main() {
  late PersonText text;

  setUpAll(() async => text = englishText(await loadEnglish()));

  test('the sample tree really does contain every kind of line', () {
    final layout = const TreeLayoutBuilder().build(_bundle());
    final kinds = layout.edges.map((edge) => edge.kind).toSet();

    expect(kinds, containsAll(TreeEdgeKind.values));
  });

  test('paints a whole tree at every text scale', () {
    for (final scale in <double>[1, 1.5, 3]) {
      final layout = TreeLayoutBuilder(metrics: TreeMetrics.forTextScale(scale))
          .build(_bundle());
      final recorder = ui.PictureRecorder();
      final painter = TreePainter(
        layout: layout,
        theme: AppTheme.light(),
        text: text,
        textScaler: TextScaler.linear(scale),
      );

      // Any negative size or bad offset would throw here.
      painter.paint(Canvas(recorder), layout.size);
      recorder.endRecording().dispose();
    }
  });

  test('paints a private profile without asking for a name', () {
    final layout = const TreeLayoutBuilder().build(_bundle());
    final recorder = ui.PictureRecorder();

    TreePainter(
      layout: layout,
      theme: AppTheme.dark(),
      text: text,
      textScaler: TextScaler.noScaling,
    ).paint(Canvas(recorder), layout.size);
    recorder.endRecording().dispose();

    expect(layout.nodeFor(7)!.hasDetails, isFalse);
  });

  test('dashes a hundred pixels into ten short dashes', () {
    final path = dashedLine(Offset.zero, const Offset(100, 0));
    final metrics = path.computeMetrics().toList(growable: false);

    expect(metrics, hasLength(10));
    for (final metric in metrics) {
      expect(metric.length, closeTo(TreePainter.dashLength, 0.001));
    }
  });

  test('keeps the last dash short instead of overshooting', () {
    final path = dashedLine(Offset.zero, const Offset(5, 0));
    final metrics = path.computeMetrics().toList(growable: false);

    expect(metrics, hasLength(1));
    expect(metrics.single.length, closeTo(5, 0.001));
  });

  test('draws nothing for a zero-length line', () {
    final path = dashedLine(const Offset(10, 10), const Offset(10, 10));

    expect(path.computeMetrics(), isEmpty);
  });

  test('dashes around a corner without dropping the pattern', () {
    final bent = Path()
      ..moveTo(0, 0)
      ..lineTo(30, 0)
      ..lineTo(30, 30);
    final dashes = dashedPath(bent).computeMetrics().toList(growable: false);

    // Sixty pixels of path at 6 on, 4 off, carried across the bend.
    expect(dashes, hasLength(6));
    expect(
      dashes.fold<double>(0, (sum, metric) => sum + metric.length),
      closeTo(36, 0.001),
    );
  });

  test('repaints only when the tree or the text size changed', () {
    final layout = const TreeLayoutBuilder().build(_bundle());
    final theme = AppTheme.light();

    TreePainter painter(TextScaler scaler) => TreePainter(
      layout: layout,
      theme: theme,
      text: text,
      textScaler: scaler,
    );

    expect(
      painter(TextScaler.noScaling)
          .shouldRepaint(painter(TextScaler.noScaling)),
      isFalse,
    );
    expect(
      painter(TextScaler.noScaling)
          .shouldRepaint(painter(TextScaler.linear(1.4))),
      isTrue,
    );
    expect(
      painter(TextScaler.noScaling).shouldRepaint(
        TreePainter(
          layout: const TreeLayoutBuilder().build(_bundle()),
          theme: theme,
          text: text,
          textScaler: TextScaler.noScaling,
        ),
      ),
      isTrue,
    );
  });
}
