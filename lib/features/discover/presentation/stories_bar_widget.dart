/// Part P-062 scope: `StoriesBarWidget` -- the horizontally-scrolling row of
/// `StoryRingWidget` at the top of the Home feed and the Discover screen, one
/// ring per business that currently has an active Story.
///
/// ### businessName resolution -- per ring, non-blocking
///
/// `activeStoryGroupsProvider` only carries a `businessId` per group, so each
/// ring resolves its own display name through the EXISTING
/// `businessProfilePublicProvider` (Part P-029) -- one slow/failed name lookup
/// never blocks the rest of the bar from rendering.
///
/// Renders nothing (`SizedBox.shrink()`) while loading, on error, or when
/// there are no active story groups -- unless [showOwnStoryTile] is true.
///
/// ### Part P-114 STEP 1 (presentation only)
///
/// * Directional padding (`EdgeInsetsDirectional`), so the tray starts at the
///   right edge in Arabic.
/// * [showOwnStoryTile]: Business accounts see their own "+" tile FIRST. The
///   caller (Home) decides from the session whether the account is a Business;
///   this widget reads no new provider. The tile opens the EXISTING story
///   creation route ([RouteNames.storyForm]); it adds no new capability.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../stories/presentation/story_ring_widget.dart';
import 'discover_provider.dart';

class StoriesBarWidget extends ConsumerWidget {
  const StoriesBarWidget({super.key, this.showOwnStoryTile = false});

  /// Business accounts: show the "+" tile (your story) before every ring.
  final bool showOwnStoryTile;

  static const double height = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(activeStoryGroupsProvider);

    // Pattern-matched rather than `.valueOrNull` -- same flutter_riverpod
    // 3.3.2 constraint `StoryRingWidget` documents.
    final groups = switch (groupsAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final int groupCount = groups?.length ?? 0;
    if (groupCount == 0 && !showOwnStoryTile) {
      return const SizedBox.shrink();
    }

    final int offset = showOwnStoryTile ? 1 : 0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        itemCount: groupCount + offset,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (showOwnStoryTile && index == 0) {
            return const _OwnStoryTile();
          }
          return _StoryRingByBusinessId(
            businessId: groups![index - offset].businessId,
          );
        },
      ),
    );
  }
}

/// One ring, resolving its own `businessName` independently of every other
/// ring in the bar -- see this file's own doc above for why.
class _StoryRingByBusinessId extends ConsumerWidget {
  const _StoryRingByBusinessId({required this.businessId});

  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfilePublicProvider(businessId));
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? context.l10n.businessUnknownName,
      _ => '',
    };

    return StoryRingWidget(businessId: businessId, businessName: businessName);
  }
}

/// "Your story" tile for Business accounts: avatar with a blue "+" badge.
/// Opens the existing story creation form.
class _OwnStoryTile extends StatelessWidget {
  const _OwnStoryTile();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String label = context.l10n.storyYourStory;

    return Semantics(
      button: true,
      label: context.l10n.storyAddTooltip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pushNamed(RouteNames.storyForm),
        child: SizedBox(
          width: StoryRingWidget.tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Same outer size as a ringed avatar, so the labels of all
                  // tiles line up.
                  const Padding(
                    padding: EdgeInsets.all(
                      AppAvatar.ringWidth + AppAvatar.ringGap,
                    ),
                    child: AppAvatar(size: StoryRingWidget.avatarSize),
                  ),
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.brand,
                        border: Border.all(
                          color: colors.background,
                          width: 2,
                        ),
                      ),
                      child: Icon(Icons.add, size: 16, color: colors.onBrand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}