import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/comment_entity.dart';
import 'comment_list_provider.dart';
import 'content_interaction_key.dart';
import 'content_overflow_menu.dart';

/// Part P-058: the comment list for one Post/Reel. Renders exactly what the
/// backend returns (no client-side hidden-comment filtering). A comment with
/// `isHidden: true` is only ever present for its own author or a moderator,
/// so it gets a subtle "pending review" marker.
///
/// KNOWN GAP: the backend `user` field is a bare id (no username/avatar), so
/// authors render as "User # plus the id" until a backend part adds an author object.
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
  ContentInteractionKey get _key =>
      (contentType: widget.contentType, objectId: widget.objectId);

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

    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No comments yet. Be the first to comment.')),
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
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (state.nextUrl != null)
          Center(
            child: state.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                : TextButton(
                    onPressed: notifier.loadMore,
                    child: const Text('Load more comments'),
                  ),
          ),
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({super.key, required this.comment});

  final CommentEntity comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text('User #${comment.userId}', style: theme.textTheme.labelLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.text),
          const SizedBox(height: 2),
          Text(
            _formatDate(comment.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          if (comment.isHidden)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.visibility_off_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Pending review: hidden from other users',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: ContentOverflowMenu(
        contentType: 'comment',
        objectId: comment.id,
      ),
    );
  }
}