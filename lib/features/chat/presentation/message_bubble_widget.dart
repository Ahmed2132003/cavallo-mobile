import 'package:flutter/material.dart';

import '../domain/message.dart';
import '../domain/message_status.dart';

/// Part P-074 STEP 3 — renders a single message bubble inside the
/// message thread screen (kept as `chat_thread_screen.dart`'s
/// `ChatThreadScreen`, not renamed — see that file's own doc comment
/// for why no new screen file/class was created for P-007's existing
/// placeholders).
///
/// [isMine] is supplied by the caller, not computed here: in a 1:1
/// conversation, `message.senderId != conversation.otherParticipant.id`
/// is enough to know "this is my own message" without this app ever
/// needing to know its own signed-in user id — see
/// `chat_thread_screen.dart`'s own doc comment for why that's a
/// deliberate design choice, not an oversight.
class MessageBubbleWidget extends StatelessWidget {
  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _StatusIcon(status: message.status, color: textColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Sent -> single check. Delivered -> double check. Read -> double
/// check, tinted with the theme's own tertiary color rather than a
/// hardcoded blue (this file has no knowledge of the app's palette).
/// [MessageStatus.unknown] falls back to a single check — same
/// never-block-rendering-on-an-unrecognized-value rationale as
/// `MessageStatus.unknown` itself.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Theme.of(context).colorScheme.tertiary,
        );
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color.withValues(alpha: 0.85));
      case MessageStatus.sent:
      case MessageStatus.unknown:
        return Icon(Icons.done, size: 14, color: color.withValues(alpha: 0.85));
    }
  }
}