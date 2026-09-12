import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `home` route (Part P-007 — routing skeleton
/// only). Represents the customer Home Feed (see project plan, Customer
/// App section) — replaced by the real feed feature. The button below
/// exists only to prove route resolution manually.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: home'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to discover',
              onPressed: () => context.goNamed(RouteNames.discover),
            ),
          ],
        ),
      ),
    );
  }
}
