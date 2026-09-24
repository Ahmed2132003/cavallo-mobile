import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'content_interaction_key.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058 scope: replaces `ContentStubActionRow` (P-045) on
/// PostCard/ReelCard. The Comment icon does not act inline: it calls
/// [onCommentTap], which the caller wires to navigation to the detail
/// screen's comment section.
///
/// KNOWN GAP: `PublicPost`/`PublicReel` carry no likes/comments/shares
/// counts (no backend serializer exposes them yet), so every counter starts
/// at 0 and only reflects interactions from this session.
class ContentActionRow extends ConsumerWidget {
  const ContentActionRow({
    super.key,
    required this.contentType,
    required this.objectId,
    required this.onCommentTap,
  });

  /// `"post"` or `"reel"`.
  final String contentType;
  final int objectId;
  final VoidCallback onCommentTap;

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(socialErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContentInteractionKey key = (
      contentType: contentType,
      objectId: objectId,
    );
    final state = ref.watch(contentInteractionProvider(key));
    final notifier = ref.read(contentInteractionProvider(key).notifier);
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) _showError(context, e);
      }
    }

    Widget countLabel(int count) => count > 0
        ? Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          )
        : const SizedBox.shrink();

    return Row(
      children: [
        IconButton(
          icon: Icon(
            state.isLiked ? Icons.favorite : Icons.favorite_border,
            color: state.isLiked ? Colors.red : iconColor,
          ),
          tooltip: 'Like',
          onPressed: () => guarded(notifier.toggleLike),
        ),
        countLabel(state.likesCount),
        IconButton(
          icon: Icon(Icons.mode_comment_outlined, color: iconColor),
          tooltip: 'Comment',
          onPressed: onCommentTap,
        ),
        countLabel(state.commentsCount),
        IconButton(
          icon: Icon(Icons.share_outlined, color: iconColor),
          tooltip: 'Share',
          onPressed: () => guarded(() async {
            await notifier.share();
            if (context.mounted) {
              await SharePlus.instance.share(
                ShareParams(text: 'Check out this $contentType on Cavallo'),
              );
            }
          }),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            state.isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: iconColor,
          ),
          tooltip: 'Save',
          onPressed: () => guarded(notifier.toggleSave),
        ),
      ],
    );
  }
}