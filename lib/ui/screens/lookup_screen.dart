import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants.dart';
import '../../core/crash_reporter.dart';
import '../../core/failures.dart';
import '../../data/key_parser.dart';
import '../../data/preferences.dart';
import '../../data/wikitree_repository.dart';
import '../../l10n/app_localizations.dart';
import '../format/failure_text.dart';
import '../widgets/status_views.dart';
import '../widgets/wikitree_id_formatter.dart';
import 'family_tree_screen.dart';

/// Where a session starts: type or paste a WikiTree ID, or a profile link.
class LookupScreen extends StatefulWidget {
  const LookupScreen({
    super.key,
    required this.repository,
    required this.preferences,
    this.links,
  });

  final WikiTreeRepository repository;

  /// What the app remembers between runs.
  final AppPreferences preferences;

  /// WikiTree IDs arriving from outside the app, e.g. somebody shared a family
  /// link. Each one is opened as soon as it arrives.
  final Stream<String>? links;

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  StreamSubscription<String>? _links;
  bool _busy = false;
  WikiTreeFailure? _failure;

  @override
  void initState() {
    super.initState();
    // This screen stays mounted underneath the tree, so a link that arrives
    // while a tree is open still lands here and opens the tree it points at.
    _links = widget.links?.listen(_openLink);
    unawaited(_restoreLastCode());
  }

  /// Puts the family the user opened last back in the box, so the second visit
  /// is one tap rather than typing the same code again.
  Future<void> _restoreLastCode() async {
    final code = await widget.preferences.lastCode();
    // Never overwrite typing that started while the storage was being read, and
    // never fight a link that has already put its own code there.
    if (!mounted || code == null || _input.text.isNotEmpty) return;
    _input.text = code;
    _input.selection = TextSelection.collapsed(offset: code.length);
  }

  @override
  void dispose() {
    // The node is ours, so it is ours to dispose.
    _links?.cancel();
    _inputFocus.dispose();
    _input.dispose();
    super.dispose();
  }

  void _openLink(String wikiTreeId) {
    if (!mounted || _busy) return;
    _input.text = wikiTreeId;
    unawaited(_open(wikiTreeId));
  }

  /// Empties the box and puts the cursor back in it, ready for a new code. Any
  /// message about the old one goes with it.
  void _clear() {
    setState(() {
      _input.clear();
      _failure = null;
    });
    _inputFocus.requestFocus();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() {
      _input.text = text;
      _failure = null;
    });
  }

  Future<void> _open(String rawInput) async {
    if (_busy) return;

    // Submitting means "I am done typing": close the keyboard *before* any
    // message is shown, so it cannot cover the message.
    _inputFocus.unfocus();

    final input = rawInput.trim();
    _input.text = input;
    setState(() => _failure = null);

    // Validate before any network call so typos fail instantly.
    try {
      KeyParser.parse(input);
    } on WikiTreeFailure catch (failure) {
      setState(() => _failure = failure);
      return;
    }

    setState(() => _busy = true);

    FocusBundle? bundle;
    WikiTreeFailure? failure;
    try {
      bundle = await widget.repository.loadFocus(input);
    } on WikiTreeFailure catch (error) {
      failure = error;
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'lookup');
      failure = const ServerFailure();
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });

    final loaded = bundle;
    if (loaded == null) return;

    // Remembered only once WikiTree has answered, so a typo is never the code
    // that greets the user next time. The canonical id, not the raw input: a
    // pasted profile link leaves clean code behind.
    unawaited(widget.preferences.rememberCode(loaded.focus.wikiTreeId));

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FamilyTreeScreen(
          repository: widget.repository,
          bundle: loaded,
          preferences: widget.preferences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    final failureText = failure == null ? null : describeFailure(l10n, failure);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Dragging the page also dismisses the keyboard.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Header(),
                  const SizedBox(height: 36),
                  // Rebuilt as the text changes so the clear button can appear
                  // only when there is something to clear.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, child) => TextField(
                      controller: _input,
                      // Deliberately *not* disabled while loading: a disabled
                      // field cannot take focus, so tapping it would do nothing
                      // and the keyboard would never come up.
                      focusNode: _inputFocus,
                      autocorrect: false,
                      enableSuggestions: false,
                      // WikiTree IDs are case sensitive, and nobody types the
                      // capital. A pasted link is left exactly as it is.
                      inputFormatters: const <TextInputFormatter>[
                        WikiTreeIdCaseFormatter(),
                      ],
                      textInputAction: TextInputAction.go,
                      style: theme.textTheme.titleLarge,
                      onSubmitted: _busy ? null : _open,
                      // Tapping anywhere else (including the button) closes the
                      // keyboard, which is what mobile users expect.
                      onTapOutside: (_) => _inputFocus.unfocus(),
                      decoration: InputDecoration(
                        labelText: l10n.lookupLabel,
                        prefixIcon: const Icon(Icons.person_search_outlined),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                key: const ValueKey<String>('lookup-clear'),
                                tooltip: l10n.lookupClear,
                                onPressed: _busy ? null : _clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _open(_input.text),
                    icon: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.account_tree_outlined),
                    label: Text(_busy ? l10n.lookupBusy : l10n.lookupSubmit),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _paste,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.content_paste_rounded),
                    label: Text(l10n.lookupPaste),
                  ),
                  if (failureText != null) ...<Widget>[
                    const SizedBox(height: 20),
                    ErrorBanner(
                      message: failureText.message,
                      hint: failureText.hint,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    l10n.lookupExamplePrompt,
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                  // Two suggestions rather than one: one on its own reads like
                  // the only family the app can open, and the pair also shows
                  // that the surname is part of the code.
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      TextButton(
                        onPressed: _busy ? null : () => _open(AppInfo.exampleKey),
                        child: Text(l10n.lookupTryExample(AppInfo.exampleKey)),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _open(AppInfo.secondExampleKey),
                        child: Text(
                          l10n.lookupOrTry(AppInfo.secondExampleKey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.disclaimer,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    // Vector art, so it can grow with the reader's text size without going blurry
    // or eating the screen.
    final logoSize = MediaQuery.textScalerOf(context)
        .scale(112)
        .clamp(112.0, 160.0);
    return Column(
      children: <Widget>[
        SvgPicture.asset(
          AppInfo.logoAsset,
          width: logoSize,
          height: logoSize,
          semanticsLabel: l10n.appTitle,
        ),
        const SizedBox(height: 20),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
