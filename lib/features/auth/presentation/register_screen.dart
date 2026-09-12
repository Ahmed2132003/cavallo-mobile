import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `register` route (Part P-007 — routing
/// skeleton only). Replaced by the real registration screen in the
/// Phase-3 auth feature part. The button below exists only to prove route
/// resolution manually.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('register')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: register'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to home',
              onPressed: () => context.goNamed(RouteNames.home),
            ),
          ],
        ),
      ),
    );
  }
}
