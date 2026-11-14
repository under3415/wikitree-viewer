import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/crash_reporter.dart';
import '../../core/failures.dart';
import '../../core/sharing.dart';
import '../../data/person.dart';
import '../../data/preferences.dart';
import '../../data/wikitree_repository.dart';
import '../../l10n/app_localizations.dart';
import '../format/failure_text.dart';
import '../format/person_text.dart';
import '../tree/tree_layout.dart';
import '../tree/tree_metrics.dart';
import '../tree/tree_view.dart';
import '../widgets/status_views.dart';
import '../widgets/tree_tips.dart';
import 'person_summary_screen.dart';

/// The family tree, centred on one person.
///
/// Tapping anyone reloads the tree around them; long-pressing anyone opens
/// their details. Both are one request each, and the graph keeps everything
/// already fetched, so the tree only ever grows.
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({
    super.key,
    required this.repository,
    required this.bundle,
    required this.preferences,
  });

  final WikiTreeRepository repository;
  final FocusBundle bundle;

  /// Used for one thing here: whether the hints about the gestures have been
  /// shown before.
  final AppPreferences preferences;

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  late FocusBundle _bundle = widget.bundle;
  late TreeLayout _layout;
  FocusBundle? _layoutBundle;
  double? _layoutTextScale;

  late int _ancestorDepth = widget.bundle.ancestorDepth;
  late int _descendantDepth = widget.bundle.descendantDepth;

  /// Set once asking for another generation down brought nobody new, so the
  /// view can say "that is all" instead of "we have not looked".
  bool _descendantsExhausted = false;

  /// The same for the top: asking for more ancestors brought nobody new, so the
  /// line really does end there (their parents are recorded but private, say).
  bool _ancestorsExhausted = false;

  /// How many people are recorded below the bottom row, once WikiTree has been
  /// asked. `null` means the answer has not arrived yet.
  int? _hiddenDescendants;

  /// No exact count came back - either the look failed, or the bottom row was too
  /// wide to ask about. Either way there is no proof that nobody is there, so the
  /// button stays and says "More" instead of a number.
  bool _descendantCountMissing = false;

  /// The row [_hiddenDescendants] describes, so the same row is not asked twice.
  String? _checkedRow;

  /// How many people a "how many are below?" probe may cover.
  ///
  /// The probe asks WikiTree about every person on the bottom row in one request.
  /// Past this many the exact number is not worth the request, and the pill says
  /// "More" instead - it can still be tapped, which is the part that matters.
  static const int _probeLimit = 40;

  /// Where the user has been: back walks out of the tree one person at a time.
  final List<_TreeStop> _history = <_TreeStop>[];

  /// More than this and the trail is longer than anyone needs.
  static const int _maxHistory = 25;

  bool _busy = false;
  WikiTreeFailure? _failure;

  /// The hints are scheduled once per screen, even though
  /// [didChangeDependencies] runs again whenever the theme or text scale does.
  bool _tipsScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildLayoutIfNeeded();
    unawaited(_checkDescendants());
    if (!_tipsScheduled) {
      _tipsScheduled = true;
      // After this frame: a dialog cannot be opened while the tree is still
      // being built, and the user should see the tree behind it, not a blank
      // screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showTipsOnce());
      });
    }
  }

  /// Shows the four gestures the first time a tree is ever opened, then never
  /// again: they are useful once and in the way after that.
  Future<void> _showTipsOnce() async {
    if (!mounted) return;
    if (await widget.preferences.hasSeenTreeTips()) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => const TreeTipsDialog(),
    );
    await widget.preferences.markTreeTipsSeen();
  }

  /// Lays the tree out again only when the person or the text scale changed.
  void _rebuildLayoutIfNeeded() {
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (identical(_layoutBundle, _bundle) && _layoutTextScale == textScale) {
      return;
    }
    _layout = TreeLayoutBuilder(metrics: TreeMetrics.forTextScale(textScale))
        .build(_bundle);
    _layoutBundle = _bundle;
    _layoutTextScale = textScale;
  }

  Future<void> _focusOn(Person person) async {
    if (_busy || person.id == _bundle.focus.id) return;
    setState(() {
      _busy = true;
      _failure = null;
    });

    FocusBundle? loaded;
    WikiTreeFailure? failure;
    try {
      loaded = await widget.repository.loadFocus(
        person.wikiTreeId,
        ancestors: _ancestorDepth,
        descendants: _descendantDepth,
      );
    } on WikiTreeFailure catch (error) {
      failure = error;
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'tree-focus');
      failure = const ServerFailure();
    }

    if (!mounted) return;
    setState(() {
      if (loaded != null) {
        _rememberWhereWeWere();
        _bundle = loaded;
        _descendantsExhausted = false;
        _ancestorsExhausted = false;
        _hiddenDescendants = null;
        _descendantCountMissing = false;
        _rebuildLayoutIfNeeded();
      }
      _busy = false;
      _failure = failure;
    });
    if (loaded != null) unawaited(_checkDescendants());
  }

  /// Records what is on screen now, so back can return to it exactly.
  void _rememberWhereWeWere() {
    _history.add(
      _TreeStop(
        bundle: _bundle,
        ancestorDepth: _ancestorDepth,
        descendantDepth: _descendantDepth,
        hiddenDescendants: _hiddenDescendants,
        descendantsExhausted: _descendantsExhausted,
      ),
    );
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  /// Back returns to whoever was the middle of the tree before, rather than
  /// straight out of the tree: a walk through a family is worth undoing a step
  /// at a time.
  void _goBack() {
    if (_history.isEmpty) return;
    _restore(_history.removeLast());
  }

  /// Leaves the tree entirely, the way the X in the corner promises.
  ///
  /// Popped imperatively rather than through [PopScope]: back is a step in the
  /// walk through the family and only leaves the tree when there is nowhere left
  /// to go, while this button leaves it from wherever the walk happens to be.
  void _close() => Navigator.of(context).pop();

  /// Puts a remembered stop back on screen, answers and all.
  void _restore(_TreeStop stop) {
    final answered = stop.hiddenDescendants != null;
    setState(() {
      _bundle = stop.bundle;
      _ancestorDepth = stop.ancestorDepth;
      _descendantDepth = stop.descendantDepth;
      _hiddenDescendants = stop.hiddenDescendants;
      _descendantsExhausted = stop.descendantsExhausted;
      _descendantCountMissing = false;
      _failure = null;
      _rebuildLayoutIfNeeded();
      // This row was already looked at, so its answer is still good - unless it
      // was never answered, in which case it is asked again below.
      _checkedRow = answered
          ? _bottomRow.map((person) => person.id).join(',')
          : null;
    });
    if (!answered) unawaited(_checkDescendants());
  }

  /// Grows the tree by two generations in the direction the user asked for.
  ///
  /// Only the new part is fetched: the two generations just beyond the row on the
  /// screen, from that row, in batches small enough for one request. Asking the
  /// whole cone again at the deeper depth would send the entire tree on every tap
  /// and eventually outgrow what WikiTree answers in one go.
  Future<void> _loadMore({required bool moreAncestors}) async {
    if (_busy) return;
    final ancestors = moreAncestors
        ? _ancestorDepth + ApiConfig.growthStep
        : _ancestorDepth;
    final descendants = moreAncestors
        ? _descendantDepth
        : _descendantDepth + ApiConfig.growthStep;
    final edge = moreAncestors ? _topRow : _bottomRow;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final shownBefore = _drawnIds.length;
    var grew = true;
    WikiTreeFailure? failure;
    try {
      await widget.repository.grow(edge, ancestors: moreAncestors);
    } on WikiTreeFailure catch (error) {
      failure = error;
      grew = false;
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'tree-deeper');
      failure = const ServerFailure();
      grew = false;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
      if (grew) {
        _ancestorDepth = ancestors;
        _descendantDepth = descendants;
        _bundle = FocusBundle(
          focus: _bundle.focus,
          graph: widget.repository.graph,
          ancestorDepth: ancestors,
          descendantDepth: descendants,
        );
        if (!moreAncestors) {
          // The bottom row is about to change, so its count is stale.
          _hiddenDescendants = null;
          _descendantCountMissing = false;
        }
        _rebuildLayoutIfNeeded();
      }
      // Nobody new on screen means asking again would change nothing, however
      // many generations were asked for. This is what ends a line - not a limit on
      // how far the tree may grow.
      if (failure == null && _drawnIds.length == shownBefore) {
        if (moreAncestors) {
          _ancestorsExhausted = true;
        } else {
          _descendantsExhausted = true;
        }
      }
    });
    if (failure == null && !moreAncestors) unawaited(_checkDescendants());
  }

  /// The lowest row on screen: their children are exactly what a "more
  /// descendants" tap would fetch, so they decide whether that button exists.
  ///
  /// Only people below the focus count. When the focus has no children of its
  /// own the lowest row is the focus row, which also holds brothers, sisters and
  /// in-laws: counting *their* children offered "2 more" under Nikola Tesla -
  /// who has no descendants - and growing the tree could only ever add nothing.
  /// The focus itself is the one person on that row whose children would appear.
  List<Person> get _bottomRow => <Person>[
    for (final node in _layout.nodes)
      if (node.generation == _layout.minGeneration &&
          (node.generation < 0 || node.isFocus))
        node.person,
  ];

  /// The top row on screen: their parents are exactly what a "more ancestors" tap
  /// would fetch.
  List<Person> get _topRow => <Person>[
    for (final node in _layout.nodes)
      if (node.generation == _layout.maxGeneration) node.person,
  ];

  /// Everybody on screen, so a probe can tell "below the tree" from "already
  /// drawn": the graph keeps people the current tree has no room for.
  Set<int> get _drawnIds => <int>{
    for (final node in _layout.nodes) node.person.id,
  };

  /// Asks whether anybody is recorded below the bottom row.
  ///
  /// Children never come back with their parents (WikiTree silently drops a
  /// requested `Children` field), so the only way to know before asking for the
  /// generation itself is to ask for their ids. Measured at a few hundred bytes
  /// per person, which buys a button that never promises somebody who is not
  /// there.
  Future<void> _checkDescendants() async {
    final row = _bottomRow;
    final signature = row.map((person) => person.id).join(',');
    if (signature == _checkedRow) return;
    _checkedRow = signature;

    // A wide row would need one key per person in a single request, for a number
    // nobody needs. "More" is enough: the pill can still be tapped.
    if (row.length > _probeLimit) {
      setState(() {
        _hiddenDescendants = null;
        _descendantCountMissing = true;
      });
      return;
    }

    int? count;
    var failed = false;
    final revision = widget.repository.graph.linkRevision;
    try {
      count = await widget.repository.hiddenChildCount(row, shown: _drawnIds);
    } on WikiTreeFailure {
      failed = true;
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'tree-below');
      failed = true;
    }

    if (!mounted || signature != _checkedRow) return;
    // The probe can also hand the graph a link it could not have otherwise: the
    // children of a semi-private person name their parent as "-3", while the
    // parent's own `Children` list names them. If that attached somebody already
    // in memory, the rows have changed and the tree has to be drawn again - and
    // the row just asked about is no longer the bottom one.
    final attached = widget.repository.graph.linkRevision != revision;
    setState(() {
      _hiddenDescendants = count;
      _descendantCountMissing = failed;
      if (attached) {
        _bundle = FocusBundle(
          focus: _bundle.focus,
          graph: widget.repository.graph,
          ancestorDepth: _ancestorDepth,
          descendantDepth: _descendantDepth,
        );
        _rebuildLayoutIfNeeded();
      }
    });
    if (attached) unawaited(_checkDescendants());
  }

  Future<void> _openDetails(Person person) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Siblings and spouses of this person may not be in the graph yet. A
    // failure here is not fatal: the details view shows what the tree knows.
    try {
      await widget.repository.loadRelatives(person);
    } on WikiTreeFailure {
      // Ignored on purpose.
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'tree-details');
    }

    if (!mounted) return;
    setState(() => _busy = false);

    final current = widget.repository.graph.byId(person.id) ?? person;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            PersonSummaryScreen(bundle: widget.repository.bundleFor(current)),
      ),
    );
  }

  /// Shares this tree: the WikiTree link, a link that reopens the app on this
  /// person, and where to get the app when it is not installed yet.
  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final text = PersonText.of(context);
    final focus = _bundle.focus;
    final message = shareMessage(focus, l10n: l10n, text: text);
    final action = await showModalBottomSheet<_ShareAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ShareSheet(),
    );
    if (!mounted || action == null) return;

    if (action == _ShareAction.copy) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareCopied)));
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: l10n.shareSubject(text.displayName(focus)),
        ),
      );
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'tree-share');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
  }

  /// Terse answers to "is there more up there?": a count, or nothing at all when
  /// the line really ends here.
  String? _ancestorLabel(AppLocalizations l10n) {
    if (!_layout.hasMoreAncestors) return null;
    if (_ancestorsExhausted) return null;
    return l10n.moreCount(_layout.hiddenAncestorCount);
  }

  /// Terse answers to "is there more below here?": a count, or nothing at all
  /// when this is as far as the line goes.
  ///
  /// There is no depth limit: a tap adds `ApiConfig.growthStep` generations and
  /// the pill stays until asking brings nobody new.
  String? _descendantLabel(AppLocalizations l10n) {
    if (_descendantsExhausted) return null;

    final hidden = _hiddenDescendants;
    if (hidden == null) {
      // Still looking. Nothing is promised until the answer is in.
      return _descendantCountMissing ? l10n.moreUnknown : null;
    }
    return hidden > 0 ? l10n.moreCount(hidden) : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = PersonText.of(context);
    final focus = _bundle.focus;
    final ancestorLabel = _ancestorLabel(l10n);
    final descendantLabel = _descendantLabel(l10n);
    final failed = _failure;
    final failureText = failed == null ? null : describeFailure(l10n, failed);
    return PopScope(
      // Back leaves the tree only when there is nowhere inside it to go back to.
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, Object? result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          // Two controls in the top corner, X first and the arrow beside it.
          //
          // The X leaves the tree from wherever the walk happens to be. The arrow
          // steps back through the people visited, which is what the system back
          // gesture does on Android - but iOS puts no back button on the screen,
          // so without the arrow the only way out of a walk there would be the X,
          // which throws the trail away.
          automaticallyImplyLeading: false,
          leadingWidth: 96,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('tree-close'),
                tooltip: l10n.treeCloseTooltip,
                icon: const Icon(Icons.close_rounded),
                onPressed: _close,
              ),
              IconButton(
                key: const ValueKey<String>('tree-back'),
                tooltip: l10n.treeBackTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
                // Greyed out rather than gone when there is nothing behind this
                // person: the corner keeps its shape, and the arrow still says a
                // walk through the family can be undone.
                onPressed: _history.isEmpty ? null : _goBack,
              ),
            ],
          ),
          title: Text(text.displayName(focus), overflow: TextOverflow.ellipsis),
          actions: <Widget>[
            // Anything about the top of the tree belongs at the top of the screen,
            // and in the bar it never covers a person.
            if (ancestorLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: Center(
                  child: _GrowthControl(
                    key: const ValueKey<String>('tree-more-ancestors'),
                    icon: Icons.expand_less,
                    label: ancestorLabel,
                    onPressed: () => _loadMore(moreAncestors: true),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: TreeView(
                layout: _layout,
                onPersonTap: _focusOn,
                onPersonLongPress: _openDetails,
              ),
            ),
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
            // The error banner stays at the top; the "more ancestors" control
            // lives in the app bar, where it cannot cover a person. SafeArea
            // keeps it clear of a cutout or a navigation bar at the side.
            if (failureText != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: ErrorBanner(
                    message: failureText.message,
                    hint: failureText.hint,
                  ),
                ),
              ),
            // The two controls at the bottom share one SafeArea, because the
            // tree is drawn edge to edge: on Android 15 and later the system
            // navigation bar is painted over the bottom of the app, and without
            // this the buttons end up underneath it. The side insets matter in
            // landscape, where a three-button bar sits at one end of the screen.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                // SafeArea takes the larger of this and the system inset, so
                // the 12 that was here before survives on devices without one.
                minimum: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    // Where the zoom buttons used to be. Pinching handles zoom
                    // now, so this corner is free for the thing people actually
                    // look for.
                    IconButton.filledTonal(
                      key: const ValueKey<String>('tree-share'),
                      tooltip: l10n.shareTooltip,
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.share_outlined),
                    ),
                    const Spacer(),
                    // ...and anything about the bottom at the bottom, on the
                    // right like its counterpart in the app bar.
                    if (descendantLabel != null)
                      _GrowthControl(
                        key: const ValueKey<String>('tree-more-descendants'),
                        icon: Icons.expand_more,
                        label: descendantLabel,
                        onPressed: () => _loadMore(moreAncestors: false),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of the walk through the tree: everything needed to put the screen
/// back exactly as it was when the user tapped somebody else.
class _TreeStop {
  const _TreeStop({
    required this.bundle,
    required this.ancestorDepth,
    required this.descendantDepth,
    required this.hiddenDescendants,
    required this.descendantsExhausted,
  });

  final FocusBundle bundle;
  final int ancestorDepth;
  final int descendantDepth;
  final int? hiddenDescendants;
  final bool descendantsExhausted;
}

/// What the share sheet was asked to do.
enum _ShareAction { share, copy }

/// The two ways of passing a tree on: hand it to another app, or copy the text
/// so it can be pasted anywhere.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.shareSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          ListTile(
            key: const ValueKey<String>('tree-share-apps'),
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.shareWithApp),
            subtitle: Text(l10n.shareWithAppSubtitle),
            onTap: () => Navigator.of(context).pop(_ShareAction.share),
          ),
          ListTile(
            key: const ValueKey<String>('tree-share-copy'),
            leading: const Icon(Icons.copy_rounded),
            title: Text(l10n.shareCopyLink),
            subtitle: Text(l10n.shareCopyLinkSubtitle),
            onTap: () => Navigator.of(context).pop(_ShareAction.copy),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A terse "there is more this way" pill. Only built when there is something to
/// load, so its absence is the answer that this is the end of the line.
class _GrowthControl extends StatelessWidget {
  const _GrowthControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: scheme.onSecondaryContainer),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
