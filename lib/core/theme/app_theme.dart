import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Part P-111: the real app theme (replaces the P-006 indigo placeholder that
/// lived in lib/core/config/app_theme.dart).
///
/// [light] and [dark] are built from the same [AppColors] tokens, Material 3,
/// with hairline borders instead of elevation. Wire both into
/// `MaterialApp.router(theme: AppTheme.light, darkTheme: AppTheme.dark,
/// themeMode: ...)` (done in P-111 STEP 2).
abstract final class AppTheme {
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  /// Backwards-compatible alias of [light] so existing callers and tests
  /// (`AppTheme.theme`) keep working until main.dart switches to
  /// light/dark/themeMode in P-111 STEP 2. Remove once nothing uses it.
  static ThemeData get theme => light;

  static const Color _clear = Colors.transparent;
  static const BorderRadius _radius12 = BorderRadius.all(Radius.circular(12));
  static const Size _minButtonSize = Size(64, 44);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final TextTheme text = AppTypography.textTheme(c);
    const TextStyle base = TextStyle();

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandSubtle,
      onPrimaryContainer: c.brandText,
      secondary: c.brand,
      onSecondary: c.onBrand,
      secondaryContainer: c.surfaceVariant,
      onSecondaryContainer: c.textPrimary,
      error: c.danger,
      onError: c.onDanger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceTint: _clear,
      outline: c.outline,
      outlineVariant: c.outline,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.brandText,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceVariant,
      surfaceContainerHighest: c.surfaceVariant,
    );

    OutlineInputBorder inputBorder(BorderSide side) =>
        OutlineInputBorder(borderRadius: _radius12, borderSide: side);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        surfaceTintColor: _clear,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary),
        actionsIconTheme: IconThemeData(color: c.textPrimary),
        shape: Border(bottom: BorderSide(color: c.outline)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: _clear,
        elevation: 0,
        indicatorColor: _clear,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.brand
                : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => (text.labelSmall ?? base).copyWith(
            color: states.contains(WidgetState.selected)
                ? c.textPrimary
                : c.textSecondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: _clear,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _radius12,
          side: BorderSide(color: c.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        hintStyle: TextStyle(color: c.textSecondary),
        labelStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: TextStyle(color: c.brandText),
        errorStyle: TextStyle(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: inputBorder(BorderSide.none),
        enabledBorder: inputBorder(BorderSide.none),
        disabledBorder: inputBorder(BorderSide.none),
        focusedBorder: inputBorder(BorderSide(color: c.brand, width: 1.5)),
        errorBorder: inputBorder(BorderSide(color: c.danger)),
        focusedErrorBorder: inputBorder(BorderSide(color: c.danger, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.surfaceVariant,
          disabledForegroundColor: c.textSecondary,
          minimumSize: _minButtonSize,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: c.textSecondary,
          side: BorderSide(color: c.outline),
          minimumSize: _minButtonSize,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandText,
          disabledForegroundColor: c.textSecondary,
          minimumSize: _minButtonSize,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        disabledColor: c.surfaceVariant,
        selectedColor: c.brand,
        checkmarkColor: c.onBrand,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: WidgetStateTextStyle.resolveWith(
          (Set<WidgetState> states) => (text.labelLarge ?? base).copyWith(
            color: states.contains(WidgetState.selected)
                ? c.onBrand
                : c.textPrimary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: _clear,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: _clear,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _radius12),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceVariant,
        contentTextStyle: text.bodyMedium,
        actionTextColor: c.brandText,
        disabledActionTextColor: c.textSecondary,
        closeIconColor: c.textSecondary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.textPrimary,
        unselectedLabelColor: c.textSecondary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle:
            (text.titleSmall ?? base).copyWith(fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.brand, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: c.outline,
        dividerHeight: 1,
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
    );
  }
}