import 'package:flutter/material.dart';

/// Part P-111: the single source of truth for every colour token of the
/// "Cavallo Blue" design system (Phase 23 overview, Design Tokens table).
///
/// Rules (Architecture Rules of P-111):
/// * Colour values live ONLY in this file. Nothing else in the app may
///   declare a brand hex value.
/// * Screens never branch on [Brightness] to pick a colour by hand. They read
///   `context.appColors` (or the [ColorScheme]).
/// * [light] and [dark] share the same brand fill on purpose.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.onBrand,
    required this.brandText,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.onDanger,
    required this.featured,
    required this.onFeatured,
    required this.successText,
    required this.warningText,
    required this.dangerText,
    required this.storyRing,
  });

  /// Brand fill: filled buttons, active tab, unread badges, own chat bubbles.
  /// Identical in Light and Dark. White label on it is 4.5:1 (rounded).
  final Color brand;

  /// Label / icon colour on top of [brand].
  final Color onBrand;

  /// Blue used as TEXT or ICON colour (links). Lighter tint on dark surfaces.
  final Color brandText;

  /// Scaffold background.
  final Color background;

  /// Cards, sheets, app bars.
  final Color surface;

  /// Chat received bubble, search field, chips, skeletons.
  final Color surfaceVariant;

  /// Hairline dividers and 1px borders.
  final Color outline;

  final Color textPrimary;
  final Color textSecondary;

  /// Destructive actions, errors, report.
  final Color danger;

  /// Label / icon colour on top of [danger].
  final Color onDanger;

  /// Featured / Sponsored badge fill (amber, never confused with brand blue).
  final Color featured;

  /// Label colour on top of [featured] (dark on amber).
  final Color onFeatured;

  /// Green used as TEXT or ICON colour on [successSubtle] (published, on
  /// track). Part P-111 STEP 3: >= 4.5:1 on its own subtle tint in both themes.
  final Color successText;

  /// Amber used as TEXT or ICON colour on [warningSubtle] (under review,
  /// approaching deadline). >= 4.5:1 on its own subtle tint in both themes.
  final Color warningText;

  /// Red used as small TEXT or ICON colour on [dangerSubtle] (rejected,
  /// failed, breached). In Light it is a deeper red than [danger] so a small
  /// chip label stays >= 4.5:1.
  final Color dangerText;

  /// Unseen story ring gradient. The "seen" ring is [storyRingSeen].
  final LinearGradient storyRing;

  /// Seen story ring = the outline colour.
  Color get storyRingSeen => outline;

  /// Very light brand tint (e.g. unread notification row), computed from the
  /// tokens so no extra hex value exists.
  Color get brandSubtle =>
      Color.alphaBlend(brand.withValues(alpha: 0.12), surface);

  /// Status chip backgrounds: the status text colour at 10% over [surface].
  Color get successSubtle =>
      Color.alphaBlend(successText.withValues(alpha: 0.10), surface);
  Color get warningSubtle =>
      Color.alphaBlend(warningText.withValues(alpha: 0.10), surface);
  Color get dangerSubtle =>
      Color.alphaBlend(dangerText.withValues(alpha: 0.10), surface);

  static const Color _brand = Color(0xFF2F6BFF);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF0B1020);
  static const Color _featured = Color(0xFFF5B301);

  static const LinearGradient _storyRing = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[Color(0xFF5AC8FF), _brand, Color(0xFF1B4FD8)],
  );

  static const AppColors light = AppColors(
    brand: _brand,
    onBrand: _white,
    brandText: _brand,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF3F5F9),
    outline: Color(0xFFDBDFE8),
    textPrimary: _ink,
    textSecondary: Color(0xFF5B6478),
    danger: Color(0xFFD92D3A),
    onDanger: _white,
    featured: _featured,
    onFeatured: _ink,
    successText: Color(0xFF187A37),
    warningText: Color(0xFF8A5A00),
    dangerText: Color(0xFFC4232F),
    storyRing: _storyRing,
  );

  static const AppColors dark = AppColors(
    brand: _brand,
    onBrand: _white,
    brandText: Color(0xFF6F9CFF),
    background: Color(0xFF0A0D14),
    surface: Color(0xFF121724),
    surfaceVariant: Color(0xFF1B2232),
    outline: Color(0xFF2A3347),
    textPrimary: Color(0xFFF5F7FB),
    textSecondary: Color(0xFF9AA4B8),
    danger: Color(0xFFFF6B74),
    onDanger: Color(0xFF0A0D14),
    featured: _featured,
    onFeatured: _ink,
    successText: Color(0xFF4ADE80),
    warningText: Color(0xFFFFC94D),
    dangerText: Color(0xFFFF6B74),
    storyRing: _storyRing,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AppColors &&
            other.brand == brand &&
            other.onBrand == onBrand &&
            other.brandText == brandText &&
            other.background == background &&
            other.surface == surface &&
            other.surfaceVariant == surfaceVariant &&
            other.outline == outline &&
            other.textPrimary == textPrimary &&
            other.textSecondary == textSecondary &&
            other.danger == danger &&
            other.onDanger == onDanger &&
            other.featured == featured &&
            other.onFeatured == onFeatured &&
            other.successText == successText &&
            other.warningText == warningText &&
            other.dangerText == dangerText &&
            other.storyRing == storyRing);
  }

  @override
  int get hashCode => Object.hash(
    brand,
    onBrand,
    brandText,
    background,
    surface,
    surfaceVariant,
    outline,
    textPrimary,
    textSecondary,
    danger,
    onDanger,
    featured,
    onFeatured,
    successText,
    warningText,
    dangerText,
    storyRing,
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? brandText,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? danger,
    Color? onDanger,
    Color? featured,
    Color? onFeatured,
    Color? successText,
    Color? warningText,
    Color? dangerText,
    LinearGradient? storyRing,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandText: brandText ?? this.brandText,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      featured: featured ?? this.featured,
      onFeatured: onFeatured ?? this.onFeatured,
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      dangerText: dangerText ?? this.dangerText,
      storyRing: storyRing ?? this.storyRing,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      featured: Color.lerp(featured, other.featured, t)!,
      onFeatured: Color.lerp(onFeatured, other.onFeatured, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      storyRing: LinearGradient.lerp(storyRing, other.storyRing, t)!,
    );
  }
}

/// `context.appColors` - the one way widgets read design tokens.
///
/// Falls back to [AppColors.light]/[AppColors.dark] (by the ambient
/// brightness) when a bare `MaterialApp` without [AppTheme] is used, e.g. in
/// older widget tests, so token-reading widgets never crash there.
extension AppColorsContext on BuildContext {
  AppColors get appColors {
    final ThemeData theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }
}
