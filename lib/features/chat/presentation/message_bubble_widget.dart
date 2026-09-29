import 'package:flutter/material.dart';

import '../domain/message.dart';
import '../domain/message_status.dart';
import 'outbound_message_queue_provider.dart';

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
///
/// Part P-075 STEP 3: this file now also holds
/// [OutboundMessageBubbleWidget] — the bubble for a message that is
/// still in the local outbound queue (sending / retrying / failed).
/// Both widgets share one private layout ([_BubbleShell]) so a pending
/// bubble looks like a real one. [MessageBubbleWidget]'s own API is
/// unchanged.
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
    return _BubbleShell(
      text: message.text,
      isMine: isMine,
      footerBuilder: (textColor) => Row(
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
    );
  }
}

/// Part P-075 STEP 3 — the bubble for a locally-queued outbound message
/// ([OutboundMessage]). Always rendered as the sender's own bubble.
///
/// - [OutboundMessageStatus.sending]: clock icon.
/// - [OutboundMessageStatus.retrying]: clock icon + "Retrying…".
/// - [OutboundMessageStatus.failed]: error-colored bubble with
///   "Failed to send · Tap to retry"; tapping ANYWHERE on the bubble
///   calls [onRetry], and the small × calls [onDiscard].
class OutboundMessageBubbleWidget extends StatelessWidget {
  const OutboundMessageBubbleWidget({
    super.key,
    required this.outbound,
    required this.onRetry,
    required this.onDiscard,
  });

  final OutboundMessage outbound;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final isFailed = outbound.status == OutboundMessageStatus.failed;

    return _BubbleShell(
      text: outbound.text,
      isMine: true,
      isFailed: isFailed,
      onTap: isFailed ? onRetry : null,
      tapKey: isFailed ? ValueKey('outbound_retry_${outbound.id}') : null,
      footerBuilder: (textColor) {
        if (isFailed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 14, color: textColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Failed to send · Tap to retry',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: ValueKey('outbound_discard_${outbound.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onDiscard,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 16, color: textColor),
                    ),
                  ),
                ],
              ),
              if (outbound.errorMessage != null) ...[
                const SizedBox(height: 2),
                Text(
                  outbound.errorMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          );
        }

        final isRetrying = outbound.status == OutboundMessageStatus.retrying;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(outbound.createdAt),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            if (isRetrying) ...[
              const SizedBox(width: 4),
              Text(
                'Retrying…',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.schedule,
              size: 14,
              color: textColor.withValues(alpha: 0.85),
            ),
          ],
        );
      },
    );
  }
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// The shared bubble layout (alignment, colors, shape, text, footer).
/// [footerBuilder] receives the resolved text color so each caller's
/// footer matches the bubble. When [isFailed] the bubble uses the
/// theme's error container colors; when [onTap] is non-null the whole
/// bubble is tappable ([tapKey] lets tests find that tap target).
class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    required this.text,
    required this.isMine,
    required this.footerBuilder,
    this.isFailed = false,
    this.onTap,
    this.tapKey,
  });

  final String text;
  final bool isMine;
  final Widget Function(Color textColor) footerBuilder;
  final bool isFailed;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isFailed
        ? theme.colorScheme.errorContainer
        : isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isFailed
        ? theme.colorScheme.onErrorContainer
        : isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final bubble = Container(
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
          Text(text, style: TextStyle(color: textColor, fontSize: 15)),
          const SizedBox(height: 4),
          footerBuilder(textColor),
        ],
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: onTap == null
          ? bubble
          : GestureDetector(
              key: tapKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: bubble,
            ),
    );
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
        return Icon(
          Icons.done_all,
          size: 14,
          color: color.withValues(alpha: 0.85),
        );
      case MessageStatus.sent:
      case MessageStatus.unknown:
        return Icon(Icons.done, size: 14, color: color.withValues(alpha: 0.85));
    }
  }
}