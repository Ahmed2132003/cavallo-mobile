/// Part BI-04: the ordering chips of the Products tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../providers/analytics_products_providers.dart';

String productsOrderingLabel(AppLocalizations l10n, ProductsOrdering ordering) {
  return switch (ordering) {
    ProductsOrdering.mostViewed => l10n.analyticsProdOrderMostViewed,
    ProductsOrdering.mostInterested => l10n.analyticsProdOrderMostInterested,
    ProductsOrdering.mostOrdered => l10n.analyticsProdOrderMostOrdered,
    ProductsOrdering.bestSelling => l10n.analyticsProdOrderBestSelling,
    ProductsOrdering.highestConversion =>
      l10n.analyticsProdOrderHighestConversion,
    ProductsOrdering.lowestConversion =>
      l10n.analyticsProdOrderLowestConversion,
  };
}

class ProductsOrderingBar extends ConsumerWidget {
  const ProductsOrderingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ProductsOrdering selected = ref.watch(productsOrderingProvider);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: ProductsOrdering.values.length,
        separatorBuilder:
            (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final ProductsOrdering ordering = ProductsOrdering.values[index];
          return ChoiceChip(
            key: Key('analytics-products-order-${ordering.name}'),
            label: Text(productsOrderingLabel(l10n, ordering)),
            selected: ordering == selected,
            onSelected:
                (bool _) => ref
                    .read(productsOrderingProvider.notifier)
                    .select(ordering),
          );
        },
      ),
    );
  }
}
