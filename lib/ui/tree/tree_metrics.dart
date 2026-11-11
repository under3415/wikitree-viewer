import 'dart:ui' show Rect;

/// Fixed geometry for the family tree.
///
/// Boxes grow with the user's text size so labels never clip, and gaps grow
/// with them so the tree does not turn into a solid block of text.
class TreeMetrics {
  const TreeMetrics({
    this.nodeWidth = 168,
    this.nodeHeight = 78,
    this.focusWidth = 208,
    this.focusHeight = 92,
    this.horizontalGap = 26,
    this.verticalGap = 74,
    this.padding = 40,
    this.avatarSize = 44,
    this.avatarInset = 10,
    this.avatarGap = 8,
  });

  final double nodeWidth;
  final double nodeHeight;
  final double focusWidth;
  final double focusHeight;
  final double horizontalGap;
  final double verticalGap;
  final double padding;

  /// Photo slot on the left of every box. Reserving it for everybody keeps the
  /// names aligned, and the monogram fills it when WikiTree has no photo.
  final double avatarSize;
  final double avatarInset;
  final double avatarGap;

  double widthFor({required bool isFocus}) => isFocus ? focusWidth : nodeWidth;

  double heightFor({required bool isFocus}) =>
      isFocus ? focusHeight : nodeHeight;

  /// Where the photo sits inside a box.
  Rect avatarRectIn(Rect box) => Rect.fromLTWH(
    box.left + avatarInset,
    box.top + (box.height - avatarSize) / 2,
    avatarSize,
    avatarSize,
  );

  /// Where the name and dates go: everything right of the photo.
  Rect labelRectFor(Rect box, Rect avatar) => Rect.fromLTRB(
    avatar.right + avatarGap,
    box.top,
    box.right - avatarInset,
    box.bottom,
  );

  /// Scales the boxes with the system font size, clamped so a very large
  /// accessibility setting still produces a usable tree.
  static TreeMetrics forTextScale(double textScale) {
    final scale = textScale.clamp(1.0, 1.6).toDouble();
    return TreeMetrics(
      nodeWidth: 168 * scale,
      nodeHeight: 78 * scale,
      focusWidth: 208 * scale,
      focusHeight: 92 * scale,
      horizontalGap: 26 * scale,
      verticalGap: 74 * scale,
      avatarSize: 44 * scale,
      avatarInset: 10 * scale,
      avatarGap: 8 * scale,
    );
  }
}
