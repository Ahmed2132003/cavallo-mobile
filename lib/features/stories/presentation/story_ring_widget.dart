import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../routing/route_names.dart';
import 'story_public_provider.dart';

/// Part P-050 scope: the small circular avatar-with-ring indicator of one
/// business that currently has stories. Used by the Home and Discover stories
/// tray ([StoriesBarWidget]) and on a business profile. Tapping it opens
/// `StoryViewerScreen` for this one business's current story sequence.
///
/// Part P-114 STEP 1 (presentation only): the ring is drawn by the shared
/// [AppAvatar] -- the blue gradient ring while at least one story is unseen,
/// the outline-colour ring once every story has been seen. The data flow is
/// exactly the one of P-050: [businessStoriesProvider] decides whether
/// anything is drawn, [viewedStoriesProvider] decides seen / unseen, and a tap
/// pushes [RouteNames.storyViewer] with the business name as `extra`.
///
/// Renders NOTHING (`SizedBox.shrink()`) when the business has no
/// currently-visible stories, or while that first fetch is loading or failed:
/// it is a small discovery affordance, not primary content.
///
/// `BusinessProfile` still has no logo field, so the avatar shows the initials
/// of [businessName] (the shared [AppAvatar] fallback).
class StoryRingWidget extends ConsumerWidget {
  const StoryRingWidget({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final int businessId;
  final String businessName;

  /// Diameter of the photo inside the ring.
  static const double avatarSize = 62;

  /// Width of one tile of the tray (ring + label).
  static const double tileWidth = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(businessStoriesProvider(businessId));
    final viewedIds = ref.watch(viewedStoriesProvider(businessId));

    // Pattern-matched rather than `.valueOrNull` -- that getter isn't
    // available on this project's pinned flutter_riverpod version (3.3.2).
    final stories = switch (storiesAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (stories == null || stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool hasUnviewed = stories.any(
      (story) => !viewedIds.contains(story.id),
    );
    final AppColors colors = context.appColors;
    final String semanticLabel =
        hasUnviewed
            ? context.l10n.storyRingNewLabel(businessName)
            : context.l10n.storyRingSeenLabel(businessName);

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            () => context.pushNamed(
              RouteNames.storyViewer,
              pathParameters: {RouteNames.idParam: businessId.toString()},
              extra: businessName,
            ),
        child: SizedBox(
          width: tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                name: businessName,
                size: avatarSize,
                ring: hasUnviewed ? AppAvatarRing.unseen : AppAvatarRing.seen,
              ),
              const SizedBox(height: 4),
              Text(
                businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      hasUnviewed ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
