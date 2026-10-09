import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../domain/comment_entity.dart';
import 'comment_list_provider.dart';
import 'content_interaction_key.dart';
import 'content_overflow_menu.dart';

/// Part P-058 + P-114 STEP 4B: the comment list for one Post/Reel. Renders
/// exactly what the backend returns (no client-side hidden-comment
/// filtering). A comment with `isHidden: true` is only ever present for its
/// own author or a moderator, so it gets a subtle "pending review" marker.
///
/// P-114: avatar rows (AppAvatar), relative time (AppFormatters), a skeleton
/// instead of a spinner, every text from the ARB files. No provider, repository
/// or callback changed.
///
/// KNOWN GAP: the backend `user` field is a bare id (no username/avatar), so
/// authors render as "User #id" with the neutral avatar until a backend part
/// adds an author object.
class CommentListWidget extends ConsumerStatefulWidget {
  const CommentListWidget({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  ConsumerState<CommentListWidget> createState() => _CommentListWidgetState();
}

class _CommentListWidgetState extends ConsumerState<CommentListWidget> {
  ContentInteractionKey get _key => (
    contentType: widget.contentType,
    objectId: widget.objectId,
  );

  @override
  void initState() {
    super.initState();
    // Provider state can't be modified during the build phase, so defer.
    Future.microtask(() {
      if (mounted) {
        ref.read(commentListProvider(_key).notifier).loadFirstPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentListProvider(_key));
    final notifier = ref.read(commentListProvider(_key).notifier);
    final error = state.error;
    final colors = context.appColors;
    final l10n = context.l10n;

    if (state.isLoading && state.items.isEmpty) {
      return Semantics(
        label: l10n.commentsLoadingLabel,
        child: const ExcludeSemantics(
          child: Column(
            children: [
              _CommentSkeletonRow(),
              _CommentSkeletonRow(),
              _CommentSkeletonRow(),
            ],
          ),
        ),
      );
    }

    if (error != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            TextButton(
              onPressed: notifier.loadFirstPage,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.commentsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in state.items)
          _CommentTile(key: ValueKey(comment.id), comment: comment),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(error, style: TextStyle(color: colors.dangerText)),
          ),
        if (state.nextUrl != null)
          state.isLoadingMore
              ? const _CommentSkeletonRow()
              : Center(
                child: TextButton(
                  onPressed: notifier.loadMore,
                  child: Text(l10n.commentsLoadMore),
                ),
              ),
      ],
    );
  }
}

/// Skeleton of one comment row (avatar + two text lines).
class _CommentSkeletonRow extends StatelessWidget {
  const _CommentSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox.circle(size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(width: 110, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                AppShimmerBox(
                  width: double.infinity,
                  height: 12,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({super.key, required this.comment});

  final CommentEntity comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = context.l10n;
    final author = l10n.commentsAuthorFallback(comment.userId.toString());
    final time = AppFormatters(l10n).relativeTime(comment.createdAt);
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(size: 36, semanticLabel: author),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(time, style: metaStyle),
                if (comment.isHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.commentsPendingReview,
                            style: metaStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ContentOverflowMenu(contentType: 'comment', objectId: comment.id),
        ],
      ),
    );
  }
}
