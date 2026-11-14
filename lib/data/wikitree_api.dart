import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/failures.dart';
import 'cache/response_cache.dart';
import 'json_util.dart';
import 'person.dart';

/// The person fields the app asks for.
///
/// `Bio` is deliberately absent: WikiTree's app policies do not allow
/// biographies to be shown outside WikiTree, and it would bloat every response.
const String wikiTreePersonFields =
    'Id,PageId,Name,FirstName,MiddleName,'
    'LastNameAtBirth,LastNameCurrent,RealName,Prefix,Suffix,Nicknames,'
    'BirthDate,DeathDate,BirthLocation,DeathLocation,Gender,IsLiving,Privacy,'
    'Father,Mother,Photo,PhotoData';

class PeopleResponse {
  const PeopleResponse({required this.people, this.resolvedId});

  final List<Person> people;

  /// The id the requested key resolved to. Redirected (merged) profiles answer
  /// with a different id, so navigation must follow this rather than the key.
  final int? resolvedId;
}

class RelativeGroup {
  const RelativeGroup({
    required this.person,
    this.parents = const <Person>[],
    this.children = const <Person>[],
    this.siblings = const <Person>[],
    this.spouses = const <SpouseLink>[],
  });

  final Person person;
  final List<Person> parents;
  final List<Person> children;
  final List<Person> siblings;
  final List<SpouseLink> spouses;
}

class RelativesResponse {
  const RelativesResponse({required this.groups});

  final List<RelativeGroup> groups;
}

/// The subset of the WikiTree API the app needs. Kept as an interface so tests
/// and the UI never touch the network directly.
abstract interface class WikiTreeApi {
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  });

  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  });

  /// Which recorded children each key has, as bare ids.
  ///
  /// WikiTree never sends a person's children with the person itself (a
  /// requested `Children` field is silently dropped), so this is the only way to
  /// answer "is anybody recorded below these people?" without fetching the
  /// generation. Asking for ids only makes it a few hundred bytes per person.
  ///
  /// A `null` value means WikiTree would not say. It keeps the children of
  /// private profiles out of the answer entirely, which is a different thing
  /// from "no children" and must not be read as one.
  Future<Map<String, List<int>?>> probeChildren({required List<String> keys});

  /// Forgets everything answered this session, so the next request really is a
  /// request.
  ///
  /// Only the manual refresh uses this. The cache is what makes tapping back and
  /// forth free, and it is memory only - WikiTree's app policies do not allow
  /// profile data to outlive the session - so dropping it costs nothing but the
  /// requests it has already saved.
  void invalidate();

  void close();
}

