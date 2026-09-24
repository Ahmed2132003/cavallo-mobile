import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_failure.dart';
import 'content_interaction_key.dart';
import 'social_interaction_provider.dart';

/// Part P-058 scope: replaces `ContentStubActionRow` (P-045) on
/// PostCard/ReelCard. The Comment icon does NOT act inline here — it
/// calls [onCommentTap], which the caller (PostCard/ReelCard) wires to
/// its existing P-045 `onTap`-to-detail callback, per this part's own
/// spec: "tapping comment navigates to the detail screen's comment
/// section". `post_detail_screen.dart`/`reel_detail_screen.dart`'s OWN
/// action row (still `ContentStubActionRow` as of this step) is wired
/// separately in a later step, together with the real comment list/
/// input that lives there.
///
/// KNOWN GAP, deliberately not worked around here (see
/// `ContentInteractionNotifier.seed`'s own docstring): this widget
/// never calls `seed()` — as of this step, `PublicPost`/`PublicReel`
/// carry no `likesCount`/`commentsCount`/`sharesCount` fields to seed
/// FROM (not exposed by any backend serializer yet). Every counter
/// therefore starts at `0` and only reflects interactions from THIS
/// session — not the item's real historical total. This is a visible,
/// flagged limitation of this step, not a silent bug.
class ContentActionRow extends ConsumerWidget {
  const ContentActionRow({
    super.key,
    required this.contentType,
    required this.objectId,
    required this.onCommentTap,
  });

  /// `"post"` or `"reel"` — passed straight through to
  /// `SocialInteractionRepository`, never validated locally (the
  /// backend's own closed whitelist per interaction is the source of
  /// truth, and differs slightly between Like/Save/Comment/Share —
  /// see each one's own `_ALLOWED_CONTENT_TYPES` in `social/views.py`).
  final String contentType;
  final int objectId;
  final VoidCallback onCommentTap;

  void _showError(BuildContext context, Object error) {
    final message = switch (error) {
      ApiFailure(:final message) => message,
      _ => 'Something went wrong. Please try again.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            child: Text('$count', style: Theme.of(context).textTheme.labelMedium),
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
                ShareParams(
                  text: 'Check out this $contentType on Cavallo',
                ),
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