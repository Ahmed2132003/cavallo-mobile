import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_widget.dart';

/// Part P-083 — placeholder for the Analytics destination (branch index 3)
/// of the Business Console shell.
///
/// Intentionally static: no providers, no repositories, no data. It only
/// reserves the Analytics slot so the shell has four working
/// destinations until Part P-085 builds the real screen.
///
/// ### Hand-off to P-085
///
/// The route is fixed by the P-083 shared contract:
/// [RouteNames.businessAnalytics] / `RouteNames.businessAnalyticsPath`
/// (`/business-console/analytics`). P-085 replaces ONLY the `builder` of
/// that `GoRoute` in `lib/routing/app_router.dart` — it must not rename or
/// move the route, and it must not touch the shell, the other branches,
/// or the redirect gate.
///
/// Keeps its own `AppBar` because the shell deliberately has none
/// (decision D1): every branch root owns its AppBar.
class AnalyticsPlaceholderScreen extends StatelessWidget {
  const AnalyticsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const EmptyStateWidget(
        key: ValueKey('business-analytics-placeholder'),
        message: 'Analytics coming soon',
        icon: Icons.bar_chart,
      ),
    );
  }
}
