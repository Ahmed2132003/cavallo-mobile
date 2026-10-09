import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-115 (STEP 5): the one status chip of the app.
///
/// Meaning never rides on colour alone: every chip carries an icon AND a
/// text label. The label wraps instead of being cut with "...", so a rejection
/// reason is always fully readable by the business.
enum AppStatusTone { success, warning, danger, neutral }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final (Color background, Color foreground) = switch (tone) {
      AppStatusTone.success => (colors.successSubtle, colors.successText),
      AppStatusTone.warning => (colors.warningSubtle, colors.warningText),
      AppStatusTone.danger => (colors.dangerSubtle, colors.dangerText),
      AppStatusTone.neutral => (colors.surfaceVariant, colors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: foreground),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
