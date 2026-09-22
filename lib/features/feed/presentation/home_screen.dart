import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/presentation/business_profile_provider.dart';

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
/// ### Part P-028 addition — "Edit business profile" button
///
/// The router's Business-account gate (`app_router.dart`, Part P-028C1)
/// only ever forces navigation ONE way — a Business user with no
/// `BusinessProfile` yet gets routed *into* onboarding. Nothing in the
/// router pushes an already-onboarded Business user *out* to the edit
/// screen; that's a deliberate choice reachable only from somewhere in
/// the UI, and this placeholder Home is the only screen that exists to
/// put it on right now.
///
/// Shown only when BOTH are true, read reactively via `ref.watch` so it
/// appears/disappears immediately as either resolves (no manual refresh
/// needed):
/// * the signed-in user's `accountType` is [AccountType.business]
///   (a [AccountType.customer] user never sees this — matches the
///   router gate's own scoping, and never touches
///   [businessProfileProvider] at all if `session` isn't yet a
///   confirmed Business account), and
/// * [businessProfileProvider] has already resolved to a real,
///   non-null `BusinessProfile` (`AsyncData` with a value) — i.e.
///   onboarding is actually complete. While it's still `AsyncLoading`
///   (first fetch in flight) or `AsyncData(null)` (no profile yet — the
///   router gate is about to bounce this user to onboarding anyway) or
///   `AsyncError` (a genuine fetch failure), the button stays hidden
///   rather than risk linking into an edit screen with nothing to edit.
///
/// ### Part P-033 addition — "Business Console (debug)" button
///
/// P-007's original debug navigation chain (Home → Discover → Search →
/// ChatList → Notifications → Business Console → back to splash) is how
/// `businessConsole` was meant to be manually reachable, but that chain
/// is broken somewhere past the Search screen as of this part (a later,
/// unrelated part changed a screen along that chain without preserving
/// its "next" button — out of scope for P-033 to fix). Rather than
/// leave P-033's own acceptance criterion ("manual run against the real
/// backend") unreachable, this one temporary debug button jumps
/// straight from Home to `businessConsole` — the screen `BusinessConsoleScreen`
/// (Part P-033, STEP 10) already puts its real "My Products" entry
/// point on. Shown only when the signed-in user is a Business account,
/// mirroring "Edit business profile" above, since Product management is
/// a business-only surface.
///
/// **Remove this button once a real Home/Profile screen (or a real
/// Business Console shell, Phase 14) makes it reachable through proper
/// navigation — it should not ship as-is.**
///
/// ### Part P-040 addition — "Moderation queue (debug)" button
///
/// Nothing else in the app links to the moderator review UI
/// (`/moderation`, `lib/features/moderation/`) yet, and P-040's own
/// acceptance criteria need a real moderator account to reach it. This
/// one temporary button pushes straight to it. Shown only when the
/// signed-in user has `isModerator` or `isStaff` — the same condition the
/// router gate checks.
///
/// **Showing or hiding this button is a convenience, NOT the access
/// control.** The route itself is protected by `app_router.dart`'s
/// redirect guard, which blocks every non-moderator no matter how they
/// navigate (see that file's "Part P-040" doc section).
///
/// **Remove this button once a real navigation home for moderators
/// exists (e.g. an admin/moderator section of a real profile or settings
/// screen) — it should not ship as-is.**
///
/// ### Part P-050 addition — "View Story (debug)" button
///
/// P-050's own natural entry point (Phase 10's Discover screen stories
/// bar, `story_ring_widget.dart` import target, P-062) doesn't exist
/// yet — same "reachable only via a temporary debug button until its
/// real navigational home is built" situation as every other addition
/// above. Hardcodes `businessId: 3` — this is a manual-verification-only
/// button (P-050's own end-to-end acceptance criterion: business
/// creates → moderator approves → customer views → view recorded), not
/// a real navigation entry, so it isn't gated on `isBusinessUser`/
/// `canModerate` like the buttons above — any signed-in Customer needs
/// to reach it to exercise that criterion.
///
/// **Remove this button once Phase 10's Discover screen (P-062) gives
/// `StoryRingWidget` its real, permanent home — it should not ship
/// as-is.**
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final isBusinessUser =
        user != null && user.accountType == AccountType.business;
    final canModerate = user != null && (user.isModerator || user.isStaff);
    final isOnboardedBusinessUser =
        isBusinessUser &&
        switch (ref.watch(businessProfileProvider)) {
          AsyncData(:final value) => value != null,
          _ => false,
        };

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
            if (isOnboardedBusinessUser) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Edit business profile',
                onPressed:
                    () => context.goNamed(RouteNames.businessProfileEdit),
              ),
            ],
            if (isBusinessUser) ...[
              const SizedBox(height: 16),
              // Temporary — Part P-033, see class docstring above.
              AppButton(
                label: 'Business Console (debug)',
                onPressed: () => context.pushNamed(RouteNames.businessConsole),
              ),
            ],
            if (canModerate) ...[
              const SizedBox(height: 16),
              // Temporary — Part P-040, see class docstring above. A
              // convenience link only; the route is gated by the router.
              AppButton(
                label: 'Moderation queue (debug)',
                onPressed: () => context.pushNamed(RouteNames.moderation),
              ),
            ],
            const SizedBox(height: 16),
            // Temporary — Part P-050, see class docstring above.
            // Manual-verification-only entry point, hardcoded to
            // businessId 3 — not gated on account type.
            AppButton(
              label: 'View Story (debug, business 3)',
              onPressed: () => context.pushNamed(
                RouteNames.storyViewer,
                pathParameters: {RouteNames.idParam: '3'},
                extra: 'Business 3',
              ),
            ),
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