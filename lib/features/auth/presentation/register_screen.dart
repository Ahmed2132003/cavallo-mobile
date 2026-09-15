import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/route_names.dart';
import '../domain/user_entity.dart';
import 'session_provider.dart';

/// Part P-021c scope (Part 3 of 3 of the original P-021 scope): the real
/// registration screen, replacing P-007's placeholder `RegisterScreen` (a
/// bare `Scaffold` with one debug `AppButton`).
///
/// ### Confirmed decision — register chains straight into login
///
/// `SessionNotifier.register` (Part P-021a) returns a real `User` but
/// deliberately does NOT touch `sessionProvider`'s state — the register
/// endpoint issues no tokens (Part P-020). Ahmed confirmed the open UX
/// decision both Part P-020's and Part P-021a's own docstrings left open
/// for this part: after a successful `register()` call, this screen
/// immediately calls `SessionNotifier.login` with the same email/
/// password, so registering also signs the user in. Once that `login()`
/// call succeeds, `sessionProvider`'s state becomes a non-null `User` and
/// the router's existing redirect guard (Part P-021b, `app_router.dart`)
/// carries the user to `/home` on its own — this screen does not
/// navigate manually on that path, exactly like `LoginScreen` (Part
/// P-021b) doesn't navigate manually either.
///
/// If the register call succeeds but the chained login call fails (e.g.
/// a network blip right after account creation), the account already
/// exists — there is nothing to roll back — so this screen shows a
/// message and sends the user to `/login` to sign in manually instead of
/// silently retrying.
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

  /// Spans BOTH the `register()` call and the chained `login()` call —
  /// mirrors `LoginScreen`'s own single-flag convention (Part P-021b).
  /// This is transient, screen-local UI state only, never read outside
  /// this widget, so it does not duplicate `sessionProvider` as a second
  /// source of truth for "who is logged in" (architecture Section 13):
  /// `register()` itself doesn't touch that state at all (Part P-021a),
  /// and the chained `login()` call's own state transitions are exactly
  /// what the router already reacts to.
  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — set only from a
  /// `ValidationFailure`'s `fields` map (Part P-004), keyed by the
  /// confirmed backend field names (`email`, `password`,
  /// `password_confirm`, `account_type` — Part P-020).
  String? _emailFieldError;
  String? _passwordFieldError;
  String? _passwordConfirmFieldError;
  String? _accountTypeFieldError;

  /// Any failure that doesn't map onto a specific field above, plus the
  /// "account created but sign-in failed" message for the rare
  /// register-succeeds-but-chained-login-fails case.
  String? _generalError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear any previous backend-driven errors before re-validating, so a
    // field the user has since fixed doesn't keep showing a stale
    // server-side complaint from an earlier attempt.
    setState(() {
      _emailFieldError = null;
      _passwordFieldError = null;
      _passwordConfirmFieldError = null;
      _accountTypeFieldError = null;
      _generalError = null;
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
            _emailFieldError = fields['email']?.join(' ');
            _passwordFieldError = fields['password']?.join(' ');
            _passwordConfirmFieldError = fields['password_confirm']?.join(
              ' ',
            );
            _accountTypeFieldError = fields['account_type']?.join(' ');
            // A ValidationFailure with no field-specific detail for any
            // field this form has still needs to be shown somewhere.
            if (_emailFieldError == null &&
                _passwordFieldError == null &&
                _passwordConfirmFieldError == null &&
                _accountTypeFieldError == null) {
              _generalError = failure.message;
            }
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalError = failure.message;
        }
        _isSubmitting = false;
      });
      // Validators only run when Form.validate() is called — re-run it
      // now so the field-error strings just set above actually render.
      _formKey.currentState?.validate();
      return;
    }

    // Registration succeeded — chain straight into login (confirmed
    // decision, see this class's docstring). The account already exists
    // at this point, so a failure here is a degraded landing, not a
    // reason to roll anything back.
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(email: email, password: password);
      // No manual navigation on success — the router's redirect guard
      // (Part P-021b) carries the now-authenticated user to /home on its
      // own, exactly like LoginScreen.
    } on ApiFailure catch (_) {
      if (!mounted) return;
      setState(() {
        _generalError =
            'Account created, but automatic sign-in failed. Please log in.';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (_emailFieldError != null) return _emailFieldError;
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Email is required.';
                      if (!trimmed.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    validator: (value) {
                      if (_passwordFieldError != null) {
                        return _passwordFieldError;
                      }
                      if ((value ?? '').isEmpty) {
                        return 'Password is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm password',
                    controller: _passwordConfirmController,
                    obscureText: true,
                    validator: (value) {
                      if (_passwordConfirmFieldError != null) {
                        return _passwordConfirmFieldError;
                      }
                      if ((value ?? '').isEmpty) {
                        return 'Please confirm your password.';
                      }
                      // Client-side check — fast feedback in addition to
                      // whatever the backend itself also validates.
                      if (value != _passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Account type'),
                  const SizedBox(height: 8),
                  SegmentedButton<AccountType>(
                    segments: const [
                      ButtonSegment(
                        value: AccountType.customer,
                        label: Text('Customer'),
                      ),
                      ButtonSegment(
                        value: AccountType.business,
                        label: Text('Business'),
                      ),
                    ],
                    selected: {_accountType},
                    onSelectionChanged: (selection) {
                      setState(() => _accountType = selection.first);
                    },
                  ),
                  if (_accountTypeFieldError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _accountTypeFieldError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_generalError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _generalError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Create account',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => context.goNamed(RouteNames.login),
                    child: const Text('Already have an account? Log in'),
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