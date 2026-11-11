import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Anonymous crash diagnostics.
///
/// Two rules matter more than the reporting itself:
///   * the app must work exactly the same when Firebase is missing or offline;
///   * nothing that identifies a person may ever be attached to a report. All
///     WikiTree errors are value objects with an enum code, and `reason` is
///     always a fixed tag such as `lookup`, never a WikiTree ID or a URL.
abstract final class CrashReporter {
  static bool _initialised = false;
  static bool _userEnabled = true;

  static bool get isAvailable => _initialised;

  static Future<void> start({bool userEnabled = true}) async {
    _userEnabled = userEnabled;

    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return; // Desktop dev runs have no Firebase configuration.
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));

      _initialised = true;
      await _applyCollectionFlag();

      if (kDebugMode) return; // Keep the console readable while developing.

      FlutterError.onError = (details) {
        if (_userEnabled) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } else {
          FlutterError.presentError(details);
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        record(error, stack, reason: 'uncaught');
        return true;
      };
    } catch (error) {
      _initialised = false;
      debugPrint('Crash reporting disabled (${error.runtimeType}).');
    }
  }

  static Future<void> setUserEnabled(bool enabled) async {
    _userEnabled = enabled;
    await _applyCollectionFlag();
  }

  static void record(
    Object error,
    StackTrace? stack, {
    String reason = 'error',
  }) {
    if (!_initialised || !_userEnabled || kDebugMode) return;
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason),
    );
  }

  static Future<void> _applyCollectionFlag() async {
    if (!_initialised) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _userEnabled && !kDebugMode,
      );
    } catch (error) {
      debugPrint('Could not change crash collection (${error.runtimeType}).');
    }
  }
}
