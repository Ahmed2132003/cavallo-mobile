import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import 'forgot_password_provider.dart';

/// The three real forgot-password screens (they replace the placeholders of
/// the state-layer step). They follow `login_screen.dart`: a [Form] with
/// validators, a failure turned into a localized text at build time (the
/// backend's own English sentences are never shown), and logic only in
/// [ForgotPasswordNotifier].
///
/// Each screen WATCHES [forgotPasswordProvider]: that keeps the autoDispose
/// flow state alive while a forgot-password screen is on screen, which the
/// step guard in `app_router.dart` relies on.

/// Length of the code. It is the backend's `_OTP_PATTERN = [0-9]{6}` in
/// `accounts/services.py` (read from the code, not assumed).
const int kPasswordResetOtpLength = 6;

/// A 429 gets the flow's own text; everything else goes through the shared
/// error-code mapping.
String _failureText(AppLocalizations l10n, ApiFailure failure) {
  if (failure.code == ApiErrorCodes.throttled) {
    return l10n.authResetThrottled;
  }
  return localizedApiError(l10n, failure);
}

bool _hasField(ApiFailure? failure, String name) =>
    failure is ValidationFailure &&
    (failure.fields[name] ?? const <String>[]).isNotEmpty;

/// The backend's unified 400: a [ValidationFailure] with no field detail.
bool _isUnified400(ApiFailure? failure) =>
    failure is ValidationFailure && failure.fields.isEmpty;

