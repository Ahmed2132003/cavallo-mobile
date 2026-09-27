import 'package:flutter/material.dart';

/// Part P-006 scope: the one button every feature screen should use
/// instead of a raw [ElevatedButton]/[FilledButton], so the whole app
/// picks up a consistent look now — and any future brand restyle of
/// [AppTheme] — automatically, in one place.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  /// Text shown on the button. Replaced by a small spinner while
  /// [isLoading] is true.
  final String label;

  /// Called when the button is tapped. Ignored while [isLoading] is
  /// true — pass `null` directly to disable the button for any other
  /// reason (e.g. an invalid form).
  final VoidCallback? onPressed;

  /// When true, shows a spinner instead of [label] and disables the
  /// button, so a slow request can't be double-submitted by an
  /// impatient tap.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}