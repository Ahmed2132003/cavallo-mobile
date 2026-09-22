/// Part P-044 scope: `lib/features/content/presentation/
/// content_list_screen.dart` — shows the signed-in Business account's
/// own Posts and Reels together (`ownContentProvider`, STEP 4 of this
/// part), tagged by type, each with an honest moderation-status badge.
/// Mirrors `ProductListScreen`'s (Part P-033) exact
/// `switch (asyncValue) { AsyncData... AsyncError... _ => Loading }`
/// pattern, its `ErrorStateWidget`/`EmptyStateWidget`/`LoadingIndicator`
/// (Part P-006) usage, and its shared `_apiFailureMessage` helper
/// (handles both the bare-`ApiFailure`-from-test-fakes shape and the
/// real `DioException(error: ApiFailure)` production shape).
///
/// ### Architecture Rule enforced here (P-044's own explicit spec)
///
/// A business owner's UI must never imply content is live/visible
/// before its status genuinely equals `published`. Concretely:
/// * A Post always shows a real moderation badge (Under review / Live
///   / Rejected).
/// * A Reel shows a DISTINCT "Processing video..." indicator while
///   [ReelProcessingStatus.isBeforeModeration] is true — it has not
///   even reached moderation yet, so showing "Under review" for it
///   would be misleading (this part's spec says so explicitly). Once
///   processing reaches `ready`, the real moderation badge takes over,
///   exactly like a Post.
///
/// ### `processing_status: failed` — an explicit choice beyond the
/// literal Acceptance Criteria
///
/// P-044's own spec only calls out `uploaded`/`processing` as the
/// pre-moderation states needing a distinct indicator; `failed` (a
/// real, reachable state per P-042's own known issues — e.g. a corrupt
/// upload) is left unaddressed by the spec text. Silently falling back
/// to a generic/blank badge for it would be its own kind of dishonest
/// UI, so it gets its own explicit red "Video processing failed" state
/// here — flagged as an addition, not a literal requirement.
///
/// ### Polling for Reel processing status (documented MVP choice, per
/// this part's own spec: "a simple refresh-on-screen-focus or a
/// short-interval poll ... is acceptable for MVP")
///
/// Implemented as a plain 5-second [Timer] owned by this screen's
/// [State] (not inside `OwnContentNotifier` — polling is a
/// presentation-layer/visibility concern, kept out of the notifier so
/// it stays a plain, reusable data-merge class). The timer:
/// * is only ever running while [state]'s current data contains at
///   least one [ReelContentItem] with
///   [ReelProcessingStatus.isBeforeModeration] true;
/// * is (re)armed after every successful [build]/[refresh] that still
///   finds such a Reel, and is cancelled the moment none remain;
/// * is always cancelled in [dispose] — no Timer callback ever fires
///   after this screen is gone.
/// No WebSocket/streaming channel — same reasoning already recorded in
/// this part's own execution prompt (Chat's WebSocket infrastructure
/// doesn't exist until Phase 12; building one just for this would be
/// premature).
///
/// ### Two content types, one "Create" action
///
/// Unlike `ProductListScreen`'s single "Create New" FAB, this screen
/// needs two distinct creation entry points (Post vs Reel — different
/// forms, different media type). Implemented as two stacked
/// `FloatingActionButton.extended` widgets rather than a single FAB
/// with a popup menu, so both actions are always one visible tap away
/// with no extra menu-open step — acceptable screen-space cost at this
/// list's expected size (a business's own content, not a long public
/// feed).
///
/// ### Navigation is injected, not hardcoded — same deliberate,
/// flagged reason as `ProductListScreen` (Part P-033)
///
/// `RouteNames` has no entries yet for the Post/Reel creation forms —
/// those routes (STEP 8 of this part) don't exist as of this file. So
/// this screen takes [onCreatePost]/[onCreateReel] as required
/// callbacks, exactly mirroring `ProductListScreen.onCreateNew`'s own
/// documented reasoning.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/content_item_entity.dart';
import '../domain/moderation_status.dart';
import '../domain/reel_entity.dart';
import 'own_content_provider.dart';

class ContentListScreen extends ConsumerStatefulWidget {
  const ContentListScreen({
    super.key,
    required this.onCreatePost,
    required this.onCreateReel,
  });

  /// Invoked when the user taps "New Post". The caller (eventually
  /// `app_router.dart`, STEP 8) is responsible for navigating to
  /// `PostFormScreen`.
  final VoidCallback onCreatePost;

  /// Invoked when the user taps "New Reel". The caller is responsible
  /// for navigating to `ReelFormScreen`.
  final VoidCallback onCreateReel;

