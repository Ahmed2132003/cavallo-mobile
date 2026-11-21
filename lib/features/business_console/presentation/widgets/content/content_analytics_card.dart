/// Part BI-04: one content row of the Content tab.
///
/// The list row has NO thumbnail, external numbers or per-row last-updated
/// (api_contract_BI02.md). The thumbnail comes from the content feature; the
/// external numbers live in the detail screen, which the card points to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/analytics_content.dart';
import '../../providers/analytics_content_providers.dart';
import '../products/product_analytics_format.dart';
import '../products/product_metric_grid.dart';
import 'content_filter_bar.dart';

class ContentThumb extends StatelessWidget {
  const ContentThumb({
    super.key,
    required this.imageUrl,
    required this.contentType,
    this.size = 72,
  });

  final String? imageUrl;
  final String contentType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget placeholder = ColoredBox(
      color: colors.surfaceVariant,
      child: Icon(
        contentType == 'reel'
            ? Icons.play_circle_outline
            : Icons.image_outlined,
        color: colors.textSecondary,
      ),
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

class ContentAnalyticsCard extends ConsumerWidget {
  const ContentAnalyticsCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final ContentAnalyticsRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final String? thumb = ref.watch(
      analyticsContentThumbProvider((row.contentType, row.contentId)),
    );
    final DateTime? createdAt = row.createdAt;
    final String caption =
        row.captionPreview.trim().isEmpty
            ? l10n.analyticsContentNoCaption
            : row.captionPreview;

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
        l10n.analyticsContentMetricLikes,
        productCountText(formatters, row.likes),
      ),
      ProductMetric(
        l10n.analyticsContentMetricComments,
        productCountText(formatters, row.comments),
      ),
      ProductMetric(
        l10n.analyticsProdMetricSaves,
        productCountText(formatters, row.saves),
      ),
      ProductMetric(
        l10n.analyticsContentMetricInAppShares,
        productCountText(formatters, row.inAppShares),
      ),
      ProductMetric(
        l10n.analyticsContentMetricEngagementRate,
        productRateText(l10n, row.engagementRate),
      ),
    ];

    return Card(
      key: Key('analytics-content-card-${row.contentType}-${row.contentId}'),
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
                  ContentThumb(imageUrl: thumb, contentType: row.contentType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${contentTypeLabel(l10n, row.contentType)}'
                          ' · '
                          '${createdAt == null ? kProductMissing : formatters.absoluteDate(createdAt)}',
                          style: text.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ProductMetricGrid(metrics: metrics),
              const SizedBox(height: 8),
              Text(
                l10n.analyticsContentExternalInDetails,
                style: text.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