class _FailureText extends StatelessWidget {
  const _FailureText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ step 1

/// Step 1 (`/forgot-password`): the email. [initialEmail] is the address the
/// user had already typed on the login screen.
class ForgotPasswordEmailScreen extends ConsumerStatefulWidget {
  const ForgotPasswordEmailScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState
    extends ConsumerState<ForgotPasswordEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final remembered = ref.read(forgotPasswordProvider).email;
    final initial = (widget.initialEmail ?? '').trim();
    _emailController = TextEditingController(
      text: initial.isNotEmpty ? initial : remembered,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ref.read(forgotPasswordProvider.notifier).clearFailure();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(forgotPasswordProvider.notifier)
        .submitEmail(_emailController.text);
    if (!mounted) return;
    if (ok) {
      context.goNamed(RouteNames.forgotPasswordVerify);
    } else {
      // Re-run the validators so a server-side email complaint renders.
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(forgotPasswordProvider);
    final failure = state.failure;
    final String? general;
    if (failure == null || _hasField(failure, 'email')) {
      general = null;
    } else if (_isUnified400(failure)) {
      // Only reachable when step 3 restarted the flow (dead reset token).
      general = l10n.authResetSessionExpired;
    } else {
      general = _failureText(l10n, failure);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(RouteNames.login);
      },
      child: Scaffold(
        appBar: CavalloAppBar(title: Text(l10n.authResetEmailTitle)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Intro(l10n.authResetEmailSubtitle),
                    AppTextField(
                      label: l10n.authEmailLabel,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (_hasField(
                          ref.read(forgotPasswordProvider).failure,
                          'email',
                        )) {
                          return l10n.authFieldErrorEmail;
                        }
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return l10n.authEmailRequired;
                        if (!trimmed.contains('@')) {
                          return l10n.authEmailInvalid;
                        }
                        return null;
                      },
                    ),
                    if (general != null) _FailureText(general),
                    const SizedBox(height: 24),
                    AppButton(
                      label: l10n.authResetEmailSubmit,
                      isLoading: state.isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          state.isSubmitting
                              ? null
                              : () => context.goNamed(RouteNames.login),
                      child: Text(l10n.authResetBackToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ step 2

/// Step 2 (`/forgot-password/verify`): the code.
class ForgotPasswordOtpScreen extends ConsumerStatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  ConsumerState<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState
    extends ConsumerState<ForgotPasswordOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _backToEmail() {
    ref.read(forgotPasswordProvider.notifier).backToEmail();
    context.goNamed(RouteNames.forgotPassword);
  }

  Future<void> _verify() async {
    ref.read(forgotPasswordProvider.notifier).clearFailure();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(forgotPasswordProvider.notifier)
        .verifyOtp(_otpController.text);
    if (!mounted) return;
    if (ok) {
      _otpController.clear();
      context.goNamed(RouteNames.forgotPasswordNewPassword);
    }
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final sentText = context.l10n.authResetResendSent;
    final ok = await ref.read(forgotPasswordProvider.notifier).resendOtp();
    if (!mounted || !ok) return;
    _otpController.clear();
    messenger.showSnackBar(SnackBar(content: Text(sentText)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(forgotPasswordProvider);
    final failure = state.failure;
    final String? message =
        failure == null
            ? null
            : (_isUnified400(failure)
                ? l10n.authResetOtpInvalid
                : _failureText(l10n, failure));
    final resendLabel =
        state.canResend
            ? l10n.authResetResendButton
            : l10n.authResetResendCooldown(state.resendCooldownSeconds);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToEmail();
      },
      child: Scaffold(
        appBar: CavalloAppBar(title: Text(l10n.authResetOtpTitle)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Intro(l10n.authResetOtpNeutralHint(state.email)),
                    AppTextField(
                      label: l10n.authResetOtpLabel,
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          kPasswordResetOtpLength,
                        ),
                      ],
                      validator: (value) {
                        final code = value?.trim() ?? '';
                        if (code.isEmpty) return l10n.authResetOtpRequired;
                        if (code.length != kPasswordResetOtpLength) {
                          return l10n.authResetOtpInvalid;
                        }
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8),
                      child: Text(
                        l10n.authResetOtpExpiry,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                    if (message != null) _FailureText(message),
                    const SizedBox(height: 24),
                    AppButton(
                      label: l10n.authResetOtpSubmit,
                      isLoading: state.isSubmitting,
                      onPressed: _verify,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: resendLabel,
                      variant: AppButtonVariant.outlined,
                      onPressed:
                          state.canResend && !state.isSubmitting
                              ? _resend
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isSubmitting ? null : _backToEmail,
                      child: Text(l10n.authResetChangeEmail),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ step 3

/// Step 3 (`/forgot-password/new-password`): the new password.
class ForgotPasswordNewPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordNewPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordNewPasswordScreen> createState() =>
      _ForgotPasswordNewPasswordScreenState();
}

class _ForgotPasswordNewPasswordScreenState
    extends ConsumerState<ForgotPasswordNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ref.read(forgotPasswordProvider.notifier).clearFailure();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final successText = context.l10n.authResetSuccessBody;
    final notifier = ref.read(forgotPasswordProvider.notifier);
    final email = ref.read(forgotPasswordProvider).email;

    final ok = await notifier.confirmNewPassword(_passwordController.text);
    if (!mounted) return;

    if (ok) {
      // Success: wipe the whole flow state, tell the user, and go to the
      // login screen with the address filled in. No automatic login: the
      // backend revoked every old refresh token.
      notifier.reset();
      messenger.showSnackBar(SnackBar(content: Text(successText)));
      context.goNamed(RouteNames.login, extra: email);
      return;
    }
    if (ref.read(forgotPasswordProvider).step == ForgotPasswordStep.email) {
      // The reset token is dead (unified 400): the notifier restarted the
      // flow, so go back to step 1, which shows the "session expired" text.
      context.goNamed(RouteNames.forgotPassword);
      return;
    }
    // Weak password / network / 429: stay here; re-run the validators so a
    // field error from the server renders under the field.
    _formKey.currentState?.validate();
  }

  Widget _toggle(AppLocalizations l10n) {
    return IconButton(
      tooltip:
          _obscure ? l10n.authResetShowPassword : l10n.authResetHidePassword,
      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
  }

  void _backToEmail() {
    ref.read(forgotPasswordProvider.notifier).backToEmail();
    context.goNamed(RouteNames.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(forgotPasswordProvider);
    final failure = state.failure;
    final String? general =
        failure == null || _hasField(failure, 'new_password')
            ? null
            : _failureText(l10n, failure);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToEmail();
      },
      child: Scaffold(
        appBar: CavalloAppBar(title: Text(l10n.authResetNewPasswordTitle)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Intro(l10n.authResetNewPasswordSubtitle),
                    AppTextField(
                      label: l10n.authResetNewPasswordLabel,
                      controller: _passwordController,
                      obscureText: _obscure,
                      suffixIcon: _toggle(l10n),
                      validator: (value) {
                        if (_hasField(
                          ref.read(forgotPasswordProvider).failure,
                          'new_password',
                        )) {
                          return l10n.authResetPasswordWeak;
                        }
                        if ((value ?? '').isEmpty) {
                          return l10n.authResetPasswordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: l10n.authResetConfirmPasswordLabel,
                      controller: _confirmController,
                      obscureText: _obscure,
                      suffixIcon: _toggle(l10n),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return l10n.authResetPasswordRequired;
                        }
                        if (value != _passwordController.text) {
                          return l10n.authResetPasswordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    if (general != null) _FailureText(general),
                    const SizedBox(height: 24),
                    AppButton(
                      label: l10n.authResetNewPasswordSubmit,
                      isLoading: state.isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isSubmitting ? null : _backToEmail,
                      child: Text(l10n.authResetChangeEmail),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
