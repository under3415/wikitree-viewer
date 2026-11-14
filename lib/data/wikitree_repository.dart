import '../core/constants.dart';
import '../core/failures.dart';
import 'family_graph.dart';
import 'key_parser.dart';
import 'person.dart';
import 'wikitree_api.dart';

/// Everything needed to draw the area around one starting person.
class FocusBundle {
  const FocusBundle({
    required this.focus,
    required this.graph,
    required this.ancestorDepth,
    required this.descendantDepth,
  });

  final Person focus;
  final FamilyGraph graph;
  final int ancestorDepth;
  final int descendantDepth;

  List<Person> get parents => graph.parentsOf(focus);
  List<Person> get children => graph.childrenOf(focus);
  List<Person> get siblings => graph.fullSiblingsOf(focus);
  List<Person> get halfSiblings => graph.halfSiblingsOf(focus);
  List<SpouseLink> get spouses => graph.visibleSpousesOf(focus.id);
}

/// Fetches and merges WikiTree data for one starting person.
///
/// Two requests are enough:
///   1. `getPeople` with ancestors/descendants - the family cone.
///   2. `getRelatives` for siblings and spouses (and marriage details).
///
/// `nuclear=1` is deliberately not used: requesting it on the first call pulls
/// in every ancestor's siblings too, which measured five times larger for data
/// the tree does not draw.
class WikiTreeRepository {
  WikiTreeRepository({required this.api});

  final WikiTreeApi api;

  FamilyGraph _graph = FamilyGraph();

  FamilyGraph get graph => _graph;

  /// Loads [input] again after forgetting the whole session: the answers WikiTree
  /// gave and the people built from them, as if the app had just been started.
  ///
  /// This is the manual refresh, and the only path in the app that throws data
  /// away. Everything else keeps the graph because it only ever grows - which is
  /// also why a refresh has to drop it: the graph holds the copy that arrived
  /// first, and [Person.mergedWith] prefers the richer copy rather than the newer
  /// one, so a corrected birth date (same fields filled, different values) would
  /// survive a refetch untouched. An empty graph has nothing to merge with.
  ///
  /// The depths are passed in rather than defaulted, so a tree the reader has
  /// grown comes back the size it was. A failed reload puts the previous graph
  /// back: a refresh that cannot reach WikiTree must not empty the screen.
  Future<FocusBundle> reload(
    String input, {
    required int ancestors,
    required int descendants,
  }) async {
    api.invalidate();
    final previous = _graph;
    clear();
    try {
      return await loadFocus(
        input,
        ancestors: ancestors,
        descendants: descendants,
      );
    } catch (_) {
      _graph = previous;
      rethrow;
    }
  }

  Future<FocusBundle> loadFocus(
    String input, {
    int? ancestors,
    int? descendants,
  }) async {
    final parsed = KeyParser.parse(input);
    final ancestorDepth = ancestors ?? ApiConfig.ancestorsDepth;
    final descendantDepth = descendants ?? ApiConfig.descendantsDepth;

    WikiTreeFailure? lastFailure;
    for (final candidate in _casingVariants(parsed.wikiTreeId)) {
      try {
        final response = await api.getPeople(
          key: candidate,
          ancestors: ancestorDepth,
          descendants: descendantDepth,
        );
        _graph.addAll(response.people);
        var focus = await _focusFor(candidate, response);
        if (focus == null) throw const NotFoundFailure();

        await _loadHorizontalRelatives(focus);
        focus = _graph.byId(focus.id) ?? focus;

        return FocusBundle(
          focus: focus,
          graph: _graph,
          ancestorDepth: ancestorDepth,
          descendantDepth: descendantDepth,
        );
      } on NotFoundFailure catch (failure) {
        lastFailure = failure;
      }
    }

    throw lastFailure ?? const NotFoundFailure();
  }

