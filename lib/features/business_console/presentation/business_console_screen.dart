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
///
/// ### Part P-044 addition — "My Content" entry point
///
/// Same reasoning and same shape as "My Products" immediately above:
/// `ContentListScreen` (Post/Reel creation + status feedback) has no
/// home in the real Business Console shell yet either (Phase 14), so it
/// gets the same temporary-but-permanent entry point here, reached via
/// `pushNamed(RouteNames.contentList)`.
///
/// ### Part P-044 addition — "Moderation Queue" entry point
///
/// `ModerationQueueScreen` (Part P-040) had no reachable entry point
/// anywhere in the app before this — only the `redirect` guard in
/// `app_router.dart` enforced who could land on `/moderation`, but
/// nothing in the UI ever navigated there. Placed here (not gated by
/// account type in the UI) because this screen is reachable by ANY
/// signed-in user regardless of account type (see `app_router.dart`'s
/// base auth gate — `businessConsole` carries no account-type
/// restriction of its own), and the moderator-only restriction is
/// already enforced server-side by the router's own redirect guard: a
/// non-moderator tapping this button is bounced straight back to
/// `/home` by that guard, so showing the button unconditionally here is
/// not a security gap, only a UI convenience for whichever signed-in
/// account happens to also be staff/moderator.
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
              label: 'My Content',
              onPressed: () => context.pushNamed(RouteNames.contentList),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Moderation Queue',
              onPressed: () => context.pushNamed(RouteNames.moderation),
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