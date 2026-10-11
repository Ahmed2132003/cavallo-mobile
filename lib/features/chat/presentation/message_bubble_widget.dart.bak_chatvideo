import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/message.dart';
import '../domain/message_status.dart';
import '../domain/shared_content.dart';
import 'outbound_message_queue_provider.dart';
import 'shared_content_card.dart';

/// Chat bubbles.
///
/// Part P-115 STEP 3A: restyle only. Own bubbles are brand blue with white
/// text, received bubbles use surfaceVariant, corners are 20 with the corners
/// on the sender's side tightened to 4 between consecutive messages from the
/// same sender (grouping is decided by the caller and passed in as
/// [MessageBubbleWidget.isFirstInGroup] / [MessageBubbleWidget.isLastInGroup];
/// it is presentation only). Everything is directional, so the layout mirrors
/// in Arabic. No send / queue / delivery logic lives here.

const double _bubbleRadius = 20;
const double _groupedRadius = 4;

BorderRadiusDirectional _radiusFor({
  required bool isMine,
  required bool isFirstInGroup,
  required bool isLastInGroup,
}) {
  const Radius big = Radius.circular(_bubbleRadius);
  final Radius top = Radius.circular(
    isFirstInGroup ? _bubbleRadius : _groupedRadius,
  );
  final Radius bottom = Radius.circular(
    isLastInGroup ? _bubbleRadius : _groupedRadius,
  );
  if (isMine) {
    return BorderRadiusDirectional.only(
      topStart: big,
      bottomStart: big,
      topEnd: top,
      bottomEnd: bottom,
    );
  }
  return BorderRadiusDirectional.only(
    topStart: top,
    bottomStart: bottom,
    topEnd: big,
    bottomEnd: big,
  );
}

/// The colours of one bubble, all taken from [AppColors].
class _Tone {
  const _Tone({
    required this.background,
    required this.text,
    required this.meta,
    required this.readTick,
  });

  final Color background;
  final Color text;
  final Color meta;
  final Color readTick;
}

_Tone _toneFor(AppColors c, {required bool isMine, bool isFailed = false}) {
  if (isFailed) {
    return _Tone(
      background: c.dangerSubtle,
      text: c.dangerText,
      meta: c.dangerText.withValues(alpha: 0.8),
      readTick: c.dangerText,
    );
  }
  if (isMine) {
    return _Tone(
      background: c.brand,
      text: c.onBrand,
      meta: c.onBrand.withValues(alpha: 0.75),
      readTick: c.onBrand,
    );
  }
  return _Tone(
    background: c.surfaceVariant,
    text: c.textPrimary,
    meta: c.textSecondary,
    readTick: c.brandText,
  );
}

/// For a time / tick line that sits on the page, outside any bubble.
_Tone _toneOnBackground(AppColors c) {
  return _Tone(
    background: Colors.transparent,
    text: c.textPrimary,
    meta: c.textSecondary,
    readTick: c.brandText,
  );
}

class MessageBubbleWidget extends StatelessWidget {
  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMine,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final Message message;
  final bool isMine;

  /// First message of a run from the same sender (full top corners).
  final bool isFirstInGroup;

  /// Last message of a run from the same sender (full bottom corners).
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final shared = message.sharedContent;
    if (shared != null) {
      return _SharedContentBubble(
        message: message,
        shared: shared,
        isMine: isMine,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      );
    }

    final mediaType = message.mediaType;
    return _BubbleShell(
      text: message.text,
      isMine: isMine,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      media:
          mediaType == null
              ? null
              : _MediaPreview(type: mediaType, networkUrl: message.mediaUrl),
      footerBuilder: (tone) => _deliveredFooter(message, isMine, tone),
    );
  }
}

Widget _deliveredFooter(Message message, bool isMine, _Tone tone) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        _formatTime(message.createdAt),
        style: TextStyle(color: tone.meta, fontSize: 11),
      ),
      if (isMine) ...[
        const SizedBox(width: 4),
        _StatusIcon(status: message.status, tone: tone),
      ],
    ],
  );
}