  /// Adds [generations] generations beyond [edge] - the top row for ancestors, the
  /// bottom row for descendants - and merges the answer into the graph.
  ///
  /// This is what a "more" tap asks for, and it asks for **only the new part**.
  /// The obvious alternative, re-asking for the whole cone at the deeper depth,
  /// sends the entire tree again with every tap (748 people at ten generations
  /// down for Habsburg-32), and it stops working as soon as the edge itself is
  /// wider than WikiTree will answer about in one request - a 124-key request
  /// measured a server error where 40 keys were fine. So the edge is batched.
  Future<void> grow(
    Iterable<Person> edge, {
    required bool ancestors,
    int generations = ApiConfig.growthStep,
  }) async {
    final keys = <String>[
      for (final person in edge)
        if (person.id > 0) person.wikiTreeId,
    ];
    if (keys.isEmpty) return;

    WikiTreeFailure? failure;
    for (var start = 0; start < keys.length; start += ApiConfig.keyBatchSize) {
      final batch = keys.skip(start).take(ApiConfig.keyBatchSize).join(',');
      try {
        final response = ancestors
            ? await api.getPeople(key: batch, ancestors: generations)
            : await api.getPeople(key: batch, descendants: generations);
        _graph.addAll(response.people);
      } on WikiTreeFailure catch (error) {
        // Whatever the other batches brought is kept; the failure is reported so
        // the screen can say so rather than pretend the tree grew.
        failure = error;
      }
    }

    if (failure != null) throw failure;
  }

  /// How many recorded children [people] have that are not on screen yet.
  ///
  /// WikiTree sends a person's children only when those children happen to be
  /// part of the same answer, so "is there anybody below this row?" has to be
  /// asked. [WikiTreeApi.probeChildren] asks for ids only, which is cheap.
  ///
  /// The ids in that answer are also the only way to learn some links: a child of
  /// a semi-private parent names their father as `-3`, while the parent's
  /// `Children` list names the child plainly. Each id is recorded with
  /// [FamilyGraph.recordChild], so a son WikiTree has already sent the app can
  /// actually be drawn under his father instead of being counted forever.
  ///
  /// [shown] is what the tree is drawing, not what is in memory: a person can be
  /// in the graph from an earlier look and still be below the bottom row.
  Future<int> hiddenChildCount(
    Iterable<Person> people, {
    required Set<int> shown,
  }) async {
    final row = <String, int>{
      for (final person in people)
        if (person.id > 0) person.wikiTreeId: person.id,
    };
    if (row.isEmpty) return 0;

    final byKey = await api.probeChildren(
      keys: row.keys.toList(growable: false),
    );

    final hidden = <int>{};
    final withheld = <String>[];
    for (final entry in row.entries) {
      final ids = byKey[entry.key];
      if (ids == null) {
        // WikiTree would not say. Guessing here is what puts a button on screen
        // that can only disappoint, so ask properly below.
        withheld.add(entry.key);
        continue;
      }
      for (final id in ids) {
        _graph.recordChild(parentId: entry.value, childId: id);
        if (!shown.contains(id)) hidden.add(id);
      }
    }

    if (withheld.isNotEmpty) {
      // Private profiles never list their children, but the generation itself
      // does come back - as limited records. Only the withheld people are asked
      // about, and private records are tiny: a living parent with three
      // children measured 2.2 KB.
      //
      // That answer also echoes the people asked about (and sometimes their
      // siblings, which are on the same row anyway), so anything already in the
      // row or on screen is not counted as "below".
      final response = await api.getPeople(
        key: withheld.join(','),
        descendants: 1,
      );
      final rowIds = withheld.map((key) => row[key]).whereType<int>().toSet();
      for (final person in response.people) {
        if (rowIds.contains(person.id) || shown.contains(person.id)) continue;
        hidden.add(person.id);
      }
    }

    return hidden.length;
  }

  /// Loads (and caches in the graph) siblings and spouses of one person. Used
  /// by the tree and details views so any person can be explored without
  /// leaving what is already on screen.
  Future<RelativeGroup?> loadRelatives(Person person) async {
    final response = await api.getRelatives(keys: <String>[person.wikiTreeId]);
    if (response.groups.isEmpty) return null;
    final group = response.groups.first;
    _mergeGroup(group);
    return group;
  }

