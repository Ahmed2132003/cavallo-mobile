import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';
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
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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