  @override
  ConsumerState<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends ConsumerState<ContentListScreen> {
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Arms a 5-second poll if [items] contains a still-processing Reel,
  /// cancels any existing timer otherwise. Safe to call on every
  /// successful build — re-arming an already-running timer is a no-op
  /// in effect (it just gets cancelled and replaced), and this method
  /// is idempotent by construction.
  void _syncPolling(List<ContentItem> items) {
    final stillProcessing = items.any(
      (item) =>
          item is ReelContentItem &&
          item.reel.processingStatus.isBeforeModeration,
    );

    if (!stillProcessing) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }

    if (_pollTimer != null) {
      return; // already polling
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(ownContentProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(ownContentProvider);

    contentAsync.whenData(_syncPolling);

    return Scaffold(
      appBar: AppBar(title: const Text('My Content')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create-post',
            onPressed: widget.onCreatePost,
            icon: const Icon(Icons.image_outlined),
            label: const Text('New Post'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create-reel',
            onPressed: widget.onCreateReel,
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('New Reel'),
          ),
        ],
      ),
      body: switch (contentAsync) {
        AsyncData(value: final items) when items.isEmpty =>
          const EmptyStateWidget(
            message:
                'No posts or reels yet.\nTap "New Post" or "New Reel" to '
                'share your first one.',
            icon: Icons.dynamic_feed_outlined,
          ),
        AsyncData(value: final items) => _ContentListView(items: items),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Extracts a human-readable message from a thrown failure — identical
/// to `ProductListScreen`'s own `_apiFailureMessage` (Part P-033),
/// duplicated here rather than shared/imported: it is a tiny, stable,
/// feature-local helper, and every other feature in this project
/// (moderation, products) already keeps its own copy rather than
/// introducing a shared cross-feature presentation utility for it.
String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _apiFailureMessage(
        error,
        fallback: 'Could not load your content.',
      ),
      onRetry: () => ref.read(ownContentProvider.notifier).refresh(),
    );
  }
}

class _ContentListView extends ConsumerWidget {
  const _ContentListView({required this.items});

  final List<ContentItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownContentProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _ContentListItem(item: items[index]),
      ),
    );
  }
}

/// One Post or Reel row: thumbnail, type icon, caption, and exactly one
/// status indicator — either the Reel processing chip or the real
/// moderation badge. See this file's module docstring for the exact
/// rule governing which one shows.
class _ContentListItem extends StatelessWidget {
  const _ContentListItem({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reelItem = item is ReelContentItem ? item as ReelContentItem : null;
    final isReelBeforeModeration =
        reelItem != null && reelItem.reel.processingStatus.isBeforeModeration;
    final isReelFailed =
        reelItem != null &&
        reelItem.reel.processingStatus == ReelProcessingStatus.failed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContentThumbnail(
              thumbnailUrl: item.thumbnailUrl,
              isVideo: item is ReelContentItem,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item is ReelContentItem
                            ? Icons.movie_creation_outlined
                            : Icons.image_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item is ReelContentItem ? 'Reel' : 'Post',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.caption,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (isReelBeforeModeration)
                    const _ProcessingBadge()
                  else if (isReelFailed)
                    const _ProcessingFailedBadge()
                  else
                    _ModerationStatusBadge(
                      status: item.moderationStatus,
                      rejectionReason: item.rejectionReason,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail — the real network image when [thumbnailUrl] is set, a
/// neutral placeholder otherwise (a Reel still processing has no
/// thumbnail yet — a valid, expected state, not an error). [isVideo]
/// only changes the placeholder icon.
class _ContentThumbnail extends StatelessWidget {
  const _ContentThumbnail({required this.thumbnailUrl, required this.isVideo});

  final String? thumbnailUrl;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final url = thumbnailUrl;
    final placeholderIcon = isVideo
        ? Icons.movie_creation_outlined
        : Icons.image_outlined;

    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(placeholderIcon),
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

/// amber "Under review" / green "Live" / red "Rejected: {reason}" —
/// palette matches `QueueAgeChip`'s existing green/amber/red convention
/// (Part P-040), so status urgency reads consistently across the whole
/// app.
class _ModerationStatusBadge extends StatelessWidget {
  const _ModerationStatusBadge({
    required this.status,
    required this.rejectionReason,
  });

  final ModerationStatus status;
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon, label) = switch (status) {
      ModerationStatus.pendingReview => (
        Colors.amber.shade50,
        Colors.amber.shade800,
        Icons.hourglass_bottom,
        'Under review',
      ),
      ModerationStatus.published => (
        Colors.green.shade50,
        Colors.green.shade700,
        Icons.check_circle_outline,
        'Live',
      ),
      ModerationStatus.rejected => (
        Colors.red.shade50,
        Colors.red.shade700,
        Icons.cancel_outlined,
        // Defensive fallback: rejectionReason should always be
        // non-null once status == rejected (STEP 1's backend
        // addition), but a badge must never show a blank reason if
        // that contract is ever violated.
        'Rejected: ${rejectionReason ?? 'no reason given'}',
      ),
    };

    return _StatusChip(
      background: background,
      foreground: foreground,
      icon: icon,
      label: label,
    );
  }
}

/// Distinct from [_ModerationStatusBadge] on purpose — a Reel in
/// `uploaded`/`processing` has not reached moderation at all yet, so
/// showing "Under review" here would be misleading (P-044's own
/// explicit Architecture Rule).
class _ProcessingBadge extends StatelessWidget {
  const _ProcessingBadge();

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      background: Colors.blueGrey.shade50,
      foreground: Colors.blueGrey.shade700,
      icon: Icons.hourglass_top,
      label: 'Processing video…',
    );
  }
}

/// See this file's module docstring ("`processing_status: failed` —
/// an explicit choice beyond the literal Acceptance Criteria").
class _ProcessingFailedBadge extends StatelessWidget {
  const _ProcessingFailedBadge();

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      background: Colors.red.shade50,
      foreground: Colors.red.shade700,
      icon: Icons.error_outline,
      label: 'Video processing failed',
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}