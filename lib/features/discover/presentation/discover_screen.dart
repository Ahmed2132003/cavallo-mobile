import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `discover` route (Part P-007 — routing
/// skeleton only). Lives in its own `lib/features/discover/` folder
/// (confirmed by Ahmed) even though this specific folder wasn't part of
/// the original Section-12 set from P-001 — "Discover" is the first step
/// of the core Discover → Follow → Engage → Explore Products → Message
/// loop and warrants its own feature going forward.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('discover')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: discover'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to search',
              onPressed: () => context.goNamed(RouteNames.search),
            ),
          ],
        ),
      ),
    );
  }
}