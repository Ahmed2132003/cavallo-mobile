/// Part P-044: the signed-in Business account's own Posts and Reels together
/// (`ownContentProvider`), tagged by type, each with an honest status chip.
/// (The long design notes of P-044 live in git history; the rules below are
/// unchanged.)
///
/// ### Architecture Rule (P-044, preserved exactly)
///
/// A business owner's UI must never imply content is live before its status
/// genuinely equals `published`:
/// * A Post always shows a real moderation chip (Under review / Live /
///   Rejected: reason).
/// * A Reel shows a DISTINCT "Processing video..." chip while
///   `ReelProcessingStatus.isBeforeModeration` is true, and a red "Video
///   processing failed" chip when processing failed. Once processing is
///   `ready`, the real moderation chip takes over.
/// * The rejection reason is ALWAYS visible to the business: the chip wraps
///   its text instead of cutting it.
///
/// Polling (a 5-second Timer owned by this State while a Reel is still
/// processing) is unchanged. Navigation is injected ([onCreatePost],
/// [onCreateReel]) as before.
///
/// Part P-115 (STEP 5) restyle, presentation only: shared `ConsoleRow`
/// anatomy, shared `AppStatusChip`, localized strings. No provider, polling or
/// callback changed.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../business_console/presentation/console_row.dart';
import '../domain/content_item_entity.dart';
import '../domain/moderation_status.dart';
import '../domain/reel_entity.dart';
import 'own_content_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

class ContentListScreen extends ConsumerStatefulWidget {
  const ContentListScreen({
    super.key,
    required this.onCreatePost,
    required this.onCreateReel,
  });

  /// Invoked when the user taps "New Post".
  final VoidCallback onCreatePost;

  /// Invoked when the user taps "New Reel".
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
  /// cancels any existing timer otherwise. Idempotent.
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
    final l10n = context.l10n;
    final contentAsync = ref.watch(ownContentProvider);

    contentAsync.whenData(_syncPolling);

    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.consoleContentTitle)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create-post',
            onPressed: widget.onCreatePost,
            icon: const Icon(Icons.image_outlined),
            label: Text(l10n.consoleContentNewPost),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create-reel',
            onPressed: widget.onCreateReel,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(l10n.consoleContentNewReel),
          ),
        ],
      ),
      body: switch (contentAsync) {
        AsyncData(value: final items) when items.isEmpty => EmptyStateWidget(
          message: l10n.consoleContentEmpty,
          icon: Icons.dynamic_feed_outlined,
        ),
        AsyncData(value: final items) => _ContentListView(items: items),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Extracts a human-readable message from a thrown failure (both shapes).
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
        fallback: context.l10n.consoleContentLoadFailed,
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _ContentListItem(item: items[index]),
      ),
    );
  }
}

/// One Post or Reel row: thumbnail, caption, type, and exactly one status chip
/// - either the Reel processing chip or the real moderation chip.
class _ContentListItem extends StatelessWidget {
  const _ContentListItem({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final reelItem = item is ReelContentItem ? item as ReelContentItem : null;
    final isReel = reelItem != null;
    final isReelBeforeModeration =
        reelItem != null && reelItem.reel.processingStatus.isBeforeModeration;
    final isReelFailed =
        reelItem != null &&
        reelItem.reel.processingStatus == ReelProcessingStatus.failed;

    final Widget status;
    if (isReelBeforeModeration) {
      status = AppStatusChip(
        label: l10n.consoleStatusProcessing,
        icon: Icons.hourglass_top,
        tone: AppStatusTone.neutral,
      );
    } else if (isReelFailed) {
      status = AppStatusChip(
        label: l10n.consoleStatusProcessingFailed,
        icon: Icons.error_outline,
        tone: AppStatusTone.danger,
      );
    } else {
      status = _moderationChip(context, item.moderationStatus);
    }

    return ConsoleRow(
      leading: ConsoleThumbnail(
        url: item.thumbnailUrl,
        placeholderIcon:
            isReel ? Icons.movie_creation_outlined : Icons.image_outlined,
      ),
      title: item.caption,
      titleMaxLines: 2,
      meta: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReel ? Icons.movie_creation_outlined : Icons.image_outlined,
              size: 16,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              isReel ? l10n.consoleTypeReel : l10n.consoleTypePost,
              style: text.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
      status: status,
    );
  }

  /// Under review (amber) / Live (green) / Rejected: reason (red).
  Widget _moderationChip(BuildContext context, ModerationStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      ModerationStatus.pendingReview => AppStatusChip(
        label: l10n.consoleStatusUnderReview,
        icon: Icons.hourglass_bottom,
        tone: AppStatusTone.warning,
      ),
      ModerationStatus.published => AppStatusChip(
        label: l10n.consoleStatusLive,
        icon: Icons.check_circle_outline,
        tone: AppStatusTone.success,
      ),
      ModerationStatus.rejected => AppStatusChip(
        // Defensive fallback: rejectionReason should always be non-null once
        // status == rejected, but the chip must never show a blank reason.
        label: l10n.consoleStatusRejectedWithReason(
          item.rejectionReason ?? l10n.consoleStatusNoReasonGiven,
        ),
        icon: Icons.cancel_outlined,
        tone: AppStatusTone.danger,
      ),
    };
  }
}
