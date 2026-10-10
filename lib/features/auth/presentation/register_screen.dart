import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/route_names.dart';
import '../domain/user_entity.dart';
import 'session_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-021c scope (Part 3 of 3 of the original P-021 scope): the real
/// registration screen, replacing P-007's placeholder `RegisterScreen` (a
/// bare `Scaffold` with one debug `AppButton`).
///
/// ### Confirmed decision - register chains straight into login
///
/// `SessionNotifier.register` (Part P-021a) returns a real `User` but
/// deliberately does NOT touch `sessionProvider`'s state - the register
/// endpoint issues no tokens (Part P-020). Ahmed confirmed the open UX
/// decision both Part P-020's and Part P-021a's own docstrings left open
/// for this part: after a successful `register()` call, this screen
/// immediately calls `SessionNotifier.login` with the same email/
/// password, so registering also signs the user in. Once that `login()`
/// call succeeds, `sessionProvider`'s state becomes a non-null `User` and
/// the router's existing redirect guard (Part P-021b, `app_router.dart`)
/// carries the user to `/home` on its own - this screen does not
/// navigate manually on that path, exactly like `LoginScreen` (Part
/// P-021b) doesn't navigate manually either.
///
/// If the register call succeeds but the chained login call fails (e.g.
/// a network blip right after account creation), the account already
/// exists - there is nothing to roll back - so this screen shows a
/// message and sends the user to `/login` to sign in manually instead of
/// silently retrying.
///
/// ### Part P-112 - localized texts, no raw backend sentences
///
/// Every text comes from the ARB files. The backend's own sentences (its
/// `message` and its per-field `fields` texts) are English and are NEVER
/// shown: the screen remembers WHAT went wrong (a flag per field, or the
/// failure itself) and builds the text at build time in the active language.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  AccountType _accountType = AccountType.customer;

  /// Spans BOTH the `register()` call and the chained `login()` call -
  /// mirrors `LoginScreen`'s own single-flag convention (Part P-021b).
  /// This is transient, screen-local UI state only, never read outside
  /// this widget, so it does not duplicate `sessionProvider` as a second
  /// source of truth for "who is logged in" (architecture Section 13):
  /// `register()` itself doesn't touch that state at all (Part P-021a),
  /// and the chained `login()` call's own state transitions are exactly
  /// what the router already reacts to.
  bool _isSubmitting = false;

  /// `true` only when the backend complained about that specific field
  /// (a `ValidationFailure`'s `fields` map, Part P-004, keyed by the
  /// confirmed backend field names `email`, `password`, `password_confirm`,
  /// `account_type` - Part P-020). The text shown is a fixed localized
  /// message, never the backend's sentence.
  bool _emailRejected = false;
  bool _passwordRejected = false;
  bool _passwordConfirmRejected = false;
  bool _accountTypeRejected = false;

  /// Any failure that doesn't map onto a specific field above. The text is
  /// built from it at build time, in the active language.
  ApiFailure? _generalFailure;

  /// The rare register-succeeds-but-chained-login-fails case.
  bool _autoLoginFailed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
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
      _passwordConfirmRejected = false;
      _accountTypeRejected = false;
      _generalFailure = null;
      _autoLoginFailed = false;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            email: email,
            password: password,
            passwordConfirm: _passwordConfirmController.text,
            accountType: _accountType,
          );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        switch (failure) {
          case ValidationFailure(:final fields):
            _emailRejected = _hasFieldError(fields, 'email');
            _passwordRejected = _hasFieldError(fields, 'password');
            _passwordConfirmRejected = _hasFieldError(
              fields,
              'password_confirm',
            );
            _accountTypeRejected = _hasFieldError(fields, 'account_type');
            // A ValidationFailure with no field-specific detail for any
            // field this form has still needs to be shown somewhere.
            if (!_emailRejected &&
                !_passwordRejected &&
                !_passwordConfirmRejected &&
                !_accountTypeRejected) {
              _generalFailure = failure;
            }
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalFailure = failure;
        }
        _isSubmitting = false;
      });
      // Validators only run when Form.validate() is called - re-run it
      // now so the field-error strings just set above actually render.
      _formKey.currentState?.validate();
      return;
    }

    // Registration succeeded - chain straight into login (confirmed
    // decision, see this class's docstring). The account already exists
    // at this point, so a failure here is a degraded landing, not a
    // reason to roll anything back.
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(email: email, password: password);
      // No manual navigation on success - the router's redirect guard
      // (Part P-021b) carries the now-authenticated user to /home on its
      // own, exactly like LoginScreen.
    } on ApiFailure catch (_) {
      if (!mounted) return;
      setState(() {
        _autoLoginFailed = true;
      });
      context.goNamed(RouteNames.login);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final generalFailure = _generalFailure;
    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.authRegisterTitle)),
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
                  const SizedBox(height: 16),
                  AppTextField(
                    label: l10n.authConfirmPasswordLabel,
                    controller: _passwordConfirmController,
                    obscureText: true,
                    validator: (value) {
                      if (_passwordConfirmRejected) {
                        return l10n.authFieldErrorPasswordConfirm;
                      }
                      if ((value ?? '').isEmpty) {
                        return l10n.authConfirmPasswordRequired;
                      }
                      // Client-side check - fast feedback in addition to
                      // whatever the backend itself also validates.
                      if (value != _passwordController.text) {
                        return l10n.authPasswordsDoNotMatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.authAccountTypeLabel),
                  const SizedBox(height: 8),
                  SegmentedButton<AccountType>(
                    segments: [
                      ButtonSegment(
                        value: AccountType.customer,
                        label: Text(l10n.authAccountTypeCustomer),
                      ),
                      ButtonSegment(
                        value: AccountType.business,
                        label: Text(l10n.authAccountTypeBusiness),
                      ),
                    ],
                    selected: {_accountType},
                    onSelectionChanged: (selection) {
                      setState(() => _accountType = selection.first);
                    },
                  ),
                  if (_accountTypeRejected) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.authFieldErrorAccountType,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_autoLoginFailed || generalFailure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _autoLoginFailed
                          ? l10n.authAutoLoginFailed
                          : localizedApiError(l10n, generalFailure),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: l10n.authRegisterButton,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => context.goNamed(RouteNames.login),
                    child: Text(l10n.authGoToLogin),
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
