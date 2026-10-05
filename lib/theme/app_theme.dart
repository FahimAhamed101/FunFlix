import 'package:flutter/material.dart';

/// Netflix-style palette.
///
/// Near-pure black rather than the usual dark grey: Netflix's look depends on
/// artwork floating on nothing, and any lift in the background flattens the
/// posters. Everything else steps up from there in small increments so cards
/// separate without needing borders.
class AppColors {
  const AppColors._();

  /// Page background. True black, so OLED panels blend the chrome away.
  static const background = Color(0xFF000000);

  /// Cards, fields, raised rows.
  static const surface = Color(0xFF141414);

  /// Selected/hover state, one step above [surface].
  static const surfaceHigh = Color(0xFF1F1F1F);

  /// The brand red. Used sparingly — buttons and the logo only.
  static const accent = Color(0xFFE50914);

  /// Pressed state for [accent].
  static const accentPressed = Color(0xFFC11119);

  static const textPrimary = Color(0xFFFFFFFF);

  /// Body and metadata text.
  static const textSecondary = Color(0xFFB3B3B3);

  /// Least important text: hints, footnotes.
  static const textMuted = Color(0xFF808080);

  /// Hairlines. Kept very low contrast on purpose.
  static const border = Color(0xFF2A2A2A);

  /// Netflix's "98% match" green.
  static const match = Color(0xFF46D369);

  /// Scrims for text over artwork. Baked as ARGB rather than computed at
  /// runtime so they stay stable across Flutter versions.
  static const scrimTop = Color(0x00000000);
  static const scrimMid = Color(0x99000000);
  static const scrimBottom = Color(0xF2000000);
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
    );
  }

  /// The one place type scale is decided.
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.12,
    color: AppColors.textPrimary,
  );

  /// Row headings on the home screen.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Small uppercase labels: badges, eyebrows.
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: AppColors.textSecondary,
  );
}
