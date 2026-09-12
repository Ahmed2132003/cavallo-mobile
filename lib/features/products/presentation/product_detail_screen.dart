import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `productDetail` route (`/product/:id`)
/// (Part P-007 — routing skeleton only). Displays the received [productId]
/// to prove the `:id` path parameter is wired correctly.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});

  /// The `:id` path parameter from the matched `/product/:id` route.
  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('productDetail')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: productDetail'),
            Text('id param: $productId'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to chat list',
              onPressed: () => context.goNamed(RouteNames.chatList),
            ),
          ],
        ),
      ),
    );
  }
}
