import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/product_entity.dart';
import 'own_products_provider.dart';

/// Part P-033 scope: `lib/features/products/presentation/
/// product_list_screen.dart` — shows the signed-in Business account's
/// own products (`ownProductsProvider`, STEP 7), each with Edit/Delete
/// actions, plus a "Create New" action. Mirrors
/// `BusinessProfilePublicScreen`'s (Part P-029) exact
/// `switch (asyncValue) { AsyncData... AsyncError... _ => Loading }`
/// pattern and its `ErrorStateWidget`/`EmptyStateWidget`/`LoadingIndicator`
/// (Part P-006) usage.
///
/// ### Correction after review — [_apiFailureMessage] handles BOTH
/// failure shapes, not just one
///
/// The version first delivered for this step only matched a bare
/// [ApiFailure] when extracting an error message (in `_LoadErrorView`
/// and `_confirmAndDelete`'s catch block) — that's the shape every
/// hand-rolled fake repository in this project's own tests throws, so
/// it passed every test, but it is NOT the shape `ErrorInterceptor`
/// (Part P-004) actually produces in production: a real failure
/// arrives as a `DioException` whose `.error` is the typed
/// [ApiFailure] (confirmed directly in
/// `business_profile_public_screen.dart`'s own `_LoadErrorView`, which
/// already handles both shapes explicitly — this file should have
/// matched that exactly from the start and didn't). Fixed here via one
/// shared [_apiFailureMessage] helper used in both places, so a real
/// production failure now shows the backend's own message instead of
/// silently falling back to a generic one — directly relevant to this
/// part's own acceptance criterion ("do not silently swallow a
/// failure").
///
/// ### Navigation is injected, not hardcoded — a deliberate, flagged
/// sequencing decision
///
/// Every other screen in this app that navigates does so directly via
/// `context.goNamed(RouteNames.xxx)`, because `RouteNames.xxx` and its
/// `GoRoute` already existed by the time that screen was written (P-007
/// seeded the full route table up front, even for placeholder screens;
/// later parts replaced the placeholders in place). That precedent does
/// not apply here: `RouteNames` has NO entry yet for "create/edit a
/// product" — that route, and the real `ProductFormScreen` behind it
/// (STEP 9), are this part's own next step, not yet built as of this
/// file. Hardcoding a call to `context.goNamed(RouteNames.productForm)`
/// here would fail `flutter analyze` today purely because of step
/// ordering, not because of anything this screen itself needs.
///
/// So this screen takes navigation as two required callbacks —
/// [onCreateNew] and [onEditProduct] — instead. This keeps
/// `ProductListScreen` fully self-contained and testable in complete
/// isolation (a plain `MaterialApp` + `ProviderScope`, no
/// `GoRouter`/`MaterialApp.router` needed at all). Once a later step
/// adds `RouteNames.productForm` and its `GoRoute`, wiring this screen
/// into `app_router.dart`'s route table becomes a one-line `builder:` —
/// passing real `context.pushNamed(...)`/`context.push(...)` closures
/// as [onCreateNew]/[onEditProduct] — with NO change required to this
/// file.
class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({
    super.key,
    required this.onCreateNew,
    required this.onEditProduct,
  });

  /// Invoked when the user taps the "Create New" action. The caller
  /// (eventually `app_router.dart`) is responsible for navigating to
  /// the product creation form.
  final VoidCallback onCreateNew;

  /// Invoked when the user taps a product's Edit action, with that
  /// exact [Product]. The caller is responsible for navigating to the
  /// product edit form pre-filled with it.
  final void Function(Product product) onEditProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(ownProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateNew,
        icon: const Icon(Icons.add),
        label: const Text('Create New'),
      ),
      body: switch (productsAsync) {
        AsyncData(value: final products) when products.isEmpty =>
          const EmptyStateWidget(
            message:
                'No products yet.\nTap "Create New" to add your first '
                'product.',
            icon: Icons.inventory_2_outlined,
          ),
        AsyncData(value: final products) => _ProductListView(
          products: products,
          onEditProduct: onEditProduct,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Extracts a human-readable message from a thrown failure, handling
/// both shapes this project's failures can arrive in — see this file's
/// "Correction after review" note above. Shared by [_LoadErrorView] and
/// [_ProductListItem]'s delete-failure handling so both stay in sync.
String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

/// A genuine fetch failure — retryable, unlike the empty-list state
/// above (which is a normal, expected outcome for a brand-new
/// business, not an error).
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _apiFailureMessage(
        error,
        fallback: 'Could not load your products.',
      ),
      onRetry: () => ref.read(ownProductsProvider.notifier).refreshProducts(),
    );
  }
}

/// The loaded, non-empty product list. Pull-to-refresh calls
/// `OwnProductsNotifier.refreshProducts` (STEP 7) directly — the same
/// method a successful create/update/delete already triggers
/// internally, so a manual pull-down is just the user-initiated version
/// of the same refresh.
class _ProductListView extends ConsumerWidget {
  const _ProductListView({
    required this.products,
    required this.onEditProduct,
  });

  final List<Product> products;
  final void Function(Product product) onEditProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(ownProductsProvider.notifier).refreshProducts(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return _ProductListItem(
            product: product,
            onEdit: () => onEditProduct(product),
          );
        },
      ),
    );
  }
}

/// One product row: thumbnail, name, price + currency, variant count
/// (when any), an "Inactive" chip (when applicable), and Edit/Delete
/// actions.
class _ProductListItem extends ConsumerWidget {
  const _ProductListItem({required this.product, required this.onEdit});

  final Product product;
  final VoidCallback onEdit;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This will remove "${product.name}" from your products. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(ownProductsProvider.notifier).deleteProduct(product.id);
    } catch (error) {
      if (!context.mounted) return;
      final message = _apiFailureMessage(
        error,
        fallback: 'Could not delete this product.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ProductThumbnail(imageUrl: product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price} ${product.currency.toWire()}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (product.variants.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${product.variants.length} '
                      '${product.variants.length == 1 ? 'variant' : 'variants'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (!product.isActive) ...[
                    const SizedBox(height: 4),
                    const Chip(
                      label: Text('Inactive'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmAndDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product thumbnail — the real network image when [imageUrl] is set, a
/// placeholder icon otherwise (a product with no image yet is a valid,
/// expected state — see `product_entity.dart`'s own docstring).
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}