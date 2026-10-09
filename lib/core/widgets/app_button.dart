import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Visual weight of an [AppButton].
///
/// Part P-114 STEP 3: [neutral] (grey, used by "Following") and [outlined]
/// (used by "Message") were added next to the original filled button.
enum AppButtonVariant {
  /// Filled brand button: the primary action. This is the default.
  filled,

  /// Filled with the neutral surface colour: a secondary state such as
  /// "Following".
  neutral,

  /// Hairline outline, no fill: a secondary action such as "Message".
  outlined,

  /// Filled with the danger colour: a destructive action such as "Reject"
  /// (Part P-115 STEP 7B).
  danger,
}

/// The one button of the app (Part P-006, extended by P-114 STEP 3).
///
/// Every variant is still an [AppButton], so tests and callers that look for
/// an [AppButton] with a label keep working whatever the variant is.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
  });

  final String label;

  final VoidCallback? onPressed;

  /// Shows a small spinner instead of the label and disables the button.
  final bool isLoading;

  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final VoidCallback? handler = isLoading ? null : onPressed;
    final Widget child =
        isLoading
            ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: switch (variant) {
                  AppButtonVariant.filled => colors.brandText,
                  AppButtonVariant.danger => colors.onDanger,
                  _ => colors.textPrimary,
                },
              ),
            )
            : Text(label);

    switch (variant) {
      case AppButtonVariant.filled:
        return FilledButton(onPressed: handler, child: child);
      case AppButtonVariant.neutral:
        return FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: colors.surfaceVariant,
            foregroundColor: colors.textPrimary,
          ),
          child: child,
        );
      case AppButtonVariant.danger:
        return FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.onDanger,
          ),
          child: child,
        );
      case AppButtonVariant.outlined:
        return OutlinedButton(
          onPressed: handler,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.outline),
          ),
          child: child,
        );
    }
  }
}
