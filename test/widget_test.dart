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
  void close() {}
}

/// A family with one recorded generation above that is only returned when the
/// caller asks for four generations.
class _DeepApi implements WikiTreeApi {
  int lastAncestors = 0;

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
    return PeopleResponse(
      people: <Person>[
        _FamilyApi._albert,
        _hermann,
        if (ancestors >= 4) _abraham,
      ],
      resolvedId: _FamilyApi._albert.id,
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

/// A family with one recorded generation below that is only returned when the
/// caller asks for three generations down.
class _BranchApi implements WikiTreeApi {
  int lastDescendants = 0;

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
    return PeopleResponse(
      people: <Person>[
        _FamilyApi._albert,
        _FamilyApi._hermann,
        if (descendants >= 3) _hans,
      ],
      resolvedId: _FamilyApi._albert.id,
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
    expect(find.text('Try Einstein-1'), findsOneWidget);
    // A second example, so the pair reads as "codes look like this" instead of
    // "this is the only family the app can open".
    expect(find.text('or Kennedy-96'), findsOneWidget);
    // The field used to carry a helper line repeating what the buttons say.
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.helperText,
      isNull,
    );
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
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TreeView), findsOneWidget);
    expect(find.text('Albert Einstein'), findsOneWidget);

    // With nowhere left to go back to, it leaves the tree.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Show family tree'), findsOneWidget);
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

    expect(api.lastAncestors, 4);
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
    await tester.pageBack();
    await tester.pumpAndSettle();
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

  testWidgets('home returns to the starting person in one tap', (tester) async {
    await _openTree(tester);
    expect(find.byKey(const ValueKey<String>('tree-home')), findsNothing);

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('Hermann Einstein'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('tree-home')));
    await tester.pumpAndSettle();

    expect(find.text('Albert Einstein'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tree-home')), findsNothing);

    // The trail is gone, so back leaves the tree rather than walking it again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Show family tree'), findsOneWidget);
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

    expect(api.lastDescendants, 3);
    expect(find.byKey(TreeView.nodeKey(4)), findsOneWidget);
    // The new bottom row has nobody below it, so the button is gone.
    expect(pill, findsNothing);
  });
}
