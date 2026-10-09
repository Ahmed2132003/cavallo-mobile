import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-114 STEP 1: one number-over-label cell of the Instagram-style
/// stats row (Posts, Followers, Products, Rating) on a business profile.
///
/// Presentation only. The caller passes the already formatted [value]
/// (use `AppFormatters.compactCount`) and the localized [label]; this widget
/// never formats or translates anything itself.
///
/// With [onTap] the whole cell is a button with a touch target of at least
/// 44 logical pixels. Without it the cell is plain text.
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  static const double minTapTarget = 44;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );

    Widget result = content;
    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTapTarget,
            minHeight: minTapTarget,
          ),
          child: Center(child: content),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '$value $label',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: result,
    );
  }
}
