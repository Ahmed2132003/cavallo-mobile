import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `notifications` route (Part P-007 — routing
/// skeleton only). The button below exists only to prove route resolution
/// manually.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('notifications')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: notifications'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to business console',
              onPressed: () => context.goNamed(RouteNames.businessConsole),
            ),
          ],
        ),
      ),
    );
  }
}
