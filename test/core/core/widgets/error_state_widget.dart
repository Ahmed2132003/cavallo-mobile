import 'package:flutter/material.dart';

import 'app_button.dart';

/// Part P-006 scope: the one "something went wrong" state every feature
/// screen should use — a message plus a retry action — instead of each
/// feature hand-rolling its own error UI.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Human-readable error message shown to the user. Callers are
  /// expected to pass an already-friendly string (e.g. an
  /// `ApiFailure.message` from `lib/core/network`) — this widget knows
  /// nothing about failure types, per the architecture rule that
  /// `lib/core/widgets` stays feature- and layer-agnostic.
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
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}