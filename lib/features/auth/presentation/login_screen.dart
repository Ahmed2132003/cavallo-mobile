import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/route_names.dart';
import 'session_provider.dart';

/// Part P-021b scope (Part 2 of 3 of the original P-021 scope): the real
/// login screen, replacing P-007's placeholder `LoginScreen` (a bare
/// `Scaffold` with one debug `AppButton`).
///
/// Deliberately does NOT navigate anywhere on a successful login. Once
/// [SessionNotifier.login] succeeds, [sessionProvider]'s state becomes a
/// non-null [User], `appRouterProvider` (which `ref.watch`es
/// [sessionProvider]) rebuilds, and its redirect guard — also Part
/// P-021b, `app_router.dart` — bounces away from `/login` toward `/home`
/// on its own. Navigating manually here as well would risk a double
/// navigation race against that reactive redirect.
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

  /// Backend-driven, field-specific error text — set only from a
  /// [ValidationFailure]'s `fields` map (Part P-004). `null` unless the
  /// backend has actually complained about that specific field.
  ///
  /// These are read by each field's `validator`, but validators only run
  /// when `Form.validate()` is called — setting these via `setState`
  /// alone does not make the error text appear on-screen. [_submit]
  /// re-calls `_formKey.currentState?.validate()` after setting them for
  /// that reason (see the comment there).
  String? _emailFieldError;
  String? _passwordFieldError;

  /// Any failure that doesn't map onto a specific field above (a
  /// [ValidationFailure] with no `email`/`password` entry, an
  /// [AuthFailure] for bad credentials, a [NetworkFailure], a
  /// [ServerFailure], or an [UnknownFailure]).
  String? _generalError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear any previous backend-driven errors before re-validating, so a
    // field the user has since fixed doesn't keep showing a stale
    // server-side complaint from an earlier attempt.
    setState(() {
      _emailFieldError = null;
      _passwordFieldError = null;
      _generalError = null;
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
      // No manual navigation on success — see this class's docstring.
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        switch (failure) {
          case ValidationFailure(:final fields):
            _emailFieldError = fields['email']?.join(' ');
            _passwordFieldError = fields['password']?.join(' ');
            // A ValidationFailure with no field-specific detail for
            // either field this form has (e.g. a generic/non-field
            // 400) still needs to be shown somewhere.
            if (_emailFieldError == null && _passwordFieldError == null) {
              _generalError = failure.message;
            }
          // AuthFailure (bad credentials — LoginView requires valid
          // credentials, Part P-018), NetworkFailure, ServerFailure,
          // UnknownFailure: none of these map to a specific field.
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalError = failure.message;
        }
      });
      // Validators only run when Form.validate() is called — re-run it
      // now so the field-error strings just set above actually render.
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
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
                    label: 'Log in',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => context.goNamed(RouteNames.register),
                    child: const Text("Don't have an account? Register"),
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
