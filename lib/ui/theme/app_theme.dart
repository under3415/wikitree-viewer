import 'package:flutter/material.dart';

/// Material 3 theme tuned for the people this app is for: generous text sizes,
/// high contrast, and controls that are easy to hit.
abstract final class AppTheme {
  static const Color seedColor = Color(0xFF2F7D32);

  static ThemeData light({double textScale = 1}) =>
      _build(Brightness.light, textScale);

  static ThemeData dark({double textScale = 1}) =>
      _build(Brightness.dark, textScale);

  static ThemeData _build(Brightness brightness, double textScale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, textScale),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          textStyle: _textTheme(base.textTheme, textScale).titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, double textScale) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32 * textScale,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26 * textScale,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22 * textScale,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18 * textScale,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 18 * textScale,
        height: 1.4,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 16 * textScale,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 17 * textScale,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