/// Talks to `https://api.wikitree.com`.
///
/// Responsibilities kept in one place so the rest of the app never sees HTTP:
/// the required `appId`, the field list, redirect resolution, rate limiting,
/// defensive status handling and an in-session response cache.
class HttpWikiTreeApi implements WikiTreeApi {
  HttpWikiTreeApi({http.Client? client, ResponseCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? SessionResponseCache();

  final http.Client _client;
  final ResponseCache _cache;
  final Map<String, Future<Map<String, dynamic>>> _inFlight =
      <String, Future<Map<String, dynamic>>>{};

  Future<void> _serial = Future<void>.value();
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<PeopleResponse> getPeople({
    required String key,
    int ancestors = 0,
    int descendants = 0,
  }) async {
    final map = await _request(<String, String>{
      'action': 'getPeople',
      'keys': key,
      if (ancestors > 0) 'ancestors': '$ancestors',
      if (descendants > 0) 'descendants': '$descendants',
    });

    final people = <Person>[];
    for (final entry in asMapValues(map['people'])) {
      final person = Person.tryFromJson(entry);
      if (person != null) people.add(person);
    }

    int? resolvedId;
    String? keyStatus;
    final resultByKey = asMap(map['resultByKey']);
    if (resultByKey != null && resultByKey.isNotEmpty) {
      final entry = asMap(resultByKey.values.first);
      resolvedId = asInt(entry?['Id']);
      keyStatus = asString(entry?['status']);
    }

    if (people.isEmpty) {
      // `resultByKey` names the id and says why nothing came back: an Unlisted
      // profile answers "Ancestor/Descendant permission denied." and sends a
      // nameless placeholder instead of the person. Calling that "not found"
      // tells the reader their relative does not exist, which is untrue.
      if (keyStatus != null && _saysWithheld(keyStatus)) {
        throw const PrivateProfileFailure();
      }
      throw const NotFoundFailure();
    }

    return PeopleResponse(people: people, resolvedId: resolvedId);
  }

  @override
  Future<RelativesResponse> getRelatives({
    required List<String> keys,
    bool siblings = true,
    bool spouses = true,
  }) async {
    if (keys.isEmpty) {
      return const RelativesResponse(groups: <RelativeGroup>[]);
    }

    final map = await _request(<String, String>{
      'action': 'getRelatives',
      'keys': keys.join(','),
      // WikiTree answers with `Father`/`Mother` ids alone unless this is asked
      // for, and an id is not a card. Without it a tapped person whose parents
      // were not part of the loaded tree showed no parents at all.
      'getParents': '1',
      if (siblings) 'getSiblings': '1',
      if (spouses) 'getSpouses': '1',
    });

    final items = map['items'];
    if (items is! List) throw const ParseFailure();

    final groups = <RelativeGroup>[];
    for (final item in items) {
      final itemMap = asMap(item);
      if (itemMap == null) continue;
      final personMap = asMap(itemMap['person']);
      final person = Person.tryFromJson(personMap);
      if (person == null || personMap == null) continue;
      groups.add(
        RelativeGroup(
          person: person,
          parents: _peopleFrom(personMap['Parents']),
          children: _peopleFrom(personMap['Children']),
          siblings: _peopleFrom(personMap['Siblings']),
          spouses: _spousesFrom(personMap['Spouses']),
        ),
      );
    }
    return RelativesResponse(groups: groups);
  }

  @override
  Future<Map<String, List<int>?>> probeChildren({
    required List<String> keys,
  }) async {
    if (keys.isEmpty) return const <String, List<int>?>{};

    final map = await _request(<String, String>{
      'action': 'getRelatives',
      'keys': keys.join(','),
      'getChildren': '1',
      'getParents': '0',
      'getSiblings': '0',
      'getSpouses': '0',
    }, fields: 'Id,Children');

    final items = map['items'];
    if (items is! List) throw const ParseFailure();

    final children = <String, List<int>?>{};
    for (final item in items) {
      final itemMap = asMap(item);
      if (itemMap == null) continue;
      final key = itemMap['key'];
      final person = asMap(itemMap['person']);
      if (key is! String || person == null) continue;
      // A missing `Children` key is WikiTree saying "not for you", which
      // happens for private profiles. `null` keeps that apart from empty.
      children[key] = person.containsKey('Children')
          ? _childIds(person['Children'])
          : null;
    }
    return children;
  }

  @override
  void invalidate() => _cache.clear();

  @override
  void close() {
    _cache.clear();
    _client.close();
  }

  Future<Map<String, dynamic>> _request(
    Map<String, String> params, {
    String fields = wikiTreePersonFields,
  }) {
    final query = <String, String>{
      ...params,
      'fields': fields,
      'appId': ApiConfig.appId,
      'resolveRedirect': '1',
    };

    final cacheKey = _cacheKey(query);
    final cached = _cache.read(cacheKey);
    if (cached != null) {
      return Future<Map<String, dynamic>>.value(cached);
    }

    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final request = _send(query, cacheKey);
    _inFlight[cacheKey] = request;
    return request;
  }

  Future<Map<String, dynamic>> _send(
    Map<String, String> query,
    String cacheKey,
  ) async {
    try {
      await _throttle();
      final uri = Uri.parse(ApiConfig.endpoint).replace(queryParameters: query);

      http.Response response;
      try {
        response = await _client.get(uri).timeout(ApiConfig.requestTimeout);
      } on TimeoutException {
        throw const NetworkFailure(timedOut: true);
      } on http.ClientException {
        throw const NetworkFailure();
      }

      if (response.statusCode == 429) throw const RateLimitFailure();
      if (response.statusCode >= 500) {
        throw ServerFailure(httpStatus: response.statusCode);
      }
      if (response.statusCode != 200) {
        throw ServerFailure(httpStatus: response.statusCode);
      }

      Object? decoded;
      try {
        decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
      } on FormatException {
        throw const ParseFailure();
      }

      final map = _firstObject(decoded);
      if (map == null) throw const ParseFailure();
      _throwIfStatusIsError(map);

      _cache.write(cacheKey, map);
      return map;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Spaces requests out so the app stays a good citizen even if the user taps
  /// quickly through several people.
  Future<void> _throttle() {
    final next = _serial.then((_) async {
      final wait = _nextAllowed.difference(DateTime.now());
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
      _nextAllowed = DateTime.now().add(ApiConfig.minRequestSpacing);
    });
    _serial = next.catchError((Object _) {});
    return next;
  }

  static Map<String, dynamic>? _firstObject(Object? decoded) {
    if (decoded is List) {
      if (decoded.isEmpty) return null;
      return asMap(decoded.first);
    }
    return asMap(decoded);
  }

  /// `status` is `0` from some actions and `''` from others. A non-empty string
  /// is an error, though WikiTree also uses it for harmless notices, so the
  /// known error phrases are matched rather than treating every string alike.
  static void _throwIfStatusIsError(Map<String, dynamic> map) {
    final status = map['status'];
    if (status == null) return;

    if (status is num) {
      if (status == 0) return;
      throw const ServerFailure();
    }

    if (status is bool) {
      if (!status) return;
      throw const ServerFailure();
    }

    if (status is String) {
      final trimmed = status.trim();
      if (trimmed.isEmpty || trimmed == '0') return;

      final lower = trimmed.toLowerCase();
      if (lower.contains('invalid wikitree id') ||
          lower.contains('illegal wikitree id') ||
          lower.contains('not found') ||
          lower.contains('does not exist') ||
          lower.contains('unable to find')) {
        throw const NotFoundFailure();
      }
      if (lower.contains('private')) throw const PrivateProfileFailure();
      throw const ServerFailure();
    }

    throw const ServerFailure();
  }

  /// Whether a per-key `resultByKey` status means WikiTree is withholding the
  /// profile rather than saying it does not exist.
  static bool _saysWithheld(String status) {
    final lower = status.toLowerCase();
    return lower.contains('permission denied') ||
        lower.contains('private') ||
        lower.contains('denied');
  }

  static List<Person> _peopleFrom(Object? value) {
    final people = <Person>[];
    for (final entry in asMapValues(value)) {
      final person = Person.tryFromJson(entry);
      if (person != null) people.add(person);
    }
    return people;
  }

  /// `Children` arrives as a map of id to profile normally, and as a plain list
  /// of ids when only `Id` and `Children` were asked for.
  static List<int> _childIds(Object? value) {
    final ids = <int>{};
    for (final entry in asMapValues(value)) {
      final id = asInt(entry['Id']);
      if (id != null) ids.add(id);
    }
    if (value is List) {
      for (final entry in value) {
        final id = asInt(entry) ?? asInt(asMap(entry)?['Id']);
        if (id != null) ids.add(id);
      }
    }
    return ids.toList(growable: false);
  }

  static List<SpouseLink> _spousesFrom(Object? value) {
    final spouses = <SpouseLink>[];
    for (final entry in asMapValues(value)) {
      final link = SpouseLink.tryFromJson(entry);
      if (link != null) spouses.add(link);
    }
    return spouses;
  }

  static String _cacheKey(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('&');
  }
}
