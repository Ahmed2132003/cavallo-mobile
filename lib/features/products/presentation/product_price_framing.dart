import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
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
/// * Phase 11 (Search results) reuses this widget for any product shown
///   in a result list.
///
/// Part P-114 STEP 4A: the wording now comes from the ARB files
/// (`productPriceHeadline`, `productPriceNote`), so it is shown in Arabic
/// and English. [ProductPriceCopy] keeps the English wording as plain
/// constants: tests and any non-widget caller can still read it, and it
/// must stay identical to the English ARB text.
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
///
/// The price number is the backend's raw decimal string, passed through
/// untouched on purpose (Part P-034): it is NOT run through
/// `AppFormatters.price`, which groups thousands and drops `.00`.
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
    final AppColors colors = context.appColors;
    final headlineStyle = (compact
            ? theme.textTheme.titleSmall
            : theme.textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary);
    final noteStyle = (compact
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium)
        ?.copyWith(color: colors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.productPriceHeadline(price, currency.toWire()),
          style: headlineStyle,
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(context.l10n.productPriceNote, style: noteStyle),
      ],
    );
  }
}
