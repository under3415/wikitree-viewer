import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../format/person_text.dart';
import 'tree_layout.dart';

/// Draws the boxes and relationship lines of a [TreeLayout].
///
/// The tree is painted rather than built from widgets: a few generations of a
/// family is already dozens of boxes, and a single [CustomPaint] keeps panning
/// and zooming smooth. Tap targets and their screen-reader labels sit on top of
/// this painter, in the view that owns it.
class TreePainter extends CustomPainter {
  TreePainter({
    required this.layout,
    required this.theme,
    required this.text,
    required this.textScaler,
    this.textDirection = TextDirection.ltr,
  });

  final TreeLayout layout;
  final ThemeData theme;

  /// Names and dates in the reader's language.
  final PersonText text;

  /// The system text scale, applied to every label. The boxes grow with the
  /// same factor (see `TreeMetrics.forTextScale`), so text never has to shrink.
  final TextScaler textScaler;

  final TextDirection textDirection;

  static const double _boxRadius = 14;
  static const double _focusRadius = 18;
  static const double _dashLength = 6;
  static const double _gapLength = 4;

  /// Dash geometry for marriages that ended, exposed for the dashed helper.
  static const double dashLength = _dashLength;
  static const double gapLength = _gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    // Lines first: boxes are drawn over their ends, which hides the joins.
    _paintEdges(canvas);
    for (final node in layout.nodes) {
      _paintBox(canvas, node);
      _paintLabels(canvas, node);
    }
  }

  void _paintEdges(Canvas canvas) {
    final scheme = theme.colorScheme;
    final parentChild = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = scheme.outlineVariant;
    final marriage = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = scheme.primary.withValues(alpha: 0.55);
    final ended = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = scheme.outlineVariant;

    for (final edge in layout.edges) {
      switch (edge.kind) {
        case TreeEdgeKind.parentChild:
          canvas.drawPath(_polyline(edge.points), parentChild);
        case TreeEdgeKind.marriage:
          canvas.drawPath(_polyline(edge.points), marriage);
        case TreeEdgeKind.endedMarriage:
          canvas.drawPath(dashedPath(_polyline(edge.points)), ended);
      }
    }
  }

  void _paintBox(Canvas canvas, TreeNodeLayout node) {
    final scheme = theme.colorScheme;
    final rrect = RRect.fromRectAndRadius(
      node.rect,
      Radius.circular(node.isFocus ? _focusRadius : _boxRadius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = node.isFocus
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = node.isFocus ? 2.5 : 1.2
        ..color = node.isFocus ? scheme.primary : scheme.outlineVariant,
    );
  }

  void _paintLabels(Canvas canvas, TreeNodeLayout node) {
    final scheme = theme.colorScheme;
    final label = node.labelRect;
    final maxWidth = math.max(1.0, label.width);

    final nameStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 16)).copyWith(
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: node.isFocus ? scheme.onPrimaryContainer : scheme.onSurface,
        );
    final detailStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 13)).copyWith(
          height: 1.2,
          color: node.isFocus
              ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
              : scheme.onSurfaceVariant,
        );

    final name = _label(
      text.displayName(node.person),
      nameStyle,
      maxWidth,
      maxLines: 2,
    );
    final detail = _label(
      _secondLine(node),
      detailStyle,
      maxWidth,
      maxLines: 1,
    );

    final spacing = label.height * 0.03;
    final top =
        label.top + (label.height - name.height - detail.height - spacing) / 2;
    name.paint(canvas, Offset(label.left, top));
    detail.paint(canvas, Offset(label.left, top + name.height + spacing));
  }

  /// Dates, or a plain-language note when WikiTree keeps the profile hidden.
  String _secondLine(TreeNodeLayout node) =>
      text.treeSecondLine(node.person, hasDetails: node.hasDetails);

  TextPainter _label(
    String value,
    TextStyle style,
    double maxWidth, {
    required int maxLines,
  }) {
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textAlign: TextAlign.left,
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
      ellipsis: '\u2026',
    )..layout(maxWidth: maxWidth);
  }

  static Path _polyline(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.theme != theme ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.text.l10n != text.l10n ||
      oldDelegate.text.locale != text.locale;
}

/// Turns [source] into dashes, walking each segment in order so a bent bar stays
/// evenly dashed around its corners.
@visibleForTesting
Path dashedPath(
  Path source, {
  double dashLength = TreePainter.dashLength,
  double gapLength = TreePainter.gapLength,
}) {
  final dashed = Path();
  if (dashLength <= 0) return dashed;

  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dashLength, metric.length);
      dashed.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gapLength;
    }
  }
  return dashed;
}

/// A dashed straight line: marriages that ended, so they cannot be mistaken for
/// a current one.
@visibleForTesting
Path dashedLine(
  Offset from,
  Offset to, {
  double dashLength = TreePainter.dashLength,
  double gapLength = TreePainter.gapLength,
}) {
  if ((to - from).distance <= 0) return Path();
  return dashedPath(
    Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy),
    dashLength: dashLength,
    gapLength: gapLength,
  );
}
