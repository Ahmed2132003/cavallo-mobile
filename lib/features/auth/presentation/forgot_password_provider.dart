import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/auth_repository_impl.dart';

/// The steps of the forgot-password flow, in order.
enum ForgotPasswordStep { email, otp, newPassword, done }

/// What the forgot-password screens read. Memory only, never persisted.
///
/// Deliberately NOT in here: the reset token (kept in a private field of
/// [ForgotPasswordNotifier], so no widget, listener or devtools snapshot can
/// ever see it) and the typed passwords / OTP (they live in the screens'
/// text controllers and are passed straight to the notifier's methods).
@immutable
class ForgotPasswordState {
  const ForgotPasswordState({
    this.step = ForgotPasswordStep.email,
    this.email = '',
    this.resendCooldownSeconds = 0,
    this.isSubmitting = false,
    this.failure,
  });

  final ForgotPasswordStep step;

  /// The address the code was requested for (trimmed). Empty on step 1
  /// until a request succeeded.
  final String email;

  /// Seconds left before the code may be requested again; 0 means "allowed".
  final int resendCooldownSeconds;

  /// A request is in flight; the screens disable their buttons.
  final bool isSubmitting;

  /// The failure of the last action, or null. The screens turn it into text
  /// with `localizedApiError`; a [ValidationFailure] on step 3 carries the
  /// backend's `fields['new_password']`.
  final ApiFailure? failure;

  bool get canResend =>
      step == ForgotPasswordStep.otp && resendCooldownSeconds == 0;

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    String? email,
    int? resendCooldownSeconds,
    bool? isSubmitting,
    ApiFailure? failure,
    bool clearFailure = false,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      email: email ?? this.email,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  /// Never prints the email: this object may end up in a log by accident.
  @override
  String toString() =>
      'ForgotPasswordState(step: ${step.name}, '
      'cooldown: $resendCooldownSeconds, submitting: $isSubmitting, '
      'failure: ${failure?.code})';
}

/// State of the forgot-password flow: email -> otp -> newPassword -> done.
///
/// * Memory only. The email is in [ForgotPasswordState]; the reset token is a
///   private field. Nothing is written to `SecureTokenStorage`, preferences or
///   logs, and nothing here touches the session: a password reset never logs
///   the user in.
/// * `autoDispose`: leaving the flow (no screen watching any more) drops the
///   email, the token and the cooldown timer. [build] registers the cleanup.
/// * The reset token is cleared on success, on a "token is dead" failure, on
///   [backToEmail] / [reset], and when the notifier is disposed.
///
/// Every action returns whether it moved the flow forward, and never throws:
/// a failure is put in [ForgotPasswordState.failure] instead.
class ForgotPasswordNotifier extends Notifier<ForgotPasswordState> {
  /// How long the user must wait before asking for another code.
  static const Duration resendCooldown = Duration(seconds: 60);

  Timer? _cooldownTimer;
  String? _resetToken;

  /// Test hook: lets a test look at the token after the notifier is disposed.
  /// Production code must never read this.
  @visibleForTesting
  String? get resetTokenForTesting => _resetToken;

  @override
  ForgotPasswordState build() {
    ref.onDispose(() {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      _resetToken = null;
    });
    return const ForgotPasswordState();
  }

