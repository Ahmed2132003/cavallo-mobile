import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/grid_tile_media.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/profile_tab_bar.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../content/presentation/content_public_providers.dart';
import '../../products/presentation/product_public_providers.dart';
import '../../social/presentation/follow_button.dart';
import '../../social/presentation/social_interaction_provider.dart';
import '../../stories/presentation/story_public_provider.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_public_provider.dart';
import 'own_business_id_provider.dart';
import 'own_profile_edit_button.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-029: the customer-facing, READ-ONLY business profile screen behind
/// `/business/:id`.
///
/// ## Part P-114 STEP 3: Instagram-style layout (presentation only)
///
/// Same provider, same routes, same callbacks as before. Only the widget tree
/// changed:
///
/// * Header: avatar (with the story ring when the business has active
///   stories; tapping it opens the story viewer like the Home tray does),
///   a stats row (Posts, Followers, Products), name with the Verified mark
///   and the Featured badge, business type, location, bio, and an action row
///   (Follow filled / Following neutral, Message outlined).
/// * An icon tab bar (Posts grid, Reels grid, Products grid, Info) with
///   3-column grids. The tab bodies live inside the one scroll view (no
///   nested scrolling).
/// * Every list keeps its own loading / empty / error states; loading is a
///   grid of skeleton tiles, never a spinner.
///
/// ## Data contracts that did not change
///
/// * Posts, Reels and Products come from `businessPostsProvider`,
///   `businessReelsProvider` and `businessProductsProvider` (first page only,
///   no client-side filtering: the backend only returns published rows).
/// * Follow state lives in `businessFollowProvider`; [FollowButton] seeds it.
/// * Messaging uses `ConversationRepository.startConversationWithBusiness`,
///   the same call as the product screen's "Message Business".
/// * Prices are not shown in the Products grid; the product screen keeps the
///   mandatory "approximate / negotiable" framing. No cart, checkout or buy
///   affordance exists here.
///
/// KNOWN GAPS (flagged): the Posts and Products counts in the stats row are
/// the number of items in the FIRST PAGE (the API returns no total yet);
/// `BusinessProfile` has no rating, logo or cover, so none is drawn; there is
/// no business-level report/share contract yet, so the action row has no
/// overflow menu.
class BusinessProfilePublicScreen extends ConsumerWidget {
  const BusinessProfilePublicScreen({super.key, required this.businessId});

  /// The raw `:id` path parameter, as `go_router` hands it over.
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a business: resolve it to the not-found state without a
    // request.
    final id = int.tryParse(businessId);
    if (id == null) {
      return const Scaffold(body: SafeArea(child: _NotFoundView()));
    }

    final profileAsync = ref.watch(businessProfilePublicProvider(id));

    return Scaffold(
      appBar: CavalloAppBar(
        title: Text(context.l10n.profileScreenTitle),
        actions: <Widget>[OwnProfileEditButton(businessId: id)],
      ),
      body: switch (profileAsync) {
        // AsyncData is matched before the catch-all, and its null case (a
        // confirmed backend 404) is its own branch so "this business does
        // not exist" never renders as a generic error.
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

/// The message of a failure, or [fallback] when it is not an [ApiFailure].
///
/// Both shapes are handled on purpose: `ErrorInterceptor` rethrows a new
/// DioException carrying the typed ApiFailure in its `.error` (production),
/// while hand-rolled fakes in tests throw the bare ApiFailure.
String _failureMessage(Object error, String fallback) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

/// "This business doesn't exist": an [EmptyStateWidget], not an error, since
/// there is nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.profileNotFound,
      icon: Icons.storefront_outlined,
    );
  }
}

/// A genuine fetch failure (no connectivity, 5xx, unexpected payload):
/// retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _failureMessage(error, context.l10n.profileLoadFailed),
      // Automatic retry is disabled on this provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(businessProfilePublicProvider(id)),
    );
  }
}

