import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../../products/domain/product_entity.dart';
import '../../products/presentation/product_price_framing.dart';
import '../../products/presentation/product_public_providers.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_public_provider.dart';

/// Part P-029 scope: the customer-facing, READ-ONLY business profile
/// screen behind `/business/:id` — the "Business Profile" step of the
/// product's core Discover → Follow → Engage → Explore → Message loop.
/// Replaces Part P-007's placeholder screen for the same route.
///
/// ## ⚠️ KNOWN FUTURE-TOUCH-POINT — later phases EXTEND this file
///
/// Three later phases add to **this exact screen**, and must extend it
/// rather than creating a competing "business profile" screen:
///
/// * **Phase 5 (Products)** — DONE in Part P-034: [_ProductsSection],
///   appended at the marked section boundary in [_ProfileView] below.
/// * **Phase 7 (Posts/Reels)** — posts and reels sections, at the same
///   boundary, below products.
/// * **Phase 9 (Follow)** — activates the currently-disabled Follow
///   button in [_ProfileHeader], and is also where `followerCount`
///   (see note below) becomes real and displayable.
///
/// The layout is a plain scrolling [Column] precisely so those sections
/// can be appended without a relayout rewrite — deliberately NOT
/// over-engineered with empty placeholder widgets for models that don't
/// exist yet.
///
/// ## Part P-034 — the products section
///
/// [_ProductsSection] lists the business's active products (first page
/// only — cursor pagination's "load more" is out of scope, same
/// decision as Part P-033's own list), read through
/// `businessProductsProvider`. Its states are independent of the
/// profile's own: a failure loading products shows an inline error with
/// Retry inside the section and never replaces the whole profile.
/// Every product price is rendered through [ProductPriceFraming], so the
/// architecture Section 20 "approximate / negotiable" copy accompanies
/// every price shown here. Nothing in the section resembles a purchase
/// flow (no cart icon, no Buy Now, no quantity selector). Tapping a card
/// opens the real `ProductDetailScreen` via [RouteNames.productDetail].
///
/// ## `followerCount` is deliberately not displayed
///
/// The backend's `follower_count` is a hardcoded `0` placeholder
/// (`# TODO(Phase 9)` in `businesses/serializers.py` — confirmed in the
/// real source). Rendering "0 followers" would show a customer a
/// confident falsehood about every business on the platform. The field
/// is carried through the DTO/entity (Part P-028A) and simply not shown
/// until Phase 9 makes it real.
///
/// ## No logo/cover image
///
/// `BusinessProfile` has no image fields on the backend yet (P-024/
/// P-026), so this header is text-only. When image fields land, they
/// belong in [_ProfileHeader], above the name.
class BusinessProfilePublicScreen extends ConsumerWidget {
  const BusinessProfilePublicScreen({super.key, required this.businessId});

