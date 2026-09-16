import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';

/// Placeholder screen for the `home` route (Part P-007 — routing skeleton
/// only). Represents the customer Home Feed (see project plan, Customer
/// App section) — replaced by the real feed feature. The "Go to discover"
/// button exists only to prove route resolution manually.
///
/// ### Temporary — Part P-021c debug logout button
///
/// The "Logout (debug)" button below was added by Part P-021c solely so
/// the full register → home → logout → login → relaunch cycle could
/// actually be exercised manually — no real Home/Profile screen with a
/// proper logout control exists yet. Calling
/// `sessionProvider`'s notifier `logout()` clears the session; the
/// router's existing redirect guard (Part P-021b) then bounces this
/// now-signed-out screen to `/login` on its own, exactly like every
/// other protected route reacts to a signed-out session.
///
/// **Remove this button once a real Home/Profile screen with proper
/// logout UX is built — it should not ship as-is.**
///
/// ### Part P-028C2 addition — "Edit business profile" entry point
///
/// This part's own first acceptance criterion is literal: "A Business
/// user who has completed onboarding can navigate from /home to the
/// Business Profile edit screen." No real Home Feed / navigation shell
/// exists yet (still this same P-007 placeholder), so — mirroring how
/// the "Logout (debug)" button above is a temporary, minimal proof
/// rather than real UX — this is a single [AppButton], conditional on
/// the signed-in user's `accountType`, that satisfies the acceptance
/// criterion without inventing a real navigation shell this part was
/// never scoped to build.
///
/// **Gated to `AccountType.business` only** — the spec's own
/// "Customer-type users remain unaffected" requirement applies here
/// too, not just to the router gate (Part P-028C1). A Customer-type
/// session never sees this button at all, rather than seeing it and
/// hitting some other guard on tap.
///
/// ⚠️ **Inherits the exact same pre-existing blocker `app_router.dart`'s
/// gate already flags**: `sessionProvider`'s `User.accountType` is still
/// the P-021a placeholder, always [AccountType.customer]. This button's
/// condition is written to be correct once that's resolved — but with
/// the placeholder in place, it will not render for any real signed-in
/// user on a real device, Business or not, exactly like the onboarding
/// redirect itself can't fire yet. This is the same open item, not a
/// new one — see `PROJECT_PROGRESS.md`'s Part P-028C1 entry.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pattern-matched rather than `.valueOrNull` — not exposed on this
    // project's pinned `flutter_riverpod` version (3.3.2), same reason
    // `app_router.dart`'s redirect and `BusinessProfileEditScreen` both
    // use the same `switch` shape instead of that getter.
    final session = ref.watch(sessionProvider);
    final user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final isBusiness = user?.accountType == AccountType.business;

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
            // Part P-028C2 — see class docstring above. Only rendered
            // for a Business-type session; a Customer-type (or, today,
            // every session, per the placeholder blocker noted above)
            // never sees this at all.
            if (isBusiness) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Edit business profile',
                onPressed: () =>
                    context.goNamed(RouteNames.businessProfileEdit),
              ),
            ],
            const SizedBox(height: 16),
            // Temporary — Part P-021c, see class docstring above.
            AppButton(
              label: 'Logout (debug)',
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}