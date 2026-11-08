import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import 'forgot_password_provider.dart';

/// PLACEHOLDER screens for the three forgot-password routes. They have no
/// form, no buttons and no logic: the real screens replace them in the next
/// step. They exist so the routes, the redirect guard and the navigation
/// manifest can be built and tested now.
///
/// Each one only WATCHES [forgotPasswordProvider]. That keeps the (autoDispose)
/// flow state alive while a forgot-password screen is on screen, exactly as
/// the real screens will, so the step guard in `app_router.dart` sees the
/// right step.
class _ForgotPasswordPlaceholder extends ConsumerWidget {
  const _ForgotPasswordPlaceholder({
    required this.title,
    required this.message,
  });

  final String Function(BuildContext context) title;
  final String Function(BuildContext context) message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(forgotPasswordProvider);
    return Scaffold(
      appBar: CavalloAppBar(title: Text(title(context))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message(context), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Step 1 (`/forgot-password`).
class ForgotPasswordEmailScreen extends StatelessWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ForgotPasswordPlaceholder(
      title: (c) => c.l10n.authResetEmailTitle,
      message: (c) => c.l10n.authResetEmailSubtitle,
    );
  }
}

/// Step 2 (`/forgot-password/verify`).
class ForgotPasswordOtpScreen extends StatelessWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ForgotPasswordPlaceholder(
      title: (c) => c.l10n.authResetOtpTitle,
      message: (c) => c.l10n.authResetOtpLabel,
    );
  }
}

/// Step 3 (`/forgot-password/new-password`).
class ForgotPasswordNewPasswordScreen extends StatelessWidget {
  const ForgotPasswordNewPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ForgotPasswordPlaceholder(
      title: (c) => c.l10n.authResetNewPasswordTitle,
      message: (c) => c.l10n.authResetNewPasswordSubtitle,
    );
  }
}
