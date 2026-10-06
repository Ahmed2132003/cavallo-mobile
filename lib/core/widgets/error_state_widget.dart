import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Part P-006 scope: the one "something went wrong" state every feature
/// screen should use - a message plus a retry action - instead of each
/// feature hand-rolling its own error UI.
///
/// Part P-111: the icon uses the danger token.
/// Part P-112: the retry label comes from the ARB files.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Human-readable error message shown to the user. Callers are
  /// expected to pass an already-friendly string - normally the result of
  /// `localizedApiError` (`lib/core/l10n/error_messages.dart`), never a raw
  /// backend message. This widget knows nothing about failure types, per the
  /// architecture rule that `lib/core/widgets` stays feature- and
  /// layer-agnostic.
  final String message;

  /// Called when the user taps the retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.appColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppButton(label: context.l10n.commonRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
