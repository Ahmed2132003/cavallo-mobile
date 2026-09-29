import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/message_bubble_widget.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

/// Part P-076 — widget tests for media rendering in both bubbles.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Message _message({
  String text = '',
  String? mediaUrl,
  ChatMediaType? mediaType,
}) {
  return Message(
    id: 1,
    conversationId: 1,
    senderId: 1,
    text: text,
    status: MessageStatus.sent,
    createdAt: DateTime(2026, 1, 1, 9, 30),
    mediaUrl: mediaUrl,
    mediaType: mediaType,
  );
}

OutboundMessage _outbound({
  required OutboundMessageStatus status,
  ChatMediaType mediaType = ChatMediaType.video,
  String text = '',
}) {
  return OutboundMessage(
    id: 'outbound_0',
    conversationId: 1,
    text: text,
    createdAt: DateTime(2026, 1, 1, 9, 30),
    attempt: 1,
    status: status,
    mediaPath: '/tmp/clip.mp4',
    mediaType: mediaType,
  );
}

void main() {
  testWidgets('image message with a caption renders the image and the caption', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MessageBubbleWidget(
          message: _message(
            text: 'nice view',
            mediaUrl: 'http://media.local/chat/media/photo.png',
            mediaType: ChatMediaType.image,
          ),
          isMine: false,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chatMedia_image')), findsOneWidget);
    expect(find.byKey(const ValueKey('chatMedia_video')), findsNothing);
    expect(find.text('nice view'), findsOneWidget);
  });

  testWidgets('video message renders the placeholder with a play icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MessageBubbleWidget(
          message: _message(
            mediaUrl: 'http://media.local/chat/media/clip.mp4',
            mediaType: ChatMediaType.video,
          ),
          isMine: true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chatMedia_video')), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byKey(const ValueKey('chatMedia_image')), findsNothing);
  });

  testWidgets('media-only message shows no text line, only media and time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MessageBubbleWidget(
          message: _message(
            mediaUrl: 'http://media.local/chat/media/photo.png',
            mediaType: ChatMediaType.image,
          ),
          isMine: false,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chatMedia_image')), findsOneWidget);
    expect(find.text(''), findsNothing);
    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('text-only message has no media widget (regression)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(MessageBubbleWidget(message: _message(text: 'hello'), isMine: true)),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byKey(const ValueKey('chatMedia_image')), findsNothing);
    expect(find.byKey(const ValueKey('chatMedia_video')), findsNothing);
  });

  testWidgets('queued (sending) video shows the placeholder and a clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(status: OutboundMessageStatus.sending),
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chatMedia_video')), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Failed to send · Tap to retry'), findsNothing);
  });

  testWidgets('failed media bubble: tap retries, × discards', (tester) async {
    var retries = 0;
    var discards = 0;
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(
            status: OutboundMessageStatus.failed,
            text: 'caption',
          ),
          onRetry: () => retries++,
          onDiscard: () => discards++,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chatMedia_video')), findsOneWidget);
    expect(find.text('Failed to send · Tap to retry'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('outbound_retry_outbound_0')));
    expect(retries, 1);

    await tester.tap(find.byKey(const ValueKey('outbound_discard_outbound_0')));
    expect(discards, 1);
  });
}