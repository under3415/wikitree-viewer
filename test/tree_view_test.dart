import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wikitree_viewer/data/family_graph.dart';
import 'package:wikitree_viewer/data/person.dart';
import 'package:wikitree_viewer/data/wikitree_repository.dart';
import 'package:wikitree_viewer/l10n/app_localizations.dart';
import 'package:wikitree_viewer/ui/theme/app_theme.dart';
import 'package:wikitree_viewer/ui/tree/tree_layout.dart';
import 'package:wikitree_viewer/ui/tree/tree_view.dart';
import 'package:wikitree_viewer/ui/widgets/photo_avatar.dart';

Person _person(int id, {int? father, int? mother, String? birth}) => Person(
  id: id,
  wikiTreeId: 'Test-$id',
  firstName: 'First$id',
  lastNameAtBirth: 'Test',
  birthDate: birth,
  fatherId: father,
  motherId: mother,
);

/// Focus 1, parents 2 and 3, child 4, wife 5 and ex-wife 6.
FocusBundle _bundle() {
  final graph = FamilyGraph()
    ..addAll(<Person>[
      _person(1, father: 2, mother: 3, birth: '1950-01-01'),
      _person(2, birth: '1920-01-01'),
      _person(3, birth: '1922-01-01'),
      _person(4, father: 1, birth: '1975-01-01'),
      _person(5, birth: '1952-01-01'),
      _person(6, birth: '1970-01-01'),
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

TreeLayout _layout() => const TreeLayoutBuilder().build(_bundle());

Widget _host(
  TreeLayout layout, {
  ValueChanged<Person>? onTap,
  ValueChanged<Person>? onLongPress,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TreeView(
        layout: layout,
        onPersonTap: onTap,
        onPersonLongPress: onLongPress,
      ),
    ),
  );
}

/// The test surface is 800 x 600, so its middle is (400, 300).
const Offset _middle = Offset(400, 300);

Matrix4 _matrix(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

Offset _toScreen(Matrix4 matrix, Offset scene) =>
    MatrixUtils.transformPoint(matrix, scene);

void main() {
  testWidgets('opens centred on the focus person', (tester) async {
    final layout = _layout();
    await tester.pumpWidget(_host(layout));
    await tester.pumpAndSettle();

    final onScreen = _toScreen(_matrix(tester), layout.focusRect.center);

    expect(onScreen.dx, closeTo(_middle.dx, 0.5));
    expect(onScreen.dy, closeTo(_middle.dy, 0.5));
  });

  testWidgets('tapping a person reports them', (tester) async {
    final layout = _layout();
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(layout, onTap: (person) => tapped.add(person.id)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TreeView.nodeKey(2)));
    await tester.pumpAndSettle();

    expect(tapped, <int>[2]);
  });

  testWidgets('long-pressing a person reports them', (tester) async {
    final layout = _layout();
    final held = <int>[];
    await tester.pumpWidget(
      _host(layout, onLongPress: (person) => held.add(person.id)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(TreeView.nodeKey(3)));
    await tester.pumpAndSettle();

    expect(held, <int>[3]);
  });

  testWidgets('shows a photo slot for every person', (tester) async {
    final layout = _layout();
    await tester.pumpWidget(_host(layout));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoAvatar), findsNWidgets(layout.nodes.length));
  });

  testWidgets('each box describes its person for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(_layout()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('First1 Test')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('middle of the tree')), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('pinching apart zooms the tree in', (tester) async {
    await tester.pumpWidget(_host(_layout()));
    await tester.pumpAndSettle();

    final before = _matrix(tester).getMaxScaleOnAxis();

    // Two fingers moving apart, which is how a phone user zooms.
    final left = await tester.startGesture(const Offset(360, 260));
    final right = await tester.startGesture(const Offset(440, 340));
    await tester.pump();
    await left.moveBy(const Offset(-70, -70));
    await right.moveBy(const Offset(70, 70));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();

    expect(_matrix(tester).getMaxScaleOnAxis(), greaterThan(before));
  });

  testWidgets('a wild drag cannot lose the tree', (tester) async {
    final layout = _layout();
    await tester.pumpWidget(_host(layout));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 4000));
    await tester.pumpAndSettle();

    final onScreen = _toScreen(_matrix(tester), layout.focusRect.center);
    expect(onScreen.dx, inInclusiveRange(0, 800));
    expect(onScreen.dy, inInclusiveRange(0, 600));
  });

  testWidgets('does not re-centre after the user has panned', (tester) async {
    final layout = _layout();
    await tester.pumpWidget(_host(layout));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(InteractiveViewer), const Offset(-90, -70));
    await tester.pumpAndSettle();
    final panned = _matrix(tester).getTranslation();

    // The same layout arrives again, as it does on any parent rebuild.
    await tester.pumpWidget(_host(layout));
    await tester.pumpAndSettle();

    final after = _matrix(tester).getTranslation();
    expect(after.x, closeTo(panned.x, 0.5));
    expect(after.y, closeTo(panned.y, 0.5));
  });

  testWidgets('a new layout centres the new focus', (tester) async {
    await tester.pumpWidget(_host(_layout()));
    await tester.pumpAndSettle();

    final other = const TreeLayoutBuilder().build(_bundle());
    await tester.pumpWidget(_host(other));
    await tester.pumpAndSettle();

    final onScreen = _toScreen(_matrix(tester), other.focusRect.center);
    expect(onScreen.dx, closeTo(_middle.dx, 0.5));
    expect(onScreen.dy, closeTo(_middle.dy, 0.5));
  });
}