  /// The raw `:id` path parameter, as `go_router` hands it over — a
  /// [String], parsed here rather than by the router (see [build]).
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/` (`businesses/urls.py`), so a
    // non-numeric id can never identify a business — there is nothing
    // to fetch. Resolving it to the not-found state here avoids firing
    // a request guaranteed to fail, and avoids the fetch failing as a
    // generic error (Django answers a non-matching URL with an HTML
    // 404, not this API's JSON error envelope).
    final id = int.tryParse(businessId);
    if (id == null) {
      return const Scaffold(body: SafeArea(child: _NotFoundView()));
    }

    final profileAsync = ref.watch(businessProfilePublicProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: switch (profileAsync) {
        // Order matters: AsyncData is matched before the catch-all, and
        // its null case (a confirmed backend 404 — see
        // BusinessProfilePublicRepositoryImpl) is matched as its own
        // branch so "this business doesn't exist" never renders as a
        // generic error, per this part's acceptance criteria.
        AsyncData(value: final BusinessProfile profile) => _ProfileView(
          profile: profile,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// "This business doesn't exist" — deliberately an [EmptyStateWidget]
/// (P-006), NOT [ErrorStateWidget]: there is nothing to retry, and
/// offering a Retry button for a business that will never exist is
/// worse than saying so plainly.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      message: 'Business not found.\nIt may have been removed.',
      icon: Icons.storefront_outlined,
    );
  }
}

/// A genuine fetch failure (no connectivity, 5xx, an unexpected
/// payload) — retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both shapes are handled on purpose. `ErrorInterceptor` (P-004)
    // rethrows a NEW DioException carrying the typed ApiFailure in its
    // `.error` — that's what actually reaches this widget in production.
    // A bare ApiFailure is matched too, because that's what a
    // hand-rolled fake repository throws in this project's widget tests
    // (the same mismatch already present in
    // business_profile_edit_screen.dart's _ErrorView, flagged in this
    // part's PROJECT_PROGRESS.md entry as a pre-existing issue that
    // P-029 does not change).
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this business profile.',
    };

    return ErrorStateWidget(
      message: message,
      // Invalidating the family entry re-runs its fetch. Automatic
      // retry is disabled on this provider by design (see
      // business_profile_public_provider.dart), so this button is the
      // only thing that retries.
      onRetry: () => ref.invalidate(businessProfilePublicProvider(id)),
    );
  }
}

/// The loaded profile. Scrollable from the start so Phase 5/7 sections
/// can be appended with no structural change.
class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(profile: profile),

          // ---------------------------------------------------------
          // SECTION BOUNDARY — later phases append below this line.
          //   Phase 5: Products section  — DONE (Part P-034), below.
          //   Phase 7: Posts / Reels sections — append after products.
          // Add new sections here, in this Column, in this file. Do NOT
          // create a second business-profile screen. See this file's
          // top-level docstring.
          // ---------------------------------------------------------
          const SizedBox(height: 32),
          _ProductsSection(businessId: profile.id),
        ],
      ),
    );
  }
}

/// Name, type badge, verification badge, location, description and the
/// (disabled) Follow action.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = switch (profile.businessType) {
      BusinessType.trader => 'Trader',
      BusinessType.factory => 'Factory',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                profile.businessName,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            // Rendered ONLY when the backend says the business is
            // verified (`User.is_business_verified`, read-through, set
            // exclusively by an Admin action server-side — P-016/P-026).
            if (profile.isVerified) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified,
                size: 20,
                color: theme.colorScheme.primary,
                semanticLabel: 'Verified business',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(label: Text(typeLabel), visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${profile.city}, ${profile.country}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          profile.description.isEmpty
              ? 'This business hasn\'t added a description yet.'
              : profile.description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        // Present but non-functional on purpose — Follow is Phase 9.
        // Neither faked (no local-only toggle that silently loses the
        // action) nor omitted (its absence would change this header's
        // layout again in Phase 9).
        Row(
          children: [
            Tooltip(
              message: 'Following businesses arrives in a later phase.',
              child: const AppButton(label: 'Follow', onPressed: null),
            ),
            const SizedBox(width: 12),
            Text('(coming soon)', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Part P-034: the business's active products, first page only.
///
/// Owns its own loading/empty/error states so a products failure never
/// replaces the whole profile. Renders a plain [Column] of cards (not a
/// nested scrolling list) — it lives inside [_ProfileView]'s
/// [SingleChildScrollView], and the first page is small.
class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({required this.businessId});

  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(businessProductsProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Products', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        switch (productsAsync) {
          AsyncData(value: final products) when products.isEmpty =>
            const EmptyStateWidget(
              message: 'This business hasn\'t added any products yet.',
              icon: Icons.inventory_2_outlined,
            ),
          AsyncData(value: final products) => Column(
            children: [
              for (final product in products) _ProductCard(product: product),
            ],
          ),
          AsyncError(:final error) => _ProductsErrorView(
            error: error,
            businessId: businessId,
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingIndicator(),
          ),
        },
      ],
    );
  }
}

/// Inline, retryable failure for the products section only.
class _ProductsErrorView extends ConsumerWidget {
  const _ProductsErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same dual-shape handling as [_LoadErrorView] — see the comment
    // there.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this business\'s products.',
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessProductsProvider(businessId)),
    );
  }
}

/// One tappable product card: thumbnail, name, and the price WITH its
/// mandatory Section 20 framing ([ProductPriceFraming], compact). No
/// cart/buy/quantity affordance of any kind.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // `push` (not `go`) so the back button returns to this profile.
        onTap:
            () => context.pushNamed(
              RouteNames.productDetail,
              pathParameters: {RouteNames.idParam: '${product.id}'},
            ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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

/// Small square product image with a neutral fallback for "no image" and
/// for a URL that fails to load. Duplicates the private thumbnail in
/// `product_list_screen.dart` (Part P-033) rather than sharing it —
/// flagged in this part's PROJECT_PROGRESS entry.
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = imageUrl;

    Widget placeholder(IconData icon) => Container(
      width: size,
      height: size,
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child:
          (url == null || url.isEmpty)
              ? placeholder(Icons.inventory_2_outlined)
              : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
                        placeholder(Icons.broken_image_outlined),
              ),
    );
  }
}