  /// A bundle centred on someone already in the graph, with no network call.
  ///
  /// Used by the details view: the person was tapped in a tree that has already
  /// loaded their closest relatives, so everything shown is already in memory.
  FocusBundle bundleFor(Person person, {int? ancestors, int? descendants}) {
    return FocusBundle(
      focus: _graph.byId(person.id) ?? person,
      graph: _graph,
      ancestorDepth: ancestors ?? ApiConfig.ancestorsDepth,
      descendantDepth: descendants ?? ApiConfig.descendantsDepth,
    );
  }

  /// Drops everything fetched so far. Profile data is never persisted, so this
  /// is all it takes to comply with WikiTree's caching rules.
  void clear() {
    _graph = FamilyGraph();
  }

  /// The person the tree should be centred on, or null when neither the answer
  /// nor the key names anybody.
  ///
  /// `resultByKey` normally names them, which also follows a merge redirect.
  /// Asking for descendants can take that away: WikiTree answers with
  /// negative-id placeholders (`-1`, `-2`, ...) for private profiles, and for a
  /// profile whose children are private it does the same to the requested
  /// person. The resolved id is then not in `people` at all - nor is the key -
  /// and the first remaining person is a grandchild. That is a real report:
  /// `Umićević-3` opened a grandson instead of the man himself.
  ///
  /// So when the answer cannot name the focus, the profile is asked for once
  /// more on its own. There is no cone to walk in that request, so nothing gets
  /// masked, and it costs one profile instead of a whole family.
  Future<Person?> _focusFor(String key, PeopleResponse response) async {
    final named = _graph.byId(response.resolvedId) ?? _graph.byWikiTreeId(key);
    if (named != null) return named;

    // An unknown key arrives as a single empty record rather than an error, and
    // there is nothing to ask for: let the caller retry with other capitals.
    if (response.resolvedId == null && response.people.isEmpty) return null;

    final solo = await api.getPeople(key: key);
    _graph.addAll(solo.people);
    return _graph.byId(solo.resolvedId) ??
        _graph.byWikiTreeId(key) ??
        (solo.people.length == 1 ? solo.people.first : null);
  }

  Future<void> _loadHorizontalRelatives(Person focus) async {
    try {
      await loadRelatives(focus);
    } on WikiTreeFailure {
      // Non-fatal: the tree is still useful without siblings and spouses.
    }
  }

  void _mergeGroup(RelativeGroup group) {
    _graph.add(group.person);
    _graph.addAll(group.parents);
    _graph.addAll(group.children);
    _graph.addAll(group.siblings);
    _graph.addSpouses(group.person.id, group.spouses);
  }

  /// WikiTree IDs are case sensitive in the surname. Typing `einstein-1` is easy
  /// to do, so a rejected key is retried once with the surname capitalised.
  static List<String> _casingVariants(String wikiTreeId) {
    final dash = wikiTreeId.lastIndexOf('-');
    if (dash <= 0) return <String>[wikiTreeId];

    final surname = wikiTreeId.substring(0, dash);
    final number = wikiTreeId.substring(dash);
    if (surname.isEmpty) return <String>[wikiTreeId];

    final variants = <String>{wikiTreeId};
    variants.add(surname[0].toUpperCase() + surname.substring(1) + number);
    if (surname == surname.toUpperCase()) {
      variants.add(_titleCase(surname) + number);
    }
    // WikiTree accepts an all-lowercase surname (`einstein-1` resolves) even
    // though it rejects all-caps and mixed case, so this is the safety net for
    // a surname whose real spelling is not capitalised.
    variants.add(surname.toLowerCase() + number);
    return variants.toList(growable: false);
  }

  static String _titleCase(String surname) {
    final buffer = StringBuffer();
    var capitaliseNext = true;
    for (final rune in surname.runes) {
      final character = String.fromCharCode(rune);
      final isLetter = character.toUpperCase() != character.toLowerCase();
      if (capitaliseNext && isLetter) {
        buffer.write(character.toUpperCase());
        capitaliseNext = false;
      } else {
        buffer.write(character.toLowerCase());
        if (character == "'" || character == '-' || character == '_') {
          capitaliseNext = true;
        }
      }
    }
    return buffer.toString();
  }
}