/// The loaded profile: header, icon tab bar, and the selected tab's body, all
/// inside one scroll view.
class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.profile});

  final BusinessProfile profile;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;
  late final TabController _controller = TabController(
    length: _tabCount,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BusinessProfile profile = widget.profile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ProfileHeader(profile: profile),
          const SizedBox(height: 12),
          ProfileTabBar(
            controller: _controller,
            items: <ProfileTabItem>[
              ProfileTabItem(icon: Icons.grid_on, label: l10n.profileTabPosts),
              ProfileTabItem(
                icon: Icons.movie_outlined,
                label: l10n.profileTabReels,
              ),
              ProfileTabItem(
                icon: Icons.inventory_2_outlined,
                label: l10n.profileTabProducts,
              ),
              ProfileTabItem(
                icon: Icons.info_outline,
                label: l10n.profileTabInfo,
              ),
            ],
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? child) {
              return _TabBody(index: _controller.index, profile: profile);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.index, required this.profile});

  final int index;
  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => _PostsTab(
        businessId: profile.id,
        businessName: profile.businessName,
      ),
      1 => _ReelsTab(
        businessId: profile.id,
        businessName: profile.businessName,
      ),
      2 => _ProductsTab(businessId: profile.id),
      _ => _InfoTab(profile: profile),
    };
  }
}

/// Avatar + stats row, name line, type, location, bio and the action row.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile});

  final BusinessProfile profile;

  /// Shown instead of a count while the list is still loading or failed.
  static const String _countPlaceholder = '\u2013';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.appColors;
    final AppLocalizations l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);
    final TextTheme text = Theme.of(context).textTheme;

    final String typeLabel = switch (profile.businessType) {
      BusinessType.trader => l10n.businessTypeTrader,
      BusinessType.factory => l10n.businessTypeFactory,
    };

    // The same providers the tabs use: no extra request, and the counts are
    // the first page only (see the class docs of the screen).
    final String postsText = switch (ref.watch(
      businessPostsProvider(profile.id),
    )) {
      AsyncData(:final value) => formatters.compactCount(value.length),
      _ => _countPlaceholder,
    };
    final String productsText = switch (ref.watch(
      businessProductsProvider(profile.id),
    )) {
      AsyncData(:final value) => formatters.compactCount(value.length),
      _ => _countPlaceholder,
    };

    // Before FollowButton seeds the provider (one microtask after the first
    // frame) the state still holds its defaults: show the profile's value.
    final follow = ref.watch(businessFollowProvider(profile.id));
    final int followers =
        (follow.followersCount == 0 && !follow.isFollowing)
            ? profile.followerCount
            : follow.followersCount;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ProfileAvatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: StatItem(
                        value: postsText,
                        label: l10n.profileStatPosts,
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        value: formatters.compactCount(followers),
                        label: l10n.profileStatFollowers,
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        value: productsText,
                        label: l10n.profileStatProducts,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  profile.businessName,
                  style: text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Rendered ONLY when the backend says the business is
              // verified (set exclusively by an Admin action server-side).
              if (profile.isVerified) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.verified,
                  size: 18,
                  color: colors.brand,
                  semanticLabel: l10n.feedVerifiedLabel,
                ),
              ],
              // Display-only Featured badge (real P-087 state, P-110).
              if (profile.isFeatured) ...<Widget>[
                const SizedBox(width: 8),
                const FeaturedBadge(),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            typeLabel,
            style: text.labelLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.profileLocation(profile.city, profile.country),
                  style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.description.isEmpty
                ? l10n.profileNoDescription
                : profile.description,
            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 16),
          _ProfileActions(profile: profile),
        ],
      ),
    );
  }
}

