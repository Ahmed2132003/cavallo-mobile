import 'package:flutter/material.dart';

/// Part P-006 scope: a minimal, neutral, functional [ThemeData] so every
/// feature screen looks consistent from the first screen built, without
/// waiting on final brand assets (Section 7, item 5 — still INPUT
/// REQUIRED as of this part).
///
/// Nothing in this file should be read as a brand decision. The only
/// commitment this part makes is that `AppTheme.theme` exists and is
/// applied app-wide via `MaterialApp(theme: AppTheme.theme)`; the seed
/// color, typography, and every other visual detail below are expected
/// to be thrown away wholesale once real brand assets exist — see the
/// restyle-pass note below.
class AppTheme {
  AppTheme._();

  // PLACEHOLDER THEME — replace seed color / typography once brand assets
  // are provided (see project plan Section 7, item 5). A future restyle
  // part should be scheduled once those assets land; until then every
  // screen shares this one neutral Material 3 look on purpose.
  static const Color _placeholderSeedColor = Colors.indigo;

  /// The app-wide theme. Apply via `MaterialApp(theme: AppTheme.theme)`.
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _placeholderSeedColor),
    );
  }
}