import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `search` route (Part P-007 — routing
/// skeleton only). Navigates to a sample `businessProfile/:id` to prove
/// the parameterized route resolves correctly.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('search')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: search'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Open sample business profile',
              onPressed: () => context.goNamed(
                RouteNames.businessProfile,
                pathParameters: const {RouteNames.idParam: 'sample-business-1'},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
