import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/app.dart';
import 'package:wikitree_viewer/core/constants.dart';
import 'package:wikitree_viewer/core/deep_links.dart';
import 'package:wikitree_viewer/core/failures.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/data/preferences.dart';
import 'package:wikitree_viewer/data/wikitree_api.dart';
import 'package:wikitree_viewer/data/wikitree_repository.dart';
import 'package:wikitree_viewer/ui/screens/person_summary_screen.dart';
import 'package:wikitree_viewer/ui/tree/tree_view.dart';

class _EmptyApi implements WikiTreeApi {
  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async => throw const NotFoundFailure();

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{for (final key in keys) key: const <int>[]};

  @override
  void invalidate() {}

  @override
  void close() {}
}

class _FamilyApi implements WikiTreeApi {
  static const Person _albert = Person(
    id: 1,
    wikiTreeId: 'Einstein-1',
    firstName: 'Albert',
    lastNameAtBirth: 'Einstein',
    birthDate: '1879-03-14',
    deathDate: '1955-04-18',
    fatherId: 2,
  );

  static const Person _hermann = Person(
    id: 2,
    wikiTreeId: 'Einstein-2',
    firstName: 'Hermann',
    lastNameAtBirth: 'Einstein',
    birthDate: '1847-08-30',
  );

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    return PeopleResponse(
      people: const <Person>[_albert, _hermann],
      // Whichever key was asked for becomes the middle of the tree.
      resolvedId: key == _hermann.wikiTreeId ? _hermann.id : _albert.id,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{for (final key in keys) key: const <int>[]};

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// An API whose answer changes between calls, the way a profile does when
/// somebody else edits it while the tree is open.
///
/// The correction fills exactly the same fields before and after, so the graph's
/// "the richer copy wins" rule cannot see it: only a reload that starts from an
/// empty graph does.
class _EditingApi implements WikiTreeApi {
  static const Person _hermann = Person(
    id: 2,
    wikiTreeId: 'Einstein-2',
    firstName: 'Hermann',
    lastNameAtBirth: 'Einstein',
    birthDate: '1847-08-30',
  );

  /// Whether the edit has landed. It happens when the app asks for fresh data,
  /// which is exactly the moment a cache-clearing refresh has to see it.
  bool edited = false;

  int invalidations = 0;

  @override
  void invalidate() {
    invalidations++;
    edited = true;
  }

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    final albert = Person(
      id: 1,
      wikiTreeId: 'Einstein-1',
      firstName: edited ? 'Albertus' : 'Albert',
      lastNameAtBirth: 'Einstein',
      birthDate: edited ? '1879-03-15' : '1879-03-14',
      deathDate: '1955-04-18',
      fatherId: 2,
    );
    return PeopleResponse(
      people: <Person>[albert, _hermann],
      resolvedId: key == _hermann.wikiTreeId ? _hermann.id : albert.id,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{for (final key in keys) key: const <int>[]};

  @override
  void close() {}
}

/// A parent whose son's own record hides him.
///
/// WikiTree answers `Father: -3` for a child of a semi-private parent - a
/// placeholder naming nobody - so the son arrives with no father at all. Only the
/// parent's `Children` list names the link. This is the shape measured on
/// Nakarada-1, where the tree offered "1 more" forever for a son it already had
/// in memory.
class _HiddenParentApi implements WikiTreeApi {
  static const Person _father = Person(
    id: 1,
    wikiTreeId: 'Nakarada-1',
    firstName: 'Radivoje',
    lastNameAtBirth: 'Nakarada',
    birthDate: '1930-00-00',
  );

  static const Person _son = Person(
    id: 2,
    wikiTreeId: 'Nakarada-Kordic-1',
    firstName: 'Dejan',
    lastNameAtBirth: 'Nakarada-Kordic',
    birthDate: '1960-00-00',
  );

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async =>
      const PeopleResponse(people: <Person>[_father, _son], resolvedId: 1);

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{
    for (final key in keys)
      key: key == 'Nakarada-1' ? const <int>[2] : const <int>[],
  };

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// A family with one recorded generation above, which growth brings in.
class _DeepApi implements WikiTreeApi {
  int lastAncestors = 0;
  int coneRequests = 0;

  static const Person _abraham = Person(
    id: 3,
    wikiTreeId: 'Einstein-3',
    firstName: 'Abraham',
    lastNameAtBirth: 'Einstein',
  );

  static const Person _hermann = Person(
    id: 2,
    wikiTreeId: 'Einstein-2',
    firstName: 'Hermann',
    lastNameAtBirth: 'Einstein',
    birthDate: '1847-08-30',
    fatherId: 3,
  );

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    lastAncestors = ancestors;
    coneRequests++;
    // The first answer is the tree; a later one is a tap on "more", which is
    // asked for from the top row and is where Abraham turns up.
    if (coneRequests > 1) {
      return const PeopleResponse(
        people: <Person>[_hermann, _abraham],
        resolvedId: 2,
      );
    }
    return const PeopleResponse(
      people: <Person>[_FamilyApi._albert, _hermann],
      resolvedId: 1,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{for (final key in keys) key: const <int>[]};

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// A family with one recorded generation below, which growth brings in.
class _BranchApi implements WikiTreeApi {
  int lastDescendants = 0;
  int coneRequests = 0;

  static const Person _hans = Person(
    id: 4,
    wikiTreeId: 'Einstein-4',
    firstName: 'Hans Albert',
    lastNameAtBirth: 'Einstein',
    birthDate: '1904-05-14',
    fatherId: 1,
  );

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    lastDescendants = descendants;
    coneRequests++;
    // The first answer is the tree; a later one is a tap on "more", asked for from
    // the bottom row, and that is where Hans Albert turns up.
    if (coneRequests > 1) {
      return const PeopleResponse(
        people: <Person>[_FamilyApi._hermann, _hans],
        resolvedId: 2,
      );
    }
    return const PeopleResponse(
      people: <Person>[_FamilyApi._albert, _FamilyApi._hermann],
      resolvedId: 1,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{
    for (final key in keys)
      key: key == 'Einstein-1' ? const <int>[4] : const <int>[],
  };

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// A focus with no children of its own and a sibling who has them.
///
/// The sibling sits on the focus row, so a probe of "everybody on the bottom
/// row" counts the sibling's children as descendants of the person this tree is
/// about - and growing the tree never shows them.
class _SiblingApi implements WikiTreeApi {
  static const Person _focus = Person(
    id: 1,
    wikiTreeId: 'Tesla-1',
    firstName: 'Nikola',
    lastNameAtBirth: 'Tesla',
    fatherId: 2,
  );

  static const Person _father = Person(
    id: 2,
    wikiTreeId: 'Tesla-2',
    firstName: 'Milutin',
    lastNameAtBirth: 'Tesla',
  );

  static const Person _sister = Person(
    id: 3,
    wikiTreeId: 'Tesla-3',
    firstName: 'Milka',
    lastNameAtBirth: 'Tesla',
    fatherId: 2,
  );

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async => const PeopleResponse(
    people: <Person>[_focus, _father, _sister],
    resolvedId: 1,
  );

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{
    for (final key in keys)
      key: key == 'Tesla-3' ? const <int>[4] : const <int>[],
  };

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// A single line of descendants, long enough to need several taps to reach the end.
class _LongLineApi implements WikiTreeApi {
  static const Person _focus = Person(id: 1, wikiTreeId: 'Line-1');

  static const Person _first = Person(
    id: 10,
    wikiTreeId: 'Line-10',
    fatherId: 1,
  );

  static const Person _second = Person(
    id: 11,
    wikiTreeId: 'Line-11',
    fatherId: 10,
  );

  static const Person _third = Person(
    id: 12,
    wikiTreeId: 'Line-12',
    fatherId: 11,
  );

  static const Person _fourth = Person(
    id: 13,
    wikiTreeId: 'Line-13',
    fatherId: 12,
  );

  static const Person _fifth = Person(
    id: 14,
    wikiTreeId: 'Line-14',
    fatherId: 13,
  );

  static const Person _sixth = Person(
    id: 15,
    wikiTreeId: 'Line-15',
    fatherId: 14,
  );

  /// Never drawn: this is the one person waiting below the depth limit.
  static const Person _seventh = Person(
    id: 16,
    wikiTreeId: 'Line-16',
    fatherId: 15,
  );

  int lastDescendants = 0;

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    lastDescendants = descendants;
    return const PeopleResponse(
      people: <Person>[
        _focus,
        _first,
        _second,
        _third,
        _fourth,
        _fifth,
        _sixth,
        _seventh,
      ],
      resolvedId: 1,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{
    for (final key in keys)
      key: switch (key) {
        'Line-10' => const <int>[11],
        'Line-11' => const <int>[12],
        'Line-12' => const <int>[13],
        'Line-13' => const <int>[14],
        'Line-14' => const <int>[15],
        'Line-15' => const <int>[16],
        _ => const <int>[],
      },
  };

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// A living family: WikiTree will not list a private profile's children, so this
/// fake behaves like the API does for somebody's own profile - the probe is
/// silent and the answer has to come from asking for the generation itself.
class _PrivateApi implements WikiTreeApi {
  static const Person _focus = Person(
    id: 1,
    wikiTreeId: 'Living-1',
    firstName: 'Robin',
    lastNameAtBirth: 'Reader',
    isLiving: true,
    privacy: 40,
    privacyIsPrivate: true,
  );

  static const Person _childA = Person(
    id: 2,
    wikiTreeId: 'Living-2',
    firstName: 'Sam',
    lastNameAtBirth: 'Reader',
    isLiving: true,
    privacy: 40,
    fatherId: 1,
  );

  static const Person _childB = Person(
    id: 3,
    wikiTreeId: 'Living-3',
    firstName: 'Alex',
    lastNameAtBirth: 'Reader',
    isLiving: true,
    privacy: 40,
    fatherId: 1,
  );

  /// Who the "one generation below" request was pointed at.
  String? askedBelow;

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    if (!key.contains(',')) {
      // The usual "show me this person's family" request.
      return PeopleResponse(
        people: const <Person>[_focus, _childA, _childB],
        resolvedId: _focus.id,
      );
    }
    // One generation below the two children: nobody.
    askedBelow = key;
    return PeopleResponse(
      people: const <Person>[_childA, _childB],
      resolvedId: _childA.id,
    );
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async => const RelativesResponse(groups: <RelativeGroup>[]);

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async => <String, List<int>?>{for (final key in keys) key: null};

  @override
  void invalidate() {}

  @override
  void close() {}
}

/// Preferences that live in memory, with the tree hints already seen unless a
/// test says otherwise, so the existing tests keep seeing a plain tree.
class _Prefs implements AppPreferences {
  _Prefs({String? storedCode, this.treeTipsSeen = true, List<String>? recent})
    : storedCode = storedCode,
      recent = recent ?? <String>[?storedCode];

  String? storedCode;
  bool treeTipsSeen;
  List<String> recent;

  @override
  Future<String?> lastCode() async => storedCode;

  @override
  Future<void> rememberCode(String code) async {
    storedCode = code;
    recent = <String>[
      code,
      ...recent.where(
        (existing) => existing.toLowerCase() != code.toLowerCase(),
      ),
    ].take(AppPreferences.maxRecentCodes).toList(growable: false);
  }

  @override
  Future<List<String>> recentCodes() async => recent;

  @override
  Future<bool> hasSeenTreeTips() async => treeTipsSeen;

  @override
  Future<void> markTreeTipsSeen() async => treeTipsSeen = true;
}

Widget _app({_Prefs? preferences}) => WikiTreeViewerApp(
  repository: WikiTreeRepository(api: _EmptyApi()),
  preferences: preferences ?? _Prefs(),
);

/// What the family-code box currently holds.
String _fieldText(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byType(TextField));
  return field.controller?.text ?? '';
}

/// The Android back button, as the platform delivers it.
///
/// The tree screen has an arrow in the corner as well, but it steps back through
/// the people visited rather than out of the screen, so a test that presses it
/// would not be testing what the platform's back button does - `PopScope` is what
/// the platform back goes through.
Future<void> _pressSystemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _openTree(
  WidgetTester tester, {
  WikiTreeApi? api,
  Stream<String>? links,
  _Prefs? preferences,
}) async {
  await tester.pumpWidget(
    WikiTreeViewerApp(
      repository: WikiTreeRepository(api: api ?? _FamilyApi()),
      preferences: preferences ?? _Prefs(),
      links: links,
    ),
  );
  await tester.enterText(find.byType(TextField), AppInfo.exampleKey);
  await tester.tap(find.text('Show family tree'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the lookup screen', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('WikiTree Viewer'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Show family tree'), findsOneWidget);
    expect(find.text('Paste a link'), findsOneWidget);
    // "Try" and "or" are labels, and only the codes are buttons: the pair reads
    // as something to press rather than as a sentence.
    expect(find.text('Try'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('lookup-example-Windsor-1')),
      findsOneWidget,
    );
    // A second example, so the pair reads as "codes look like this" instead of
    // "this is the only family the app can open".
    expect(
      find.byKey(const ValueKey<String>('lookup-example-Kennedy-96')),
      findsOneWidget,
    );
    // The field used to carry a helper line repeating what the buttons say.
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.helperText,
      isNull,
    );
  });

  testWidgets('an example code is one tap to a tree', (tester) async {
    await tester.pumpWidget(
      WikiTreeViewerApp(
        repository: WikiTreeRepository(api: _FamilyApi()),
        preferences: _Prefs(),
      ),
    );

    // The whole code is the button, so the tap target is the code itself rather
    // than a word in front of it. It sits under the buttons, below the fold of
    // the test surface, so it has to be scrolled into view first.
    final example = find.byKey(
      const ValueKey<String>('lookup-example-Windsor-1'),
    );
    await tester.ensureVisible(example);
    await tester.pumpAndSettle();
    await tester.tap(example);
    await tester.pumpAndSettle();

    expect(find.byType(TreeView), findsOneWidget);
  });

  testWidgets('the insert keys put a hyphen or an underscore in the box', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    // They belong to the box: no keyboard, no keys, no clutter.
    expect(
      find.byKey(const ValueKey<String>('lookup-insert-hyphen')),
      findsNothing,
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('lookup-insert-hyphen')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Windsor');
    await tester.pumpAndSettle();

    // A hyphen is two taps on iOS (123, then -) and on Gboard (symbols page); this
    // is one, and the keyboard stays open for the number. The press is held for a
    // frame on purpose: a real finger (and every mouse) takes longer than that, and
    // the field used to treat the press as "outside", drop the keyboard and take
    // the key away before it ever fired.
    final hyphen = find.byKey(const ValueKey<String>('lookup-insert-hyphen'));
    await tester.ensureVisible(hyphen);
    final press = await tester.startGesture(tester.getCenter(hyphen));
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'Windsor-');
    expect(
      hyphen,
      findsOneWidget,
      reason: 'the keys stay while the box has focus',
    );

    final underscore = find.byKey(
      const ValueKey<String>('lookup-insert-underscore'),
    );
    await tester.ensureVisible(underscore);
    await tester.tap(underscore);
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'Windsor-_');
  });

  testWidgets('explains input that contains no WikiTree ID', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextField), 'definitely not a code');
    await tester.tap(find.text('Show family tree'));
    await tester.pump();

    expect(find.textContaining("couldn't find a WikiTree ID"), findsOneWidget);
  });

  testWidgets('opens the keyboard on tap, closes it on submit, opens it again', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    // 1. Tapping the box asks the platform for the keyboard.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );

    // 2. Tapping the button is "I'm done typing": keyboard away, message shown.
    await tester.tap(find.text('Show family tree'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Enter a WikiTree ID or a profile link.'), findsOneWidget);

    // 3. ...and tapping the box again brings it straight back.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('the box stays editable after a failed lookup', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextField), 'definitely not a code');
    await tester.tap(find.text('Show family tree'));
    await tester.pump();
    expect(find.textContaining("couldn't find a WikiTree ID"), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isNot(false),
    );
  });

  testWidgets('accepts a full WikiTree URL as input', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(
      find.byType(TextField),
      'https://www.wikitree.com/wiki/Nobody-1',
    );
    await tester.tap(find.text('Show family tree'));
    await tester.pump();

    // The parser accepted it, so the failure comes from the (empty) fake API.
    expect(find.textContaining("couldn't find that person"), findsOneWidget);
  });

  testWidgets('opens the family tree after a successful lookup', (
    tester,
  ) async {
    await _openTree(tester);

    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Albert Einstein'), findsOneWidget);
    expect(find.byKey(TreeView.nodeKey(1)), findsOneWidget);
    expect(find.byKey(TreeView.nodeKey(2)), findsOneWidget);
  });

  testWidgets('tapping a person makes them the middle of the tree', (
    tester,
  ) async {
    await _openTree(tester);

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();

    expect(find.text('Hermann Einstein'), findsOneWidget);
  });

  testWidgets('long-pressing a person opens their details', (tester) async {
    await _openTree(tester);

    await tester.longPress(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();

    expect(find.byType(PersonSummaryScreen), findsOneWidget);
    expect(find.text('Born'), findsOneWidget);
  });

  testWidgets('back returns to the person before, then leaves the tree', (
    tester,
  ) async {
    await _openTree(tester);
    expect(find.text('Albert Einstein'), findsOneWidget);

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('Hermann Einstein'), findsOneWidget);

    // Back is a step in the walk through the family, not the way out.
    await _pressSystemBack(tester);
    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Albert Einstein'), findsOneWidget);

    // With nowhere left to go back to, it leaves the tree.
    await _pressSystemBack(tester);
    expect(find.text('Show family tree'), findsOneWidget);
  });

  testWidgets('a son whose record hides his father is drawn under him', (
    tester,
  ) async {
    // The probe is what learns the link, so the shape that used to leave a
    // permanent "1 more" is the same one that now draws the son.
    await _openTree(tester, api: _HiddenParentApi());

    expect(find.text('Radivoje Nakarada'), findsOneWidget);
    expect(find.byKey(TreeView.nodeKey(2)), findsOneWidget);
    expect(find.text('1 more'), findsNothing);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('hides both buttons when there is nobody left either way', (
    tester,
  ) async {
    await _openTree(tester);

    expect(
      find.byKey(const ValueKey<String>('tree-more-ancestors')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tree-more-descendants')),
      findsNothing,
    );
  });

  testWidgets('offers a count above and loads that generation', (tester) async {
    final api = _DeepApi();
    await _openTree(tester, api: api);

    final pill = find.byKey(const ValueKey<String>('tree-more-ancestors'));
    expect(pill, findsOneWidget);
    expect(find.text('1 more'), findsOneWidget);

    // It belongs at the top of the screen, not the bottom.
    expect(tester.getCenter(pill).dy, lessThan(200));

    await tester.tap(pill);
    await tester.pumpAndSettle();

    expect(
      api.lastAncestors,
      ApiConfig.growthStep,
      reason: 'the tap asks for two generations beyond the top row',
    );
    expect(find.byKey(TreeView.nodeKey(3)), findsOneWidget);
    expect(pill, findsNothing);
  });

  testWidgets('keeps the button off a private family with nobody below', (
    tester,
  ) async {
    final api = _PrivateApi();
    await _openTree(tester, api: api);

    // Two children on screen, no grandchildren. The probe cannot see through a
    // private profile, so the app asks for one generation and finds nobody -
    // and no button is offered.
    expect(find.byKey(TreeView.nodeKey(2)), findsOneWidget);
    expect(find.byKey(TreeView.nodeKey(3)), findsOneWidget);
    expect(api.askedBelow, isNotNull);
    expect(
      find.byKey(const ValueKey<String>('tree-more-descendants')),
      findsNothing,
    );
  });

  testWidgets('capitalises a family code while it is typed', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextField), 'einstein-1');
    await tester.pump();

    // WikiTree IDs are case sensitive, so the field helps with the capitals.
    expect(_fieldText(tester), 'Einstein-1');
  });

  testWidgets('leaves a pasted link exactly as it is', (tester) async {
    await tester.pumpWidget(_app());

    const link = 'https://www.wikitree.com/wiki/einstein-1';
    await tester.enterText(find.byType(TextField), link);
    await tester.pump();

    expect(_fieldText(tester), link);
  });

  testWidgets('the app icon greets you on the first screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The screen shows the icon itself, not the source artwork: one image, and
    // it is the asset the launcher and the store use.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, AppInfo.appIconAsset);
  });

  test('the app icon ships with the app', () async {
    final data = await rootBundle.load(AppInfo.appIconAsset);
    expect(data.lengthInBytes, greaterThan(1000));

    // It has to decode as well as exist: a truncated or wrongly exported file
    // would only show up as a broken first screen.
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThanOrEqualTo(512));
  });

