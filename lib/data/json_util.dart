/// Defensive JSON helpers.
///
/// The WikiTree API is inconsistent by nature: ids arrive as numbers *and* as
/// numeric strings (spouse ids are strings), flags arrive as `0`/`1` or
/// `true`/`false`, and absent values can be `null`, `''` or `0`.
library;

int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
  return null;
}

/// Ids use 0 to mean "unknown" for `Father`/`Mother`.
int? asRelationshipId(Object? value) {
  final id = asInt(value);
  if (id == null || id <= 0) return null;
  return id;
}

String? asString(Object? value) {
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

bool asBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    return lower == '1' || lower == 'true' || lower == 'yes';
  }
  return false;
}

Map<String, dynamic>? asMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, dynamic>{};
  value.forEach((key, entry) {
    result[key.toString()] = entry;
  });
  return result;
}

/// A map whose values are objects, keyed by id. Used for the `people`,
/// `Siblings`, `Spouses` and similar collections the API returns.
List<Map<String, dynamic>> asMapValues(Object? value) {
  if (value is! Map) return const <Map<String, dynamic>>[];
  final result = <Map<String, dynamic>>[];
  value.forEach((_, entry) {
    final map = asMap(entry);
    if (map != null) result.add(map);
  });
  return result;
}
