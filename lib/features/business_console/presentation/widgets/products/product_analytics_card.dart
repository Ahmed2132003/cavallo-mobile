/// Part BI-04: one product row of the Products tab.
///
/// The analytics row has NO image, price, conversations count or separate
/// confirmed/completed counts (api_contract_BI02.md). Image and price come
/// from the products feature through [analyticsProductMetaProvider]; the
/// order numbers shown are the ones the API has: orders, sold orders, units.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../products/domain/product_entity.dart';
import '../../../domain/analytics_products.dart';
import '../../../domain/analytics_common.dart';
import '../../providers/analytics_products_providers.dart';
import 'product_analytics_format.dart';
import 'product_metric_grid.dart';

class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.imageUrl, this.size = 72});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget placeholder = ColoredBox(
      color: colors.surfaceVariant,
      child: Icon(Icons.inventory_2_outlined, color: colors.textSecondary),
    );
    final String? url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child:
            url == null || url.isEmpty
                ? placeholder
                : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) => placeholder,
                ),
      ),
    );
  }
}

class ProductAnalyticsCard extends ConsumerWidget {
  const ProductAnalyticsCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final ProductAnalyticsRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final Product? meta = switch (ref.watch(
      analyticsProductMetaProvider(row.productId),
    )) {
      AsyncData<Product?>(:final value) => value,
      _ => null,
    };
    final String price =
        meta == null
            ? kProductMissing
            : formatters.price(meta.price, meta.currency.toWire());

    final List<ProductMetric> metrics = <ProductMetric>[
      ProductMetric(
        l10n.analyticsProdMetricViews,
        productCountText(formatters, row.views),
      ),
      ProductMetric(
        l10n.analyticsProdMetricUniqueViews,
        productCountText(formatters, row.uniqueViews),
      ),
      ProductMetric(
        l10n.analyticsProdMetricInterests,
        productCountText(formatters, row.interests),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSaves,
        productCountText(formatters, row.saves),
      ),
      ProductMetric(
        l10n.analyticsProdMetricOrders,
        productCountText(formatters, row.orders),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSoldOrders,
        productCountText(formatters, row.soldOrders),
      ),
      ProductMetric(
        l10n.analyticsProdMetricUnits,
        productCountText(formatters, row.units),
      ),
      ProductMetric(
        l10n.analyticsProdMetricConversion,
        productRateText(l10n, row.conversion),
      ),
    ];

    return Card(
      key: Key('analytics-product-card-${row.productId}'),
      margin: EdgeInsets.zero,
      color: colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ProductThumb(imageUrl: meta?.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          row.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: text.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (!row.isActive) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            l10n.analyticsProdInactive,
                            style: text.labelSmall?.copyWith(
                              color: colors.warningText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ProductMetricGrid(metrics: metrics),
              const SizedBox(height: 12),
              Text(
                l10n.analyticsProdMetricSales,
                style: text.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              if (row.sales.isEmpty)
                Text(
                  l10n.analyticsProdNoSales,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                )
              else
                for (final SalesEntry sales in row.sales)
                  Text(
                    formatters.price(sales.salesValue, sales.currency),
                    style: text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
