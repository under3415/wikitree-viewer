import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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
  /// How many remembered codes are offered at once. More than this turns the
  /// suggestion list into a second screen under the box.
  static const int _maxSuggestions = 5;

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  StreamSubscription<String>? _links;
  bool _busy = false;
  WikiTreeFailure? _failure;

  /// The codes this device opened before, newest first.
  List<String> _recent = const <String>[];

  @override
  void initState() {
    super.initState();
    // This screen stays mounted underneath the tree, so a link that arrives
    // while a tree is open still lands here and opens the tree it points at.
    _links = widget.links?.listen(_openLink);
    // The insert keys belong to the box: they appear with the keyboard.
    _inputFocus.addListener(_handleInputFocusChange);
    unawaited(_restoreLastCode());
    unawaited(_loadRecentCodes());
  }

  void _handleInputFocusChange() {
    if (mounted) setState(() {});
  }

  /// Puts [character] where the cursor is, in place of any selection.
  ///
  /// A hyphen and an underscore sit on a second layer of every phone keyboard
  /// (the 123 layer on iOS, the symbols page on Gboard), and a WikiTree ID needs
  /// them for the surname and for the number after it. These keys are the
  /// shortest path to both that no keyboard has to cooperate with. Writing the
  /// controller directly is safe: `WikiTreeIdCaseFormatter` only reacts to typing
  /// and only adds capitals, which `-` and `_` never need.
  void _insert(String character) {
    final value = _input.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    _input.value = TextEditingValue(
      text: text.replaceRange(start, end, character),
      selection: TextSelection.collapsed(offset: start + character.length),
    );
    // The box is still where the typing happens, so it keeps the keyboard.
    _inputFocus.requestFocus();
  }

  /// Reads the remembered codes, so typing can offer them.
  Future<void> _loadRecentCodes() async {
    final codes = await widget.preferences.recentCodes();
    if (!mounted) return;
    setState(() => _recent = codes);
  }

  /// Remembered codes that match what is in the box, newest first.
  ///
  /// Nothing is offered for an empty box: the point is to save typing, and a
  /// list of codes with nothing typed is a menu, not a suggestion. The code that
  /// is already there in full is skipped, because the button underneath already
  /// does what tapping it would do.
  List<String> _suggestionsFor(String typed) {
    final text = typed.trim().toLowerCase();
    if (text.isEmpty) return const <String>[];

    final matches = <String>[];
    for (final code in _recent) {
      final lower = code.toLowerCase();
      if (lower == text || !lower.contains(text)) continue;
      matches.add(code);
      if (matches.length == _maxSuggestions) break;
    }
    return matches;
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

  /// Writes [code] down and refreshes the suggestions, so the family just opened
  /// is offered next time without waiting for a restart.
  Future<void> _remember(String code) async {
    await widget.preferences.rememberCode(code);
    await _loadRecentCodes();
  }

  @override
  void dispose() {
    // The node is ours, so it is ours to dispose.
    _links?.cancel();
    _inputFocus.removeListener(_handleInputFocusChange);
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
    unawaited(_remember(loaded.focus.wikiTreeId));

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
    // Which families to suggest follows the language: the examples are people the
    // reader is likely to recognise, not the same two names everywhere.
    final examples = AppInfo.examplesFor(
      Localizations.localeOf(context).languageCode,
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
                  // only when there is something to clear, and so the families
                  // opened before can be offered underneath while typing.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, child) {
                      final suggestions = _suggestionsFor(value.text);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
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
                              prefixIcon: const Icon(
                                Icons.person_search_outlined,
                              ),
                              suffixIcon: value.text.isEmpty
                                  ? null
                                  : IconButton(
                                      key: const ValueKey<String>(
                                        'lookup-clear',
                                      ),
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
                          if (_inputFocus.hasFocus) ...<Widget>[
                            const SizedBox(height: 8),
                            // Part of the box's tap region on purpose: otherwise
                            // the tap counts as "outside" the field, the field
                            // unfocuses, and the key is gone from under the finger
                            // before its tap is registered - which is exactly what
                            // a click (or a slow tap) did.
                            TextFieldTapRegion(
                              child: _InsertKeys(onInsert: _insert),
                            ),
                          ],
                          if (suggestions.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            _RecentSuggestions(
                              title: l10n.lookupRecentTitle,
                              codes: suggestions,
                              onSelected: _busy ? null : _open,
                            ),
                          ],
                        ],
                      );
                    },
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
                  // Two examples rather than one: one on its own reads like
                  // the only family the app can open, and the pair also shows
                  // that the surname is part of the code. "Try" and "or" are
                  // labels and only the codes are buttons.
                  //
                  // The codes are the ones people in this language know: Goethe
                  // for a German reader, Karađorđević for a Serbian one.
                  //
                  // The gaps are all the same width so the "or" sits halfway
                  // between the two codes rather than hugging one of them.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      for (var index = 0; index < examples.length; index++)
                        _ExampleButton(
                          label: index == 0
                              ? l10n.lookupExampleTry
                              : l10n.lookupExampleOr,
                          code: examples[index],
                          onPressed: _busy
                              ? null
                              : () => _open(examples[index]),
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
    // The app icon itself, so the first thing the app shows is the thing that
    // was tapped on the home screen. It grows with the reader's text size, up
    // to a size that still leaves room for the box underneath.
    final iconSize = MediaQuery.textScalerOf(context)
        .scale(112)
        .clamp(112.0, 160.0);
    return Column(
      children: <Widget>[
        Image.asset(
          AppInfo.appIconAsset,
          width: iconSize,
          height: iconSize,
          semanticLabel: l10n.appTitle,
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

/// The two characters a WikiTree ID needs that phone keyboards keep on a second
/// layer: `-` between the surname and the number, and `_` in names such as
/// `Sachsen-Coburg_und_Gotha-4`.
///
/// Only on screen while the box has the keyboard, so the first screen does not
/// grow a permanent toolbar for a problem that only exists while typing.
class _InsertKeys extends StatelessWidget {
  const _InsertKeys({required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(64, 48),
      padding: EdgeInsets.zero,
      textStyle: theme.textTheme.titleLarge,
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Row(
      children: <Widget>[
        OutlinedButton(
          key: const ValueKey<String>('lookup-insert-hyphen'),
          onPressed: () => onInsert('-'),
          style: style,
          child: const Text('-'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: const ValueKey<String>('lookup-insert-underscore'),
          onPressed: () => onInsert('_'),
          style: style,
          child: const Text('_'),
        ),
      ],
    );
  }
}

/// One example family code, looking like the button it is.
///
/// The code is the whole label of the button; the word beside it ("Try", "or")
/// says what the codes are for, so the button never repeats it. A plain text
/// button, in the same style as the rest of the app's quiet actions.
///
/// The word and the button are one widget on purpose: left as separate children
/// of the row above, a narrow phone broke the line between "or" and the code it
/// belongs to.
class _ExampleButton extends StatelessWidget {
  const _ExampleButton({
    required this.label,
    required this.code,
    required this.onPressed,
  });

  final String label;
  final String code;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Wrap, not a Row: at the largest text sizes the pair no longer fits on
    // one line of a small phone, and the word can go above the code instead of
    // overflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      // The same 12 as the row above, so the "or" between the two codes is the
      // same distance from each of them.
      spacing: 12,
      runSpacing: 6,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          key: ValueKey<String>('lookup-example-$code'),
          onPressed: onPressed,
          child: Text(code),
        ),
      ],
    );
  }
}

/// The codes this device opened before that match what is being typed.
///
/// Tapping one opens it: a suggestion that only filled the box would cost the
/// second tap that the suggestion existed to save.
class _RecentSuggestions extends StatelessWidget {
  const _RecentSuggestions({
    required this.title,
    required this.codes,
    required this.onSelected,
  });

  final String title;
  final List<String> codes;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final code in codes)
            ListTile(
              key: ValueKey<String>('lookup-suggestion-$code'),
              dense: true,
              leading: Icon(
                Icons.history_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              title: Text(code, style: theme.textTheme.titleMedium),
              onTap: onSelected == null ? null : () => onSelected!(code),
            ),
        ],
      ),
    );
  }
}
