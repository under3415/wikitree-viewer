import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/person.dart';
import '../format/person_text.dart';
import '../widgets/photo_avatar.dart';
import 'tree_layout.dart';
import 'tree_painter.dart';

/// A pan-and-zoom surface for a [TreeLayout].
///
/// One [CustomPaint] draws the boxes and lines; one transparent hit target per
/// box sits on top of it so taps work and screen readers can list the people.
///
/// The view opens centred on the focus person. Tapping anyone is reported to
/// [onPersonTap] - the screen then loads that person and hands back a new
/// layout, so the tree grows around whoever was tapped. Long-pressing reports
/// them to [onPersonLongPress] for their details.
class TreeView extends StatefulWidget {
  const TreeView({
    super.key,
    required this.layout,
    this.onPersonTap,
    this.onPersonLongPress,
  });

  final TreeLayout layout;
  final ValueChanged<Person>? onPersonTap;
  final ValueChanged<Person>? onPersonLongPress;

  /// Zoom limits. Pinching stays inside this range.
  static const double minScale = 0.3;
  static const double maxScale = 3;

  /// The tap target of one box, so tests and tools can find a person.
  static Key nodeKey(int personId) => ValueKey<String>('tree-node-$personId');

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
  );
  Animation<Matrix4>? _tween;

  Size _viewport = Size.zero;
  Object? _centredLayout;
  Size? _centredViewport;
  bool _hasCentred = false;

  @override
  void initState() {
    super.initState();
    _curve.addListener(_applyTween);
  }

  @override
  void dispose() {
    _curve.dispose();
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _applyTween() {
    final tween = _tween;
    if (tween != null) _transform.value = tween.value;
  }

  /// Centres the focus person once per layout and viewport, so a new focus or a
  /// rotation is followed but the user's own panning is left alone.
  void _maybeCentre(Size viewport) {
    if (!viewport.isFinite || viewport.isEmpty) return;
    if (identical(_centredLayout, widget.layout) &&
        _centredViewport == viewport) {
      return;
    }
    _centredLayout = widget.layout;
    _centredViewport = viewport;

    final layout = widget.layout;
    final animate = _hasCentred;
    _hasCentred = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(widget.layout, layout)) return;
      final scale = _currentScale();
      _animateTo(
        _centredMatrix(viewport, layout.focusRect.center, scale),
        animate: animate,
      );
    });
  }

  double _currentScale() => _transform.value
      .getMaxScaleOnAxis()
      .clamp(TreeView.minScale, TreeView.maxScale)
      .toDouble();

  Matrix4 _matrixFor(Offset translation, double scale) => Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    // All three axes: getMaxScaleOnAxis() reads the longest basis vector, so a
    // z of 1 would make every zoom below 1 look like 1.
    ..scaleByDouble(scale, scale, scale, 1);

  /// Puts [scenePoint] in the middle of the viewport at [scale].
  Matrix4 _centredMatrix(Size viewport, Offset scenePoint, double scale) =>
      _matrixFor(viewport.center(Offset.zero) - scenePoint * scale, scale);

  /// Shrinks the whole tree into the viewport, never enlarging past 1:1.
  Matrix4 _fitMatrix(Size viewport, Size content, {double margin = 24}) {
    final available = Size(
      math.max(1.0, viewport.width - margin * 2),
      math.max(1.0, viewport.height - margin * 2),
    );
    final scale = math
        .min(
          available.width / math.max(1.0, content.width),
          available.height / math.max(1.0, content.height),
        )
        .clamp(TreeView.minScale, 1.0)
        .toDouble();
    return _centredMatrix(viewport, content.center(Offset.zero), scale);
  }

  void _animateTo(Matrix4 target, {bool animate = true}) {
    if (!animate) {
      _animation.stop();
      _tween = null;
      _transform.value = target;
      return;
    }
    _tween = _MatrixTween(
      begin: _transform.value.clone(),
      end: target,
    ).animate(_curve);
    _animation.forward(from: 0);
  }

  void _fitToScreen() {
    if (_viewport.isEmpty) return;
    _animateTo(_fitMatrix(_viewport, widget.layout.size));
  }

  /// If a drag left the tree almost out of sight, bring it back: an elderly or
  /// first-time user can otherwise be left staring at an empty screen.
  void _keepOnScreen() {
    if (_viewport.isEmpty) return;
    final matrix = _transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final painted = Rect.fromLTWH(
      translation.x,
      translation.y,
      widget.layout.size.width * scale,
      widget.layout.size.height * scale,
    );
    final visible = painted.intersect(Offset.zero & _viewport);
    if (visible.width >= 48 && visible.height >= 48) return;
    _fitToScreen();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        _viewport = viewport;
        _maybeCentre(viewport);
        // Pinch to zoom, drag to pan. The tree is drawn on a plane the size of
        // the whole layout, so there is nothing to get lost inside of, and
        // _keepOnScreen brings it back if a drag goes too far.
        return _buildSurface(context);
      },
    );
  }

  Widget _buildSurface(BuildContext context) {
    final layout = widget.layout;
    final text = PersonText.of(context);
    return InteractiveViewer(
      transformationController: _transform,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: TreeView.minScale,
      maxScale: TreeView.maxScale,
      onInteractionStart: (_) => _animation.stop(),
      onInteractionEnd: (_) => _keepOnScreen(),
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: TreePainter(
                    layout: layout,
                    theme: Theme.of(context),
                    text: text,
                    textScaler: MediaQuery.textScalerOf(context),
                    textDirection:
                        Directionality.maybeOf(context) ?? TextDirection.ltr,
                  ),
                ),
              ),
            ),
            for (final node in layout.nodes)
              Positioned.fromRect(
                rect: node.rect,
                child: _hitTarget(node, text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hitTarget(TreeNodeLayout node, PersonText text) {
    final onTap = widget.onPersonTap;
    final onLongPress = widget.onPersonLongPress;
    final tap = onTap == null ? null : () => onTap(node.person);
    final longPress = onLongPress == null
        ? null
        : () => onLongPress(node.person);

    // The photo is a widget rather than something the painter has to fetch: it
    // reuses the same avatar as the rest of the app, including the monogram
    // for people with no photo, and Flutter's image cache handles the loading.
    final avatar = node.avatarRect;
    final box = node.rect;

    return Semantics(
      button: true,
      label: _describe(node, text),
      onTap: tap,
      onLongPress: longPress,
      excludeSemantics: true,
      child: GestureDetector(
        key: TreeView.nodeKey(node.person.id),
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        onLongPress: longPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: avatar.left - box.left,
              top: avatar.top - box.top,
              width: avatar.width,
              height: avatar.height,
              child: PhotoAvatar(person: node.person, size: avatar.width),
            ),
          ],
        ),
      ),
    );
  }

  /// What a screen reader announces for one box.
  static String _describe(TreeNodeLayout node, PersonText text) {
    final parts = <String>[
      text.displayName(node.person),
      text.lifeSpan(node.person),
      if (node.isFocus) text.l10n.treeMiddleSemantics,
      if (!node.hasDetails) text.l10n.treeNotPublicSemantics,
    ];
    return parts.join(', ');
  }
}

/// Lerps two pan/zoom matrices so the animation keeps a steady speed.
class _MatrixTween extends Tween<Matrix4> {
  _MatrixTween({required Matrix4 begin, required Matrix4 end})
    : super(begin: begin, end: end);

  @override
  Matrix4 lerp(double t) {
    final from = begin!.storage;
    final to = end!.storage;
    final result = Matrix4.identity();
    for (var i = 0; i < result.storage.length; i++) {
      result.storage[i] = from[i] + (to[i] - from[i]) * t;
    }
    return result;
  }
}
