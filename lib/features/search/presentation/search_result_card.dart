/// Part P-065 STEP 4 scope: [SearchResultCard] — renders one row of the
/// Search results list, dispatching on [SearchResult]'s two variants
/// (STEP 1). [onTap] is a plain [VoidCallback], not a `context.pushNamed`
/// call made internally — same convention `PostCard`/`ReelCard`
/// (Part P-045) already use, and for the same reason: it keeps this
/// widget free of any `GoRouter` dependency, and lets a widget test
/// verify a tap without needing a real router in the tree (see
/// `HomeFeedScreen._FeedListItem`, which wires the actual
/// `context.pushNamed` call itself, one layer up).
///
/// ### Price — always through [ProductPriceFraming] (Part P-034)
///
/// The product row's price is rendered ONLY via [ProductPriceFraming]
/// (`products/presentation/product_price_framing.dart`), which that
/// file's own docstring already earmarks for exactly this reuse
/// ("Phase 11 (Search results) MUST reuse this widget/copy"). No new
/// price text is written here — reusing the real widget rather than a
/// copy of its wording is a stronger guarantee of "matching P-034's
/// precedent exactly" than a hand-copied string ever could be.
///
/// ### Business row — only real fields, no invented ones
///
/// `BusinessProfile` (Part P-028A) has no `rating`/`logo` field today —
/// confirmed against the real entity, not assumed from the product
/// deck's mockup (which shows both). This row deliberately shows only
/// what the entity actually carries: name, [BusinessType], city/country,
/// `isVerified`, and `followerCount`. Flagged here rather than silently
/// matching the mockup with fake data.
library;

import 'package:flutter/material.dart';

import '../../business_profile/domain/business_profile_entity.dart';
import '../../products/domain/product_entity.dart';
import '../../products/presentation/product_price_framing.dart';
import '../domain/search_result_entity.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      BusinessSearchResult(:final business) => _BusinessResultRow(
        business: business,
        onTap: onTap,
      ),
      ProductSearchResult(:final product) => _ProductResultRow(
        product: product,
        onTap: onTap,
      ),
    };
  }
}

class _BusinessResultRow extends StatelessWidget {
  const _BusinessResultRow({required this.business, required this.onTap});

  final BusinessProfile business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = business.businessType == BusinessType.trader
        ? 'Trader'
        : 'Factory';
    final locationLabel = [
      business.city,
      business.country,
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  business.businessName.isNotEmpty
                      ? business.businessName[0].toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            business.businessName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (business.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationLabel.isEmpty
                          ? typeLabel
                          : '$typeLabel • $locationLabel',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${business.followerCount} followers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductResultRow extends StatelessWidget {
  const _ProductResultRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchProductThumbnail(imageUrl: product.imageUrl),
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
                    const SizedBox(height: 6),
                    // The ONLY place this row renders a price — always
                    // through ProductPriceFraming (Part P-034). See this
                    // file's module docstring.
                    ProductPriceFraming(
                      price: product.price,
                      currency: product.currency,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identical shape to `product_list_screen.dart`'s own private
/// `_ProductThumbnail` (56px, rounded corners, network image with an
/// error fallback) — duplicated here under its own name rather than
/// exported and shared, same convention as this part's STEP 2 DTO
/// mapping duplication (a small, private, per-file helper rather than
/// touching an already-completed part's file for a single new caller).
class _SearchProductThumbnail extends StatelessWidget {
  const _SearchProductThumbnail({required this.imageUrl});

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