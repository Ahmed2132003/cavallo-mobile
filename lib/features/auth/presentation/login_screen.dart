import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `login` route (Part P-007 — routing skeleton
/// only). Replaced by the real login screen in the Phase-3 auth feature
/// part. The button below exists only to prove route resolution manually.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('login')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: login'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to register',
              onPressed: () => context.goNamed(RouteNames.register),
            ),
          ],
        ),
      ),
    );
  }
}