  testWidgets('the app speaks the language the device is set to', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = <Locale>[const Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Stammbaum anzeigen'), findsOneWidget);
    expect(find.text('Familiencode oder Link'), findsOneWidget);
    expect(find.text('Show family tree'), findsNothing);
  });

  testWidgets('an unsupported device language falls back to English', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = <Locale>[const Locale('it')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Show family tree'), findsOneWidget);
  });

  testWidgets('the first screen offers examples in the device language', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = <Locale>[const Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // A German reader is offered Goethe rather than an English royal family, and
    // the pair still shows what a code looks like.
    expect(
      find.byKey(const ValueKey<String>('lookup-example-Goethe-22')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lookup-example-Van_Beethoven-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lookup-example-Windsor-1')),
      findsNothing,
    );
  });

  testWidgets(
    'the Serbian first screen speaks Serbian and shows Serbian codes',
    (tester) async {
      tester.platformDispatcher.localesTestValue = <Locale>[const Locale('sr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Prikaži porodično stablo'), findsOneWidget);
      expect(find.text('Probajte'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lookup-example-Karađorđević-13')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lookup-example-Tesla-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('every Serbian script setting gets the Serbian wording', (
    tester,
  ) async {
    // Both Serbian tags are declared to Android and iOS (`sr` and `sr-Latn`), and
    // a phone in Serbia usually reports `sr` or `sr-RS`. They all have to reach
    // app_sr.arb - one translation, Latin script - instead of falling back to
    // English, which is the whole reason both tags are declared.
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    for (final locale in <Locale>[
      const Locale('sr'),
      const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl'),
      const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
      const Locale.fromSubtags(languageCode: 'sr', countryCode: 'RS'),
    ]) {
      tester.platformDispatcher.localesTestValue = <Locale>[locale];

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(
        find.text('Prikaži porodično stablo'),
        findsOneWidget,
        reason: '$locale',
      );
      expect(
        find.byKey(const ValueKey<String>('lookup-example-Karađorđević-13')),
        findsOneWidget,
        reason: '$locale',
      );
      expect(find.text('Show family tree'), findsNothing, reason: '$locale');
    }
  });

  testWidgets('a code that is not found suggests checking it', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextField), 'Nobody-1');
    await tester.tap(find.text('Show family tree'));
    await tester.pump();

    // The API accepts an all-lowercase surname, so the message no longer claims
    // that capitals are the problem - it says what to do instead.
    expect(find.textContaining('Check the code'), findsOneWidget);
  });

