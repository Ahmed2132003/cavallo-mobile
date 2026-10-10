import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Placeholder screen for the `splash` route (Part P-007 - routing
/// skeleton only). Replaced by a real splash/session-check screen once
/// Phase 3 auth exists. The button below exists only to prove route
/// resolution manually; it carries no real logic beyond
/// `context.goNamed(...)`.
///
/// Part P-112: every text comes from the ARB files.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.splashLoading),
            const SizedBox(height: 16),
            AppButton(
              label: l10n.splashGoToLogin,
              onPressed: () => context.goNamed(RouteNames.login),
            ),
          ],
        ),
      ),
    );
  }
}
