import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// The four gestures that make the tree work, shown once on the first tree.
///
/// A plain dialog rather than a coach-mark overlay: it needs no layout maths on
/// top of the tree, it is reachable by screen readers, and it can be read at any
/// text size without covering the person the user just asked for.
class TreeTipsDialog extends StatelessWidget {
  const TreeTipsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.account_tree_outlined),
      title: Text(l10n.treeTipsTitle),
      // Scrolls, because four lines of guidance plus a heading is more than a
      // short screen holds at a large text size.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Tip(icon: Icons.swipe, text: l10n.treeTipsSwipe),
            _Tip(icon: Icons.pinch, text: l10n.treeTipsZoom),
            _Tip(icon: Icons.touch_app, text: l10n.treeTipsTap),
            _Tip(icon: Icons.info_outline, text: l10n.treeTipsLongPress),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('tree-tips-dismiss'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.treeTipsDismiss,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One gesture: its icon, and what it does.
class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
