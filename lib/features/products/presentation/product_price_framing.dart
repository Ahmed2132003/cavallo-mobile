import 'package:flutter/material.dart';

import '../domain/product_entity.dart';

/// Part P-034 scope: the single source of truth for the price-framing
/// copy required by architecture Section 20 ("لازم يتوضّح في الـ UI/Copy
/// إن السعر تقريبي وبيتفاوض عليه مع التاجر مباشرة").
///
/// This is a real content requirement, not styling: a customer must
/// never mistake a product's price for a transactional checkout price
/// (this platform has no cart/checkout/payment — architecture
/// Section 1/20). Every screen that displays a product price must render
/// it through [ProductPriceFraming] rather than composing its own text,
/// so the wording lives in exactly one place:
///
/// * Part P-034: `ProductDetailScreen` and the products section of the
///   public business profile screen.
/// * Phase 11 (Search results) MUST reuse this widget/copy for any
///   product shown in a result list — see this part's PROJECT_PROGRESS
///   entry, which records the exact wording below.
///
/// Wording is English for now; bilingual UI is a planned, separate
/// change. When it happens, only this class's strings need to move to
/// the localization layer.
abstract final class ProductPriceCopy {
  /// e.g. `Starting from 199.99 EGP`. [price] is the backend's raw
  /// decimal string, passed through untouched (see `Product.price`).
  static String headline(String price, Currency currency) =>
      'Starting from $price ${currency.toWire()}';

  /// The mandatory framing note shown directly under the price.
  static const String note =
      'Approximate price, negotiable directly with the business. '
      'Message the business to confirm.';
}

/// Renders a product's price together with its mandatory framing note.
///
/// Contains only [Text] widgets — deliberately no icon, button, or
/// stepper of any kind: nothing here may resemble an "Add to Cart" /
/// "Buy Now" / quantity-selector pattern (Part P-034's hard rule).
///
/// [compact] only shrinks the text styles for use inside list/grid
/// cards; the copy itself is identical in both modes.
class ProductPriceFraming extends StatelessWidget {
  const ProductPriceFraming({
    super.key,
    required this.price,
    required this.currency,
    this.compact = false,
  });

  final String price;
  final Currency currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headlineStyle =
        compact ? theme.textTheme.titleSmall : theme.textTheme.titleLarge;
    final noteStyle = (compact
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium)
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ProductPriceCopy.headline(price, currency), style: headlineStyle),
        SizedBox(height: compact ? 2 : 4),
        Text(ProductPriceCopy.note, style: noteStyle),
      ],
    );
  }
}
