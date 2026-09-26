/// Part P-062 scope: `StoriesBarWidget` -- the horizontally-scrolling
/// row of `StoryRingWidget` (Part P-050, reused with ZERO
/// modification) at the top of `DiscoverScreen` (a later step), one
/// ring per business that currently has an active Story.
///
/// ### businessName resolution -- per ring, non-blocking
///
/// `activeStoryGroupsProvider` (STEP 3) only carries a `businessId` per
/// group (Story payloads never carry a business name -- see
/// `PublicStory`'s own docstring), so each ring resolves its own
/// display name through the EXISTING `businessProfilePublicProvider`
/// (Part P-029) -- the exact same per-row, independent-failure pattern
/// `HomeFeedScreen`'s `_FeedListItem` already uses for the same reason
/// (`home_feed_screen.dart`, Part P-061): one slow/failed name lookup
/// never blocks the rest of the bar from rendering.
///
/// Renders nothing (`SizedBox.shrink()`) while loading, on error, or
/// when there are no active story groups at all -- same "small,
/// decorative discovery affordance, not primary content" reasoning
/// `StoryRingWidget` itself already documents; `DiscoverScreen` doesn't
/// need a dedicated loading/error/empty state carved out just for this
/// bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../stories/presentation/story_ring_widget.dart';
import 'discover_provider.dart';

class StoriesBarWidget extends ConsumerWidget {
  const StoriesBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(activeStoryGroupsProvider);

    // Pattern-matched rather than `.valueOrNull` -- same
    // flutter_riverpod 3.3.2 constraint `StoryRingWidget`'s own
    // docstring already documents.
    final groups = switch (groupsAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (groups == null || groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _StoryRingByBusinessId(businessId: groups[index].businessId),
      ),
    );
  }
}

/// One ring, resolving its own `businessName` independently of every
/// other ring in the bar -- see this file's own doc above for why.
class _StoryRingByBusinessId extends ConsumerWidget {
  const _StoryRingByBusinessId({required this.businessId});

  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfilePublicProvider(businessId));
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? 'Unknown business',
      _ => '',
    };

    return StoryRingWidget(businessId: businessId, businessName: businessName);
  }
}