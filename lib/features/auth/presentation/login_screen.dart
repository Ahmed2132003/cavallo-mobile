import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/route_names.dart';
import 'session_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-021b scope (Part 2 of 3 of the original P-021 scope): the real
/// login screen, replacing P-007's placeholder `LoginScreen` (a bare
/// `Scaffold` with one debug `AppButton`).
///
/// Deliberately does NOT navigate anywhere on a successful login. Once
/// [SessionNotifier.login] succeeds, [sessionProvider]'s state becomes a
/// non-null [User], `appRouterProvider` (which `ref.watch`es
/// [sessionProvider]) rebuilds, and its redirect guard - also Part
/// P-021b, `app_router.dart` - bounces away from `/login` toward `/home`
/// on its own. Navigating manually here as well would risk a double
/// navigation race against that reactive redirect.
///
/// ### Part P-112 - localized texts, no raw backend sentences
///
/// Every text comes from the ARB files. The backend's own sentences (its
/// `message` and its per-field `fields` texts) are English and are NEVER
/// shown. Instead the screen remembers WHAT went wrong (a flag per field, or
/// the failure itself) and builds the text at build time in the active
/// language, so the message also follows a live language change.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;

  /// `true` only when the backend complained about that specific field
  /// (a [ValidationFailure]'s `fields` map, Part P-004). The text shown is
  /// a fixed localized message, not the backend's sentence.
  ///
  /// These are read by each field's `validator`, but validators only run
  /// when `Form.validate()` is called - setting these via `setState`
  /// alone does not make the error text appear on-screen. [_submit]
  /// re-calls `_formKey.currentState?.validate()` after setting them for
  /// that reason (see the comment there).
  bool _emailRejected = false;
  bool _passwordRejected = false;

  /// Any failure that doesn't map onto a specific field above (a
  /// [ValidationFailure] with no `email`/`password` entry, an
  /// [AuthFailure] for bad credentials, a [NetworkFailure], a
  /// [ServerFailure], or an [UnknownFailure]). The text is built from it
  /// at build time.
  ApiFailure? _generalFailure;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static bool _hasFieldError(Map<String, List<String>> fields, String name) =>
      (fields[name] ?? const <String>[]).isNotEmpty;

  Future<void> _submit() async {
    // Clear any previous backend-driven errors before re-validating, so a
    // field the user has since fixed doesn't keep showing a stale
    // server-side complaint from an earlier attempt.
    setState(() {
      _emailRejected = false;
      _passwordRejected = false;
      _generalFailure = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(sessionProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // No manual navigation on success - see this class's docstring.
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        switch (failure) {
          case ValidationFailure(:final fields):
            _emailRejected = _hasFieldError(fields, 'email');
            _passwordRejected = _hasFieldError(fields, 'password');
            // A ValidationFailure with no field-specific detail for
            // either field this form has (e.g. a generic/non-field
            // 400) still needs to be shown somewhere.
            if (!_emailRejected && !_passwordRejected) {
              _generalFailure = failure;
            }
          // AuthFailure (bad credentials - LoginView requires valid
          // credentials, Part P-018), NetworkFailure, ServerFailure,
          // UnknownFailure: none of these map to a specific field.
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalFailure = failure;
        }
      });
      // Validators only run when Form.validate() is called - re-run it
      // now so the field-error strings just set above actually render.
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// On the login screen an [AuthFailure] means the credentials were
  /// refused, so it gets the specific text; everything else goes through the
  /// shared error-code mapping.
  String _generalMessage(BuildContext context, ApiFailure failure) {
    final l10n = context.l10n;
    if (failure is AuthFailure) {
      return l10n.authInvalidCredentials;
    }
    return localizedApiError(l10n, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final generalFailure = _generalFailure;
    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.authLoginTitle)),
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
                  AppTextField(
                    label: l10n.authEmailLabel,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (_emailRejected) return l10n.authFieldErrorEmail;
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) return l10n.authEmailRequired;
                      if (!trimmed.contains('@')) {
                        return l10n.authEmailInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: l10n.authPasswordLabel,
                    controller: _passwordController,
                    obscureText: true,
                    validator: (value) {
                      if (_passwordRejected) {
                        return l10n.authFieldErrorPassword;
                      }
                      if ((value ?? '').isEmpty) {
                        return l10n.authPasswordRequired;
                      }
                      return null;
                    },
                  ),
                  if (generalFailure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _generalMessage(context, generalFailure),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: l10n.authLoginButton,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => context.goNamed(RouteNames.register),
                    child: Text(l10n.authGoToRegister),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
