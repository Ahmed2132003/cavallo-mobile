import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';
import 'story_public_provider.dart';

/// Part P-050 scope: the small circular avatar-with-ring indicator
/// shown on a Business Profile page's story row today, and Phase 10's
/// Discover screen stories bar once it exists (`story_ring_widget.dart`
/// is built now as a genuinely reusable component ahead of that
/// consumer -- same precedent as `PostCard`/`ReelCard`, Part P-045,
/// built ahead of Feed). Tapping it opens `StoryViewerScreen` for this
/// one business's current story sequence.
///
/// Deliberately renders NOTHING (`SizedBox.shrink()`) when the
/// business has no currently-visible stories, or while that first
/// fetch is loading/erroring -- this is a small, decorative discovery
/// affordance, not a primary content surface. A caller placing several
/// of these in a row (a future stories bar) gets a naturally sparse
/// row with no placeholder gaps or per-ring error/retry UI cluttering
/// it; the caller's own screen already owns its own loading/error
/// handling for whatever primary content the ring sits alongside.
///
/// No `businessAvatarUrl` parameter, same precedent as `PostCard`
/// (Part P-045): `BusinessProfile` has no logo field on the backend at
/// all yet. The ring's center shows [businessName]'s first letter
/// instead, same idea as `_ProfileHeader`'s own text-only identity
/// treatment.
class StoryRingWidget extends ConsumerWidget {
  const StoryRingWidget({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(businessStoriesProvider(businessId));
    final viewedIds = ref.watch(viewedStoriesProvider(businessId));

    // Pattern-matched rather than `.valueOrNull` -- that getter isn't
    // available on this project's pinned flutter_riverpod version
    // (3.3.2), same already-confirmed blocker `app_router.dart`'s own
    // `redirect` callback works around (see that file's `AsyncData(
    // :final value)` note).
    final stories = switch (storiesAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (stories == null || stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasUnviewed = stories.any((story) => !viewedIds.contains(story.id));
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.storyViewer,
        pathParameters: {RouteNames.idParam: businessId.toString()},
        extra: businessName,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasUnviewed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: 2.5,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                businessName.isNotEmpty ? businessName[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 68,
            child: Text(
              businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}