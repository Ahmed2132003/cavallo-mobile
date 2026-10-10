import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../business_console/presentation/console_row.dart';
import '../domain/product_entity.dart';
import 'own_products_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-033: the signed-in Business account's own products
/// (`ownProductsProvider`), each with Edit/Delete, plus a "Create New" action.
/// (The long design notes of P-033 live in git history.)
///
/// Navigation is injected ([onCreateNew], [onEditProduct]) so the screen is
/// testable without a router - unchanged.
///
/// Part P-115 (STEP 5) restyle, presentation only:
/// * row = the shared `ConsoleRow` anatomy, status as `AppStatusChip`,
///   Delete in the danger colour (the confirmation dialog is kept);
/// * every string is localized;
/// * an optional [header] (the console dashboard cards, passed by the router)
///   sits above the list. It is null in plain tests.
///
/// No provider, notifier call or callback changed.
class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({
    super.key,
    required this.onCreateNew,
    required this.onEditProduct,
    this.header,
  });

  /// Invoked when the user taps the "Create New" action.
  final VoidCallback onCreateNew;

  /// Invoked when the user taps a product's Edit action.
  final void Function(Product product) onEditProduct;

  /// Optional widget shown above the list / empty / error states.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(ownProductsProvider);
    final Widget? headerWidget = header;

    final Widget content = switch (productsAsync) {
      AsyncData(value: final products) when products.isEmpty =>
        EmptyStateWidget(
          message: l10n.consoleProductsEmpty,
          icon: Icons.inventory_2_outlined,
        ),
      AsyncData(value: final products) => _ProductListView(
        products: products,
        onEditProduct: onEditProduct,
      ),
      AsyncError(:final error) => _LoadErrorView(error: error),
      _ => const LoadingIndicator(),
    };

    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.consoleProductsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateNew,
        icon: const Icon(Icons.add),
        label: Text(l10n.consoleProductsCreate),
      ),
      body:
          headerWidget == null
              ? content
              : Column(children: [headerWidget, Expanded(child: content)]),
    );
  }
}

/// Extracts a human-readable message from a thrown failure (both the bare
/// [ApiFailure] shape of test fakes and the real DioException shape).
String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _apiFailureMessage(
        error,
        fallback: context.l10n.consoleProductsLoadFailed,
      ),
      onRetry: () => ref.read(ownProductsProvider.notifier).refreshProducts(),
    );
  }
}

class _ProductListView extends ConsumerWidget {
  const _ProductListView({required this.products, required this.onEditProduct});

  final List<Product> products;
  final void Function(Product product) onEditProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownProductsProvider.notifier).refreshProducts(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
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

class _ProductListItem extends ConsumerWidget {
  const _ProductListItem({required this.product, required this.onEdit});

  final Product product;
  final VoidCallback onEdit;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final danger = context.appColors.danger;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.consoleProductsDeleteTitle),
            content: Text(l10n.consoleProductsDeleteBody(product.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.consoleCancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: danger),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.consoleDelete),
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
        fallback: l10n.consoleProductsDeleteFailed,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final variantCount = product.variants.length;

    return ConsoleRow(
      leading: ConsoleThumbnail(
        url: product.imageUrl,
        placeholderIcon: Icons.inventory_2_outlined,
      ),
      title: product.name,
      meta: [
        Text(
          '${product.price} ${product.currency.toWire()}',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        if (variantCount > 0)
          Text(
            l10n.consoleProductVariants(variantCount),
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
      ],
      status:
          product.isActive
              ? null
              : AppStatusChip(
                label: l10n.consoleProductInactive,
                icon: Icons.visibility_off_outlined,
                tone: AppStatusTone.neutral,
              ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: colors.textSecondary,
            tooltip: l10n.consoleEdit,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: colors.danger,
            tooltip: l10n.consoleDelete,
            onPressed: () => _confirmAndDelete(context, ref),
          ),
        ],
      ),
    );
  }
}
