import 'person.dart';

/// An in-memory graph of the people fetched so far.
///
/// WikiTree links people by numeric id (`Father`, `Mother`, `Spouses[].Id`), so
/// the graph is keyed by id and can answer relationship questions without more
/// network calls. It lives for the lifetime of the app process only: WikiTree's
/// app policies do not allow profile data to be preserved beyond the session.
class FamilyGraph {
  final Map<int, Person> _people = <int, Person>{};
  final Map<String, int> _indexByWikiTreeId = <String, int>{};
  final Map<int, List<SpouseLink>> _spouses = <int, List<SpouseLink>>{};
  Map<int, List<int>>? _childrenByParent;

  int get length => _people.length;

  Iterable<Person> get people => _people.values;

  Person? byId(int? id) => id == null ? null : _people[id];

  Person? byWikiTreeId(String? wikiTreeId) {
    if (wikiTreeId == null) return null;
    final id = _indexByWikiTreeId[wikiTreeId.toLowerCase()];
    return id == null ? null : _people[id];
  }

  /// Adds a person, merging with a copy that may already be present.
  void add(Person person) {
    final existing = _people[person.id];
    final merged = existing == null ? person : existing.mergedWith(person);
    _people[person.id] = merged;
    _indexByWikiTreeId[merged.wikiTreeId.toLowerCase()] = merged.id;
    _childrenByParent = null;
  }

  void addAll(Iterable<Person?> people) {
    for (final person in people) {
      if (person != null) add(person);
    }
  }

  /// Records (or replaces) the spouses of a person.
  void addSpouses(int personId, Iterable<SpouseLink> links) {
    final list = _spouses.putIfAbsent(personId, () => <SpouseLink>[]);
    for (final link in links) {
      final index = list.indexWhere(
        (entry) => entry.person.id == link.person.id,
      );
      if (index >= 0) {
        list[index] = link;
      } else {
        list.add(link);
      }
      add(link.person);
    }
  }

  /// Spouses of a person, ordered by marriage date. Hidden marriages are
  /// filtered out by [visibleSpousesOf].
  List<SpouseLink> spousesOf(int personId) =>
      List<SpouseLink>.unmodifiable(_spouses[personId] ?? const <SpouseLink>[]);

  List<SpouseLink> visibleSpousesOf(int personId) {
    final links = spousesOf(personId)
        .where((link) => link.visible)
        .toList(growable: false);
    return links.toList(growable: false)..sort((a, b) {
      final left = a.marriageYear;
      final right = b.marriageYear;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
  }

  /// Everybody [personId] belongs with in a row of the tree.
  ///
  /// WikiTree sends `Spouses` only for a profile asked for by name, which in
  /// this app means the focus and whoever was tapped before. Ancestors arrive
  /// through `getPeople`, which says who their children are but never whom they
  /// married - so a couple is recognised by a shared child as well.
  ///
  /// That is what the line means in a family chart: a union. Genealogy programs
  /// group two partners and their children as one family whether or not a
  /// marriage was ever recorded, and the same goes here, so a couple with a
  /// child never loses its line just because nobody asked WikiTree about them.
  ///
  /// Explicit spouse data always wins. That includes a marriage the couple chose
  /// to hide: it keeps the pair apart instead of being inferred back in.
  List<SpouseLink> partnersOf(int personId) {
    final partners = <SpouseLink>[];
    final known = <int>{};
    for (final link in spousesOf(personId)) {
      known.add(link.person.id);
      if (link.visible) partners.add(link);
    }

    final index = _childrenByParent ??= _buildChildrenIndex();
    final children =
        (index[personId] ?? const <int>[])
            .map((id) => _people[id])
            .whereType<Person>()
            .toList()
          ..sort(_byBirthDate);

    for (final child in children) {
      final otherId = child.fatherId == personId
          ? child.motherId
          : child.fatherId;
      if (otherId == null || otherId == personId) continue;
      if (!known.add(otherId)) continue;
      final other = _people[otherId];
      if (other == null) continue;
      partners.add(SpouseLink(person: other));
    }

    return List<SpouseLink>.unmodifiable(partners);
  }

  List<Person> parentsOf(Person person) => <Person?>[
    byId(person.fatherId),
    byId(person.motherId),
  ].whereType<Person>().toList(growable: false);

  List<Person> childrenOf(Person person) {
    final index = _childrenByParent ??= _buildChildrenIndex();
    final ids = index[person.id];
    if (ids == null) return const <Person>[];
    final children = ids
        .map((id) => _people[id])
        .whereType<Person>()
        .toList(growable: false);
    return children..sort(_byBirthDate);
  }

  /// People who share both known parents with [person].
  ///
  /// When only one parent is known, anyone sharing that parent counts, because
  /// WikiTree cannot help us distinguish further.
  List<Person> fullSiblingsOf(Person person) {
    final fatherId = person.fatherId;
    final motherId = person.motherId;
    if (fatherId == null && motherId == null) return const <Person>[];

    final parent = byId(fatherId ?? motherId);
    if (parent == null) return const <Person>[];

    final siblings = childrenOf(parent)
        .where((candidate) {
          if (candidate.id == person.id) return false;
          if (fatherId != null && motherId != null) {
            return candidate.fatherId == fatherId &&
                candidate.motherId == motherId;
          }
          return true;
        })
        .toList(growable: false);
    return siblings..sort(_byBirthDate);
  }

  /// People who share exactly one parent with [person].
  List<Person> halfSiblingsOf(Person person) {
    final fatherId = person.fatherId;
    final motherId = person.motherId;
    if (fatherId == null || motherId == null) return const <Person>[];

    final result = <Person>[];
    for (final parentId in <int>{fatherId, motherId}) {
      final parent = byId(parentId);
      if (parent == null) continue;
      for (final candidate in childrenOf(parent)) {
        if (candidate.id == person.id) continue;
        final sharesFather = candidate.fatherId == fatherId;
        final sharesMother = candidate.motherId == motherId;
        if (sharesFather && sharesMother) continue; // full sibling
        if (!sharesFather && !sharesMother) continue;
        if (result.any((existing) => existing.id == candidate.id)) continue;
        result.add(candidate);
      }
    }
    return result..sort(_byBirthDate);
  }

  Map<int, List<int>> _buildChildrenIndex() {
    final index = <int, List<int>>{};
    for (final person in _people.values) {
      final fatherId = person.fatherId;
      if (fatherId != null) {
        index.putIfAbsent(fatherId, () => <int>[]).add(person.id);
      }
      final motherId = person.motherId;
      if (motherId != null) {
        index.putIfAbsent(motherId, () => <int>[]).add(person.id);
      }
    }
    return index;
  }

  static int _byBirthDate(Person a, Person b) {
    final left = a.birthYear;
    final right = b.birthYear;
    if (left != null && right != null && left != right) {
      return left.compareTo(right);
    }
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}