  testWidgets('a shared link opens that family', (tester) async {
    final links = StreamController<String>.broadcast();
    addTearDown(links.close);

    await tester.pumpWidget(
      WikiTreeViewerApp(
        repository: WikiTreeRepository(api: _FamilyApi()),
        preferences: _Prefs(),
        links: links.stream,
      ),
    );

    links.add('Einstein-1');
    await tester.pumpAndSettle();

    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Albert Einstein'), findsOneWidget);
  });

  testWidgets('a link that started the app opens that family', (tester) async {
    // What main() sees on a cold start: the link is known before the first
    // widget exists, so it has to be held until the lookup screen is listening.
    final inbox = LinkInbox();
    addTearDown(inbox.close);
    inbox.add('Einstein-1');

    await tester.pumpWidget(
      WikiTreeViewerApp(
        repository: WikiTreeRepository(api: _FamilyApi()),
        preferences: _Prefs(),
        links: inbox.keys,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Albert Einstein'), findsOneWidget);
  });

  testWidgets('a route pushed by the platform cannot crash the app', (
    tester,
  ) async {
    // What Android did to 1.0.5: the engine hands the link to the framework,
    // Flutter's own deep-link handler pushes the URI's path as a route *name*, no
    // route matches, and `onUnknownRoute!` in the framework is a real null check
    // in a release build. Three devices reported it.
    await tester.pumpWidget(_app());

    await tester.binding.handlePushRoute(
      'https://under3415.github.io/wikitree-viewer/open/?id=Einstein-1',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The fallback is the first screen, so the reader can still paste the code.
    expect(find.text('Show family tree'), findsWidgets);
    expect(find.byType(TreeView), findsNothing);
  });

  testWidgets('the share sheet copies everything a reader needs', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _openTree(tester);
    await tester.tap(find.byKey(const ValueKey<String>('tree-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('tree-share-copy')));
    await tester.pumpAndSettle();

    expect(
      copied,
      contains("View Albert Einstein's (1879–1955) family tree in"),
    );
    // One https link, because that is the only kind the places people paste
    // into turn into something tappable.
    expect(copied, contains(DeepLink.forKey('Einstein-1')));
    expect(copied, contains(AppInfo.installUrl));
    expect(copied, isNot(contains('www.wikitree.com/wiki')));
    expect(copied, isNot(contains('wikitreeviewer://')));
    expect(find.textContaining('Link copied'), findsOneWidget);
  });

  testWidgets('the share button stays clear of the system navigation bar', (
    tester,
  ) async {
    // Android draws the tree behind the navigation bar, so the screen has to
    // keep its bottom controls above the inset instead of 12 pixels above the
    // window, which is where they used to sit.
    const navBar = 48.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);

    await _openTree(tester);

    final share = tester.getRect(
      find.byKey(const ValueKey<String>('tree-share')),
    );
    expect(share.bottom, 600 - navBar);
    // Wide open space on the right is where the "more descendants" control
    // goes, so the row has to reach the edges.
    expect(share.left, 12);
  });

  testWidgets('refresh shows an edit made while the tree was open', (
    tester,
  ) async {
    // The session cache is deliberately warm for the whole run of the app, so an
    // edit somebody else makes to the profile on screen stays invisible until the
    // app is restarted. The refresh button is the way out of that.
    final api = _EditingApi();
    await _openTree(tester, api: api);
    expect(find.text('Albert Einstein'), findsOneWidget);
    expect(find.text('Albertus Einstein'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('tree-refresh')));
    await tester.pumpAndSettle();

    expect(api.invalidations, 1);
    expect(find.text('Albertus Einstein'), findsOneWidget);
    expect(find.text('Updated from WikiTree'), findsOneWidget);
  });

  testWidgets('the refresh button rests for half a minute', (tester) async {
    final api = _EditingApi();
    await _openTree(tester, api: api);
    final refresh = find.byKey(const ValueKey<String>('tree-refresh'));
    expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);

    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);

    // One second short of the wait that keeps the button from becoming polling.
    await tester.pump(ApiConfig.refreshCooldown - const Duration(seconds: 1));
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);

    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(api.invalidations, 2, reason: 'the wait is over, so it asks again');
  });

  testWidgets('a refresh starts the walk through the family again', (
    tester,
  ) async {
    final api = _EditingApi();
    await _openTree(tester, api: api);
    final back = find.byKey(const ValueKey<String>('tree-back'));

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(back).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey<String>('tree-refresh')));
    await tester.pumpAndSettle();

    // The people the walk had visited went with the discarded graph, so there is
    // nowhere to step back to - the state a restart leaves.
    expect(tester.widget<IconButton>(back).onPressed, isNull);
    expect(find.text('Hermann Einstein'), findsOneWidget);
    expect(api.invalidations, 1);
  });

  testWidgets('the tree hints explain the gestures on the first tree only', (
    tester,
  ) async {
    final preferences = _Prefs(treeTipsSeen: false);
    await _openTree(tester, preferences: preferences);

    expect(find.text('Using the tree'), findsOneWidget);
    expect(find.text('Drag with one finger to move around'), findsOneWidget);
    expect(find.text('Pinch or spread two fingers to zoom'), findsOneWidget);
    expect(
      find.text('Tap a person to make them the middle of the tree'),
      findsOneWidget,
    );
    expect(
      find.text('Press and hold a person for their details'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('tree-tips-dismiss')));
    await tester.pumpAndSettle();

    expect(find.text('Using the tree'), findsNothing);
    expect(preferences.treeTipsSeen, isTrue);

    // Away and back in: they have done their job and stay away.
    await _pressSystemBack(tester);
    await tester.tap(find.text('Show family tree'));
    await tester.pumpAndSettle();

    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Using the tree'), findsNothing);
  });

  testWidgets('the clear button empties the code box', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'Einstein-1');
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('lookup-clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('lookup-clear')));
    await tester.pump();

    expect(_fieldText(tester), isEmpty);
    // With nothing left to clear, the button goes away too.
    expect(find.byKey(const ValueKey<String>('lookup-clear')), findsNothing);
  });

  testWidgets('the last family opened is waiting in the box next time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(preferences: _Prefs(storedCode: 'Kennedy-96')),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester), 'Kennedy-96');
    // Ready to go one tap later, with the cursor after the code.
    expect(find.text('Show family tree'), findsOneWidget);
  });

  testWidgets('offers the families opened before while a code is typed', (
    tester,
  ) async {
    final preferences = _Prefs(
      recent: <String>['Kennedy-96', 'Einstein-1', 'Marić-75'],
    );
    await tester.pumpWidget(
      WikiTreeViewerApp(
        repository: WikiTreeRepository(api: _FamilyApi()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    // An empty box gets no list: that would be a menu, not a suggestion.
    expect(find.text('Recently opened'), findsNothing);

    await tester.enterText(find.byType(TextField), 'mar');
    await tester.pump();

    expect(find.text('Recently opened'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('lookup-suggestion-Marić-75')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lookup-suggestion-Einstein-1')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('lookup-suggestion-Marić-75')),
    );
    await tester.pumpAndSettle();

    // Tapping opens the family - one tap, which is what the suggestion is for -
    // and the canonical code is what gets remembered.
    expect(find.byType(TreeView), findsOneWidget);
    expect(preferences.storedCode, 'Einstein-1');
  });

  testWidgets('offers nothing that is already in the box in full', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(preferences: _Prefs(storedCode: 'Kennedy-96')),
    );
    await tester.pumpAndSettle();

    // The box holds the whole code, and the button underneath already opens it.
    expect(find.text('Recently opened'), findsNothing);
  });

  testWidgets('opening a tree remembers the code that worked', (tester) async {
    final preferences = _Prefs();
    await _openTree(tester, preferences: preferences);

    expect(preferences.storedCode, 'Einstein-1');
    // And it is offered next time, without waiting for a restart.
    expect(preferences.recent, <String>['Einstein-1']);
  });

  testWidgets('a code that did not open keeps the remembered one', (
    tester,
  ) async {
    final preferences = _Prefs(storedCode: 'Kennedy-96');
    await tester.pumpWidget(_app(preferences: preferences));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Unknown-9');
    await tester.tap(find.text('Show family tree'));
    await tester.pumpAndSettle();

    expect(preferences.storedCode, 'Kennedy-96');
  });

  testWidgets('opens a person whose code has letters outside A-Z', (
    tester,
  ) async {
    // Mileva Marić is Marić-75 on WikiTree, and asking for ASCII only turned
    // tapping her into "that is not a WikiTree ID".
    await tester.pumpWidget(
      WikiTreeViewerApp(
        repository: WikiTreeRepository(api: _FamilyApi()),
        preferences: _Prefs(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Marić-75');
    await tester.tap(find.text('Show family tree'));
    await tester.pumpAndSettle();

    expect(find.byType(TreeView), findsOneWidget);
    expect(find.textContaining("couldn't find a WikiTree ID"), findsNothing);
  });

  testWidgets('X leaves the tree from wherever the walk is', (tester) async {
    await _openTree(tester);
    // The way out is always there - unlike the home button it replaces, which
    // only appeared once the walk had started.
    expect(find.byKey(const ValueKey<String>('tree-close')), findsOneWidget);

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('Hermann Einstein'), findsOneWidget);

    // One tap out, ignoring the trail behind it: stepping back through the
    // people already visited is what the back button is for.
    await tester.tap(find.byKey(const ValueKey<String>('tree-close')));
    await tester.pumpAndSettle();

    expect(find.text('Show family tree'), findsOneWidget);
    expect(find.byType(TreeView), findsNothing);
  });

  testWidgets('the arrow beside the X steps back through the walk', (
    tester,
  ) async {
    await _openTree(tester);

    // The corner holds both buttons on the first person too, so it never shifts:
    // the arrow is greyed out because there is nothing behind this person.
    final back = find.byKey(const ValueKey<String>('tree-back'));
    final close = find.byKey(const ValueKey<String>('tree-close'));
    expect(back, findsOneWidget);
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    // X on the left, the arrow to its right, as the corner reads.
    expect(tester.getCenter(close).dx, lessThan(tester.getCenter(back).dx));

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('Hermann Einstein'), findsOneWidget);
    expect(tester.widget<IconButton>(back).onPressed, isNotNull);

    // One step back, on screen, where iOS has no system back button to offer.
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Albert Einstein'), findsOneWidget);
    expect(find.byType(TreeView), findsOneWidget);
    expect(tester.widget<IconButton>(back).onPressed, isNull);
  });

  testWidgets('does not promise the children of brothers and sisters', (
    tester,
  ) async {
    await _openTree(tester, api: _SiblingApi());

    // The sister in the middle row has a child. It is not a descendant of the
    // person this tree is about, so growing the tree could never show it: a
    // button here is a promise the app cannot keep (Tesla-1 used to say "2 more"
    // and add nothing).
    expect(
      find.byKey(const ValueKey<String>('tree-more-descendants')),
      findsNothing,
    );
  });

  testWidgets('keeps growing until the line itself ends', (tester) async {
    final api = _LongLineApi();
    await _openTree(tester, api: api);

    final pill = find.byKey(const ValueKey<String>('tree-more-descendants'));
    expect(find.text('1 more'), findsOneWidget);

    // Two generations per tap and no ceiling: the pill stays as long as somebody
    // is below it (Habsburg-32 has more than six generations of them).
    var taps = 0;
    while (pill.evaluate().isNotEmpty && taps < 10) {
      await tester.tap(pill);
      await tester.pumpAndSettle();
      taps++;
    }

    expect(
      taps,
      3,
      reason: 'depth 2 -> 4 -> 6 -> 8, one tap per two generations',
    );
    // The last person in the line is on screen, so the tree reached the end of it
    // rather than a limit: nobody is left stuck above people they cannot see.
    expect(find.byKey(TreeView.nodeKey(16)), findsOneWidget);
    expect(pill, findsNothing);
  });

  testWidgets('offers a count below, on the right, and loads it', (
    tester,
  ) async {
    final api = _BranchApi();
    await _openTree(tester, api: api);

    final pill = find.byKey(const ValueKey<String>('tree-more-descendants'));
    expect(pill, findsOneWidget);
    expect(find.text('1 more'), findsOneWidget);

    // Both growth buttons live on the right; the share button does not.
    final centre = tester.getCenter(pill);
    expect(centre.dx, greaterThan(400));
    expect(centre.dy, greaterThan(300));
    expect(
      tester.getCenter(find.byKey(const ValueKey<String>('tree-share'))).dx,
      lessThan(400),
    );

    await tester.tap(pill);
    await tester.pumpAndSettle();

    expect(
      api.lastDescendants,
      ApiConfig.growthStep,
      reason: 'the tap asks for two generations beyond the bottom row',
    );
    expect(find.byKey(TreeView.nodeKey(4)), findsOneWidget);
    // The new bottom row has nobody below it, so the button is gone.
    expect(pill, findsNothing);
  });
}
