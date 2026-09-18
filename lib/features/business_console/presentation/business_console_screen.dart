import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `businessConsole` route (Part P-007 —
/// routing skeleton only). Represents the Trader/Factory App surface (see
/// project plan, Trader/Factory App section). Loops back to `splash` so
/// the full debug navigation chain forms a closed cycle for manual
/// testing.
///
/// ### Part P-033 addition — "My Products" entry point
///
/// The full Business Console shell (navigation drawer/tabs for every
/// business-side feature) isn't built until Phase 14 — this part's own
/// spec explicitly accepts that and asks only for "a simple route the
/// router exposes" in the meantime, reached from here. `pushNamed` (not
/// `goNamed`, unlike the pre-existing "Back to splash" button below) —
/// pushing keeps this screen on the back stack, so the Android/iOS back
/// gesture returns here from the product list, matching how a real
/// console tab would behave once Phase 14 replaces this placeholder.
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
              label: 'My Products',
              onPressed: () => context.pushNamed(RouteNames.productList),
            ),
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