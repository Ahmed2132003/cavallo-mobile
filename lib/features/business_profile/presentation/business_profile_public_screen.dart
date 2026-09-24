import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../social/presentation/follow_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../../content/domain/public_post_entity.dart';
import '../../content/domain/public_reel_entity.dart';
import '../../content/presentation/content_public_providers.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
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
/// * **Phase 7 (Posts/Reels)** — DONE in Part P-045 (STEP 6):
///   [_PostsSection]/[_ReelsSection], appended right after products.
/// * **Phase 9 (Follow)** — DONE in Part P-058: [_ProfileHeader] now
///   renders `FollowButton` (real Follow/Following + follower count).
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
/// ## Part P-045 (STEP 6) — the Posts/Reels sections
///
/// [_PostsSection]/[_ReelsSection] follow [_ProductsSection]'s exact
/// shape: own independent loading/empty/error states, first page only,
/// read through `businessPostsProvider`/`businessReelsProvider`
/// (`content_public_providers.dart`, this part's own STEP 6 addition).
///
/// Neither section applies any client-side filtering of its own. Both
/// `PostPublicRepositoryImpl.fetchBusinessPosts` and
/// `ReelPublicRepositoryImpl.fetchBusinessReels` (Part P-045, STEP 1)
/// call the backend's `/public/` list endpoints
/// (`PostPublicListView`/`ReelPublicListView`, Part P-043), whose own
/// managers (`Post.published_objects`/`Reel.published_objects`) are the
/// actual enforcement point for "published only" — this screen trusts
/// and displays whatever those repositories return, exactly the same
/// trust relationship [_ProductsSection] already has with
/// `businessProductsProvider`. A second, redundant filter here would
/// only hide a real backend bug instead of surfacing it.
///
/// Each item renders through [PostCard]/[ReelCard] (Part P-045, STEP
/// 2/3) — the same reusable widgets Phase 10's Feed (Part P-061) will
/// import unmodified — wrapped with a tap handler that pushes the real
/// `PostDetailScreen`/`ReelDetailScreen` via [RouteNames.postDetail]/
/// [RouteNames.reelDetail], same `context.pushNamed` convention as
/// [_ProductCard]'s own tap handler below.
///
/// ## Part P-058 — Follow and `followerCount`
///
/// [_ProfileHeader] renders `FollowButton`
/// (`features/social/presentation/follow_button.dart`), seeded with the
/// real `profile.followerCount` (real and atomically updated since
/// P-052). The count changes optimistically on each tap and is reverted
/// on failure. This screen deliberately does NOT refetch the profile
/// after a toggle, because invalidating `businessProfilePublicProvider`
/// would swap the whole screen to its loading state.
///
/// KNOWN GAP: the backend exposes no `is_following` field, so a fresh
/// app session always starts as "Follow"; only follows made in the
/// current session are remembered. Follow is idempotent server-side, so
/// tapping "Follow" on an already-followed business is harmless.
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
          //   Phase 5: Products section       — DONE (Part P-034).
          //   Phase 7: Posts / Reels sections  — DONE (Part P-045).
          // Add new sections here, in this Column, in this file. Do NOT
          // create a second business-profile screen. See this file's
          // top-level docstring.
          // ---------------------------------------------------------
          const SizedBox(height: 32),
          _ProductsSection(businessId: profile.id),
          const SizedBox(height: 32),
          _PostsSection(
            businessId: profile.id,
            businessName: profile.businessName,
          ),
          const SizedBox(height: 32),
          _ReelsSection(
            businessId: profile.id,
            businessName: profile.businessName,
          ),
        ],
      ),
    );
  }
}

/// Name, type badge, verification badge, location, description and the
/// Follow action (real since Part P-058).
/// Follow action (real, Part P-058).
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
        // Part P-058: the real Follow / Following button + follower count.
        // State lives in `businessFollowProvider(profile.id)`, seeded with
        // the real `followerCount` the backend returned (real since P-052).
        FollowButton(
          businessId: profile.id,
          followerCount: profile.followerCount,
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

/// Part P-045 (STEP 6): the business's published Posts, first page only.
///
/// Same shape as [_ProductsSection] — owns its own loading/empty/error
/// states so a Posts failure never replaces the whole profile, and never
/// re-filters what `businessPostsProvider` returns (see this file's
/// class-level docstring, "Part P-045 (STEP 6)" section, for why a
/// second filter here would be redundant and would only hide a real
/// backend bug).
class _PostsSection extends ConsumerWidget {
  const _PostsSection({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(businessPostsProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Posts', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        switch (postsAsync) {
          AsyncData(value: final posts) when posts.isEmpty =>
            const EmptyStateWidget(
              message: 'This business hasn\'t shared any posts yet.',
              icon: Icons.article_outlined,
            ),
          AsyncData(value: final posts) => Column(
            children: [
              for (final post in posts)
                _PostListItem(post: post, businessName: businessName),
            ],
          ),
          AsyncError(:final error) => _PostsErrorView(
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

/// Inline, retryable failure for the Posts section only.
class _PostsErrorView extends ConsumerWidget {
  const _PostsErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same dual-shape handling as [_LoadErrorView]/[_ProductsErrorView].
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this business\'s posts.',
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessPostsProvider(businessId)),
    );
  }
}

/// Wraps [PostCard] (Part P-045, STEP 2) with this screen's own tap
/// behavior — pushing the real `PostDetailScreen` via
/// [RouteNames.postDetail] — and the vertical spacing this section's
/// plain [Column] layout needs. [PostCard] itself stays free of any
/// navigation dependency, same as [_ProductCard] does for
/// `ProductDetailScreen`.
class _PostListItem extends StatelessWidget {
  const _PostListItem({required this.post, required this.businessName});

  final PublicPost post;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PostCard(
        post: post,
        businessName: businessName,
        onTap:
            () => context.pushNamed(
              RouteNames.postDetail,
              pathParameters: {RouteNames.idParam: '${post.id}'},
            ),
      ),
    );
  }
}

/// Part P-045 (STEP 6): the business's published, fully-processed Reels,
/// first page only. Same shape, same "no redundant re-filtering"
/// reasoning as [_PostsSection] — see that class's docstring.
class _ReelsSection extends ConsumerWidget {
  const _ReelsSection({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reelsAsync = ref.watch(businessReelsProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reels', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        switch (reelsAsync) {
          AsyncData(value: final reels) when reels.isEmpty =>
            const EmptyStateWidget(
              message: 'This business hasn\'t shared any reels yet.',
              icon: Icons.movie_outlined,
            ),
          AsyncData(value: final reels) => Column(
            children: [
              for (final reel in reels)
                _ReelListItem(reel: reel, businessName: businessName),
            ],
          ),
          AsyncError(:final error) => _ReelsErrorView(
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

/// Inline, retryable failure for the Reels section only.
class _ReelsErrorView extends ConsumerWidget {
  const _ReelsErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this business\'s reels.',
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessReelsProvider(businessId)),
    );
  }
}

/// Wraps [ReelCard] (Part P-045, STEP 3) with this screen's own tap
/// behavior — pushing the real `ReelDetailScreen` via
/// [RouteNames.reelDetail]. Same shape as [_PostListItem].
class _ReelListItem extends StatelessWidget {
  const _ReelListItem({required this.reel, required this.businessName});

  final PublicReel reel;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ReelCard(
        reel: reel,
        businessName: businessName,
        onTap:
            () => context.pushNamed(
              RouteNames.reelDetail,
              pathParameters: {RouteNames.idParam: '${reel.id}'},
            ),
      ),
    );
  }
}