/// The avatar, with the story ring when the business has active stories.
///
/// Uses the same providers as the Home tray's `StoryRingWidget`
/// (`businessStoriesProvider`, `viewedStoriesProvider`) and opens the same
/// route. A failed or empty stories fetch simply means "no ring".
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({required this.profile});

  final BusinessProfile profile;

  static const double _size = 86;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final stories = switch (ref.watch(businessStoriesProvider(profile.id))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final Set<int> viewed = ref.watch(viewedStoriesProvider(profile.id));

    final bool hasStories = stories != null && stories.isNotEmpty;
    final bool hasUnviewed =
        stories != null && stories.any((story) => !viewed.contains(story.id));

    final AppAvatarRing ring =
        !hasStories
            ? AppAvatarRing.none
            : (hasUnviewed ? AppAvatarRing.unseen : AppAvatarRing.seen);

    return Padding(
      // Same outer size with and without a ring, so the stats row does not
      // jump when the stories arrive.
      padding: EdgeInsets.all(
        hasStories ? 0 : AppAvatar.ringWidth + AppAvatar.ringGap,
      ),
      child: AppAvatar(
        name: profile.businessName,
        size: _size,
        ring: ring,
        semanticLabel:
            !hasStories
                ? null
                : (hasUnviewed
                    ? l10n.storyRingNewLabel(profile.businessName)
                    : l10n.storyRingSeenLabel(profile.businessName)),
        onTap:
            !hasStories
                ? null
                : () => context.pushNamed(
                  RouteNames.storyViewer,
                  pathParameters: <String, String>{
                    RouteNames.idParam: profile.id.toString(),
                  },
                  extra: profile.businessName,
                ),
      ),
    );
  }
}

/// Follow (filled) / Following (neutral) and Message (outlined).
///
/// The owner of the business sees no Message button: the backend refuses a
/// conversation with your own business.
class _ProfileActions extends ConsumerStatefulWidget {
  const _ProfileActions({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends ConsumerState<_ProfileActions> {
  bool _isStartingConversation = false;

  /// Starts (or resumes) the conversation with this business, then opens its
  /// thread. Same flow as the product screen's "Message Business". The
  /// router, messenger and texts are captured BEFORE the await so they are
  /// still valid afterwards; a second tap while a request is in flight is
  /// ignored.
  Future<void> _messageBusiness() async {
    if (_isStartingConversation) return;

    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    setState(() => _isStartingConversation = true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .startConversationWithBusiness(businessId: widget.profile.id);
      if (!mounted) return;
      setState(() => _isStartingConversation = false);

      if (conversation == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileMessageStarted)),
        );
        return;
      }

      router.pushNamed(
        RouteNames.chatThread,
        pathParameters: <String, String>{
          RouteNames.idParam: conversation.id.toString(),
        },
        extra: conversation,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingConversation = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiFailure ? e.message : l10n.profileMessageFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int? ownId = ref.watch(ownBusinessIdProvider);
    final bool isOwner = ownId != null && ownId == widget.profile.id;

    return Row(
      children: <Widget>[
        Expanded(
          child: FollowButton(
            businessId: widget.profile.id,
            followerCount: widget.profile.followerCount,
            showCount: false,
          ),
        ),
        if (!isOwner) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              label: l10n.profileMessageButton,
              variant: AppButtonVariant.outlined,
              isLoading: _isStartingConversation,
              onPressed: _messageBusiness,
            ),
          ),
        ],
      ],
    );
  }
}

/// A 3-column grid inside the profile's scroll view (so it never scrolls on
/// its own). The tiles have a fixed aspect ratio, so nothing jumps while the
/// images load.
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.children, this.childAspectRatio = 1});

  final List<Widget> children;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// Skeleton tiles shown while a tab loads (never a spinner).
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({this.childAspectRatio = 1});

  final double childAspectRatio;

  static const Key skeletonKey = ValueKey<String>('profile_grid_skeleton');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: skeletonKey,
      label: context.l10n.profileGridLoadingLabel,
      child: ExcludeSemantics(
        child: _MediaGrid(
          childAspectRatio: childAspectRatio,
          children: List<Widget>.generate(
            6,
            (int index) =>
                const SizedBox.expand(child: AppShimmerBox(borderRadius: 0)),
          ),
        ),
      ),
    );
  }
}