class _SharedContentBubble extends StatelessWidget {
  const _SharedContentBubble({
    required this.message,
    required this.shared,
    required this.isMine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final Message message;
  final SharedContent shared;
  final bool isMine;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    // Same 75%-of-screen rule as the text bubble, capped so a card is
    // never absurdly wide on a tablet.
    final cardWidth = math.min(MediaQuery.of(context).size.width * 0.75, 300.0);
    final bool hasText = message.text.isNotEmpty;

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            12,
            isFirstInGroup ? 6 : 2,
            12,
            0,
          ),
          child: SizedBox(
            width: cardWidth,
            child: SharedContentCard(sharedContent: shared),
          ),
        ),
        if (hasText)
          _BubbleShell(
            text: message.text,
            isMine: isMine,
            // The text bubble is attached under the card.
            isFirstInGroup: false,
            isLastInGroup: isLastInGroup,
            footerBuilder: (tone) => _deliveredFooter(message, isMine, tone),
          )
        else
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
            child: _deliveredFooter(
              message,
              isMine,
              _toneOnBackground(context.appColors),
            ),
          ),
      ],
    );
  }
}

class OutboundMessageBubbleWidget extends StatelessWidget {
  const OutboundMessageBubbleWidget({
    super.key,
    required this.outbound,
    required this.onRetry,
    required this.onDiscard,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final OutboundMessage outbound;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final isFailed = outbound.status == OutboundMessageStatus.failed;
    final mediaType = outbound.mediaType;

    return _BubbleShell(
      text: outbound.text,
      isMine: true,
      isFailed: isFailed,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      onTap: isFailed ? onRetry : null,
      tapKey: isFailed ? ValueKey('outbound_retry_${outbound.id}') : null,
      media:
          mediaType == null
              ? null
              : _MediaPreview(type: mediaType, localPath: outbound.mediaPath),
      footerBuilder: (tone) {
        if (isFailed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 14, color: tone.text),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      context.l10n.chatBubbleFailedTapRetry,
                      style: TextStyle(
                        color: tone.text,
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
                      child: Icon(Icons.close, size: 16, color: tone.text),
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
                  style: TextStyle(color: tone.meta, fontSize: 10),
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
              style: TextStyle(color: tone.meta, fontSize: 11),
            ),
            if (isRetrying) ...[
              const SizedBox(width: 4),
              Text(
                context.l10n.chatBubbleRetrying,
                style: TextStyle(color: tone.meta, fontSize: 11),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.schedule, size: 14, color: tone.meta),
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

class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    required this.text,
    required this.isMine,
    required this.footerBuilder,
    this.media,
    this.isFailed = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onTap,
    this.tapKey,
  });

  final String text;
  final bool isMine;
  final Widget Function(_Tone tone) footerBuilder;
  final Widget? media;
  final bool isFailed;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final _Tone tone = _toneFor(colors, isMine: isMine, isFailed: isFailed);

    final bubble = Container(
      margin: EdgeInsetsDirectional.fromSTEB(
        12,
        isFirstInGroup ? 6 : 1,
        12,
        isLastInGroup ? 6 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: _radiusFor(
          isMine: isMine,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (media != null) media!,
          if (media != null && text.isNotEmpty) const SizedBox(height: 6),
          if (text.isNotEmpty)
            Text(
              text,
              style: TextStyle(color: tone.text, fontSize: 15, height: 1.35),
            ),
          const SizedBox(height: 4),
          footerBuilder(tone),
        ],
      ),
    );

    return Align(
      alignment:
          isMine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
      child:
          onTap == null
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

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.type, this.networkUrl, this.localPath});

  final ChatMediaType type;
  final String? networkUrl;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget placeholder(IconData icon) => Container(
      color: colors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(icon, size: 40, color: colors.textSecondary),
    );

    final Widget content;
    final path = localPath;
    final url = networkUrl;
    if (type == ChatMediaType.video) {
      content = Stack(
        fit: StackFit.expand,
        children: [placeholder(Icons.movie_outlined), const _PlayIconOverlay()],
      );
    } else if (path != null) {
      content = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) =>
                placeholder(Icons.broken_image_outlined),
      );
    } else if (url != null && url.isNotEmpty) {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) =>
                placeholder(Icons.broken_image_outlined),
      );
    } else {
      content = placeholder(Icons.image_outlined);
    }

    return ConstrainedBox(
      key: ValueKey('chatMedia_${type.name}'),
      constraints: const BoxConstraints(maxWidth: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(aspectRatio: 4 / 3, child: content),
      ),
    );
  }
}

class _PlayIconOverlay extends StatelessWidget {
  const _PlayIconOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.tone});

  final MessageStatus status;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    // Sent = one tick, delivered = two ticks, read = two ticks in the
    // emphasised colour. The tick COUNT separates sent from the rest; read
    // is the full-strength tick.
    switch (status) {
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: tone.readTick);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: tone.meta);
      case MessageStatus.sent:
      case MessageStatus.unknown:
        return Icon(Icons.done, size: 14, color: tone.meta);
    }
  }
}
