import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// The Cavallo wordmark, drawn exactly like the one at the start of the Home
/// top bar (`HomeTopBar`): the localized brand text `homeWordmark`, in
/// `titleLarge`, weight 800, letter spacing 0.5, in the brand text colour.
///
/// It is the single widget every screen uses to show the logo, so the logo
/// looks the same everywhere. Screens normally do not use it directly: they
/// build a `CavalloAppBar` (`cavallo_app_bar.dart`), which places it.
///
/// * [compact] draws it one text step smaller (`titleMedium`) for crowded
///   places such as the story viewer header.
/// * [color] replaces the brand text colour (the story viewer is always
///   black, whatever the theme, so it passes the dark-theme brand tint).
class CavalloLogo extends StatelessWidget {
  const CavalloLogo({this.compact = false, this.color, super.key});

  /// Draws the logo one text step smaller.
  final bool compact;

  /// Overrides the brand text colour. Null uses `AppColors.brandText`.
  final Color? color;

  /// Key of the logo text.
  static const Key logoKey = ValueKey<String>('cavallo-logo');

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? base =
        compact ? textTheme.titleMedium : textTheme.titleLarge;
    return Text(
      context.l10n.homeWordmark,
      key: logoKey,
      maxLines: 1,
      style: base?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color ?? context.appColors.brandText,
      ),
    );
  }
}