/// Posts tab: the business's published posts, first page only.
class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final postsAsync = ref.watch(businessPostsProvider(businessId));

    return switch (postsAsync) {
      AsyncData(value: final posts) when posts.isEmpty => EmptyStateWidget(
        message: l10n.profilePostsEmpty,
        icon: Icons.article_outlined,
      ),
      AsyncData(value: final posts) => _MediaGrid(
        children: <Widget>[
          for (final post in posts)
            GridTileMedia(
              key: ValueKey<String>('profile_post_${post.id}'),
              imageUrl: post.imageUrl,
              semanticLabel: l10n.feedPostMediaLabel(businessName),
              onTap:
                  () => context.pushNamed(
                    RouteNames.postDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${post.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profilePostsLoadFailed),
        onRetry: () => ref.invalidate(businessPostsProvider(businessId)),
      ),
      _ => const _GridSkeleton(),
    };
  }
}

/// Reels tab: 9:16 tiles with the video mark.
class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  static const double _aspect = 9 / 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final reelsAsync = ref.watch(businessReelsProvider(businessId));

    return switch (reelsAsync) {
      AsyncData(value: final reels) when reels.isEmpty => EmptyStateWidget(
        message: l10n.profileReelsEmpty,
        icon: Icons.movie_outlined,
      ),
      AsyncData(value: final reels) => _MediaGrid(
        childAspectRatio: _aspect,
        children: <Widget>[
          for (final reel in reels)
            GridTileMedia(
              key: ValueKey<String>('profile_reel_${reel.id}'),
              imageUrl: reel.thumbnailUrl,
              aspectRatio: _aspect,
              badge: GridTileBadge.video,
              semanticLabel: l10n.feedReelMediaLabel(businessName),
              onTap:
                  () => context.pushNamed(
                    RouteNames.reelDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${reel.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profileReelsLoadFailed),
        onRetry: () => ref.invalidate(businessReelsProvider(businessId)),
      ),
      _ => const _GridSkeleton(childAspectRatio: _aspect),
    };
  }
}

/// Products tab: square tiles with the product name under each one. The price
/// is deliberately not drawn here; the product screen shows it with the
/// mandatory discovery-only framing.
class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.businessId});

  final int businessId;

  /// Tile (square image) plus one line of text under it.
  static const double _aspect = 0.72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final productsAsync = ref.watch(businessProductsProvider(businessId));

    return switch (productsAsync) {
      AsyncData(value: final products) when products.isEmpty =>
        EmptyStateWidget(
          message: l10n.profileProductsEmpty,
          icon: Icons.inventory_2_outlined,
        ),
      AsyncData(value: final products) => _MediaGrid(
        childAspectRatio: _aspect,
        children: <Widget>[
          for (final product in products)
            _ProductTile(
              key: ValueKey<String>('profile_product_${product.id}'),
              name: product.name,
              imageUrl: product.imageUrl,
              // `push` (not `go`) so the back button returns to this profile.
              onTap:
                  () => context.pushNamed(
                    RouteNames.productDetail,
                    pathParameters: <String, String>{
                      RouteNames.idParam: '${product.id}',
                    },
                  ),
            ),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: _failureMessage(error, l10n.profileProductsLoadFailed),
        onRetry: () => ref.invalidate(businessProductsProvider(businessId)),
      ),
      _ => const _GridSkeleton(childAspectRatio: _aspect),
    };
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GridTileMedia(imageUrl: imageUrl, semanticLabel: name, onTap: onTap),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Info tab: business type, location and phone (the bio is in the header).
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String typeLabel = switch (profile.businessType) {
      BusinessType.trader => l10n.businessTypeTrader,
      BusinessType.factory => l10n.businessTypeFactory,
    };
    final String? phone = profile.phoneNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: l10n.profileInfoType,
            value: typeLabel,
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: l10n.profileInfoLocation,
            value: l10n.profileLocation(profile.city, profile.country),
          ),
          if (phone != null && phone.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: l10n.profileInfoPhone,
              value: phone,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(
        label,
        style: text.labelMedium?.copyWith(color: colors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: text.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
    );
  }
}
