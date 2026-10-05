import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Part P-111: type scale for the design system.
///
/// The font family is NOT set here per style. It is applied once through
/// `ThemeData(fontFamily: AppTypography.fontFamily)` in `AppTheme`.
/// Family: IBM Plex Sans Arabic (Arabic + Latin glyphs, SIL OFL 1.1),
/// bundled under assets/fonts, weights 400/500/600/700.
abstract final class AppTypography {
  static const String fontFamily = 'IBMPlexSansArabic';

  /// Sizes follow the Phase 23 brief: 20 section titles, 16 body,
  /// 13 secondary, semibold names. [TextTheme.bodyMedium] stays at the
  /// Material default of 14 on purpose: it is what plain `Text` uses, and P-111
  /// must not change layouts of existing screens. P-114 may revisit it.
  static TextTheme textTheme(AppColors c) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: c.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: c.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: c.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
      ),
    );
  }
}