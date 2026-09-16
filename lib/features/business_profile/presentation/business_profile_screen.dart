import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `businessProfile` route (`/business/:id`)
/// (Part P-007 — routing skeleton only). Displays the received [businessId]
/// to prove the `:id` path parameter is wired correctly, then navigates to
/// a sample `productDetail/:id` to prove chained parameterized routes work.
class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key, required this.businessId});

  /// The `:id` path parameter from the matched `/business/:id` route.
  final String businessId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('businessProfile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: businessProfile'),
            Text('id param: $businessId'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Open sample product detail',
              onPressed:
                  () => context.goNamed(
                    RouteNames.productDetail,
                    pathParameters: const {
                      RouteNames.idParam: 'sample-product-1',
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
