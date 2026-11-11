import 'dart:collection';

/// A cache of WikiTree API responses.
///
/// WikiTree's app policies forbid preserving profile data beyond the user's
/// session, so the only implementation the app wires up is in-memory. The
/// interface exists so a disk-backed implementation can be added *if* WikiTree
/// grants permission - see README.md.
abstract interface class ResponseCache {
  Map<String, dynamic>? read(String key);
  void write(String key, Map<String, dynamic> value);
  void clear();
}

/// Keeps responses for the lifetime of the app process only.
///
/// This is what makes tapping back and forth feel instant: revisiting a person
/// already seen in this session costs no network calls at all.
class SessionResponseCache implements ResponseCache {
  SessionResponseCache({this.maxEntries = 64});

  final int maxEntries;
  final LinkedHashMap<String, Map<String, dynamic>> _entries =
      LinkedHashMap<String, Map<String, dynamic>>();

  int get length => _entries.length;

  @override
  Map<String, dynamic>? read(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    // Re-insert to mark as most recently used.
    _entries[key] = value;
    return value;
  }

  @override
  void write(String key, Map<String, dynamic> value) {
    _entries.remove(key);
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = value;
  }

  @override
  void clear() => _entries.clear();
}
