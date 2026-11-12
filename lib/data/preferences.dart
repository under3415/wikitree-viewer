import 'package:shared_preferences/shared_preferences.dart';

import '../core/crash_reporter.dart';

/// What the app remembers between runs.
///
/// Deliberately tiny: the last family code the user opened, and whether the
/// how-to hints for the tree have been shown. Nothing about the people in the
/// tree is ever written - WikiTree's app policies do not allow keeping profile
/// data beyond the session - and there is no account, so there is nothing else
/// worth storing.
abstract interface class AppPreferences {
  /// The code of the last family opened, ready to go back in the box.
  Future<String?> lastCode();

  /// Remembers [code] as the code that was opened last.
  Future<void> rememberCode(String code);

  /// Whether the "how to use the tree" hints have already been shown.
  Future<bool> hasSeenTreeTips();

  /// Records that the hints have been shown, so they are not shown again.
  Future<void> markTreeTipsSeen();
}

/// The real thing: two keys in the device's own storage.
///
/// Every call is guarded. If the platform storage is unavailable the app simply
/// forgets, because a convenience from the last run is never worth an error on
/// the screen the user is looking at.
class DevicePreferences implements AppPreferences {
  DevicePreferences({SharedPreferencesAsync? store})
    : _store = store ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _store;

  /// Only has to be unique inside this app; the plugin namespaces the rest.
  static const String lastCodeKey = 'lastFamilyCode';
  static const String treeTipsKey = 'treeTipsSeen';

  @override
  Future<String?> lastCode() async {
    try {
      final code = await _store.getString(lastCodeKey);
      return (code == null || code.isEmpty) ? null : code;
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'prefs-read');
      return null;
    }
  }

  @override
  Future<void> rememberCode(String code) async {
    try {
      await _store.setString(lastCodeKey, code);
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'prefs-write');
    }
  }

  @override
  Future<bool> hasSeenTreeTips() async {
    try {
      return await _store.getBool(treeTipsKey) ?? false;
    } catch (error, stack) {
      // Not knowing is the same as not having seen them: showing the hints one
      // more time costs nothing.
      CrashReporter.record(error, stack, reason: 'prefs-read');
      return false;
    }
  }

  @override
  Future<void> markTreeTipsSeen() async {
    try {
      await _store.setBool(treeTipsKey, true);
    } catch (error, stack) {
      CrashReporter.record(error, stack, reason: 'prefs-write');
    }
  }
}
