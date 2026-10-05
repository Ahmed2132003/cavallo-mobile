import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-006 scope: the one "nothing here yet" state every feature
/// screen should use - an empty feed, no search results, no saved
/// items, etc. - instead of each feature hand-rolling its own.
///
/// Part P-111: icon and message use the textSecondary token.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key, required this.message, this.icon});

  /// Human-readable message explaining what's missing, e.g.
  /// "No products yet" or "No results found".
  final String message;

  /// Optional icon shown above [message]. Omit for a text-only state.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 48, color: colors.textSecondary),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
