import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `businessConsole` route (Part P-007 —
/// routing skeleton only). Represents the Trader/Factory App surface (see
/// project plan, Trader/Factory App section). Loops back to `splash` so
/// the full debug navigation chain forms a closed cycle for manual
/// testing.
class BusinessConsoleScreen extends StatelessWidget {
  const BusinessConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('businessConsole')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: businessConsole'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Back to splash',
              onPressed: () => context.goNamed(RouteNames.splash),
            ),
          ],
        ),
      ),
    );
  }
}
