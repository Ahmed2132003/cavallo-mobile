import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `splash` route (Part P-007 — routing
/// skeleton only). Replaced by a real splash/session-check screen once
/// Phase 3 auth exists. The button below exists only to prove route
/// resolution manually; it carries no real logic beyond
/// `context.goNamed(...)`.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('splash')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: splash'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to login',
              onPressed: () => context.goNamed(RouteNames.login),
            ),
          ],
        ),
      ),
    );
  }
}