  /// Step 1: asks the backend to send a code. On success moves to the OTP step
  /// and starts the resend cooldown. The backend answers the same way whether
  /// or not the account exists, so success says nothing about the account.
  Future<bool> submitEmail(String email) async {
    if (state.isSubmitting || state.step != ForgotPasswordStep.email) {
      return false;
    }
    final trimmed = email.trim();
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: trimmed);
    } catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false, failure: _toFailure(error));
      return false;
    }
    if (!ref.mounted) return false;
    state = state.copyWith(
      step: ForgotPasswordStep.otp,
      email: trimmed,
      isSubmitting: false,
    );
    _startCooldown(resendCooldown);
    return true;
  }

  /// Step 2: asks for a new code. Ignored while the cooldown runs. A throttled
  /// answer (HTTP 429) restarts the cooldown with the server's `Retry-After`
  /// when it sent one, or with [resendCooldown] otherwise.
  Future<bool> resendOtp() async {
    if (state.isSubmitting || !state.canResend) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: state.email);
    } catch (error) {
      if (!ref.mounted) return false;
      final failure = _toFailure(error);
      state = state.copyWith(isSubmitting: false, failure: failure);
      if (failure is UnknownFailure &&
          failure.code == ApiErrorCodes.throttled) {
        final wait = failure.retryAfter;
        _startCooldown(
          wait != null && wait.inSeconds > 0 ? wait : resendCooldown,
        );
      }
      return false;
    }
    if (!ref.mounted) return false;
    state = state.copyWith(isSubmitting: false);
    _startCooldown(resendCooldown);
    return true;
  }

  /// Step 2: exchanges the code for the one-time reset token and moves to the
  /// new-password step. A wrong / expired / used-up code is the backend's
  /// unified 400 (a [ValidationFailure] with no fields): the flow stays on
  /// this step with [ForgotPasswordState.failure] set.
  Future<bool> verifyOtp(String otp) async {
    if (state.isSubmitting || state.step != ForgotPasswordStep.otp) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final String token;
    try {
      token = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetOtp(email: state.email, otp: otp.trim());
    } catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false, failure: _toFailure(error));
      return false;
    }
    if (!ref.mounted) return false;
    _resetToken = token;
    _cancelCooldown();
    state = state.copyWith(
      step: ForgotPasswordStep.newPassword,
      isSubmitting: false,
      resendCooldownSeconds: 0,
    );
    return true;
  }

  /// Step 3: sets the new password. On success the token is cleared and the
  /// flow is [ForgotPasswordStep.done].
  ///
  /// * Weak password ([ValidationFailure] with `fields['new_password']`): the
  ///   backend keeps the token valid, so the flow stays here to let the user
  ///   try another password.
  /// * Any other [ValidationFailure] (the unified 400: token wrong or
  ///   expired): the token is dead, so it is cleared and the flow restarts at
  ///   step 1 with the failure shown.
  /// * Network / throttled / server failures: stay here, token kept, retry.
  Future<bool> confirmNewPassword(String newPassword) async {
    final token = _resetToken;
    if (state.isSubmitting ||
        state.step != ForgotPasswordStep.newPassword ||
        token == null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: state.email,
            resetToken: token,
            newPassword: newPassword,
          );
    } catch (error) {
      if (!ref.mounted) return false;
      final failure = _toFailure(error);
      if (failure is ValidationFailure &&
          !failure.fields.containsKey('new_password')) {
        _resetToken = null;
        _cancelCooldown();
        state = ForgotPasswordState(email: state.email, failure: failure);
      } else {
        state = state.copyWith(isSubmitting: false, failure: failure);
      }
      return false;
    }
    if (!ref.mounted) return false;
    _resetToken = null;
    state = state.copyWith(
      step: ForgotPasswordStep.done,
      isSubmitting: false,
      clearFailure: true,
    );
    return true;
  }

  /// Goes back to step 1 ("use a different email"): drops the token and the
  /// cooldown, keeps the typed email so it can be corrected.
  void backToEmail() {
    _resetToken = null;
    _cancelCooldown();
    state = ForgotPasswordState(email: state.email);
  }

  /// Back to a blank flow: drops the token, the cooldown and the email.
  void reset() {
    _resetToken = null;
    _cancelCooldown();
    state = const ForgotPasswordState();
  }

  /// Clears the last failure (for example when the user edits a field).
  void clearFailure() {
    if (state.failure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  void _startCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
    state = state.copyWith(resendCooldownSeconds: seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final next = state.resendCooldownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        _cooldownTimer = null;
        state = state.copyWith(resendCooldownSeconds: 0);
      } else {
        state = state.copyWith(resendCooldownSeconds: next);
      }
    });
  }

  void _cancelCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  ApiFailure _toFailure(Object error) {
    if (error is DioException && error.error is ApiFailure) {
      return error.error as ApiFailure;
    }
    return const UnknownFailure.unexpected();
  }
}

/// The forgot-password flow's state. `autoDispose`: see
/// [ForgotPasswordNotifier].
final forgotPasswordProvider =
    NotifierProvider.autoDispose<ForgotPasswordNotifier, ForgotPasswordState>(
      ForgotPasswordNotifier.new,
    );
