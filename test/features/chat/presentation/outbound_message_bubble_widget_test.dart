import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/message_bubble_widget.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

/// Part P-075 STEP 4 — widget tests for [OutboundMessageBubbleWidget]
/// (sending / retrying / failed) and a regression check that the
/// existing [MessageBubbleWidget] still renders its status ticks.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

OutboundMessage _outbound({
  required OutboundMessageStatus status,
  int attempt = 1,
  String? errorMessage,
}) {
  return OutboundMessage(
    id: 'outbound_0',
    conversationId: 1,
    text: 'hello',
    createdAt: DateTime(2026, 1, 1, 9, 30),
    attempt: attempt,
    status: status,
    errorMessage: errorMessage,
  );
}

void main() {
  testWidgets('sending: shows the text and a clock, no retry affordance', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(status: OutboundMessageStatus.sending),
          onRetry: () => retries++,
          onDiscard: () {},
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Retrying…'), findsNothing);
    expect(find.text('Failed to send · Tap to retry'), findsNothing);

    // A sending bubble is not tappable.
    expect(find.byKey(const ValueKey('outbound_retry_outbound_0')), findsNothing);
    await tester.tap(find.text('hello'));
    expect(retries, 0);
  });

  testWidgets('retrying: shows the clock and "Retrying…"', (tester) async {
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(status: OutboundMessageStatus.retrying),
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Retrying…'), findsOneWidget);
    expect(find.text('Failed to send · Tap to retry'), findsNothing);
  });

  testWidgets('failed: shows the failure text and the error reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(
            status: OutboundMessageStatus.failed,
            attempt: 5,
            errorMessage: 'Network down',
          ),
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('Failed to send · Tap to retry'), findsOneWidget);
    expect(find.text('Network down'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('failed: tapping the bubble calls onRetry only', (tester) async {
    var retries = 0;
    var discards = 0;
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(
            status: OutboundMessageStatus.failed,
            errorMessage: 'Network down',
          ),
          onRetry: () => retries++,
          onDiscard: () => discards++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('outbound_retry_outbound_0')));
    expect(retries, 1);
    expect(discards, 0);
  });

  testWidgets('failed: tapping the × calls onDiscard and NOT onRetry', (
    tester,
  ) async {
    var retries = 0;
    var discards = 0;
    await tester.pumpWidget(
      _host(
        OutboundMessageBubbleWidget(
          outbound: _outbound(
            status: OutboundMessageStatus.failed,
            errorMessage: 'Network down',
          ),
          onRetry: () => retries++,
          onDiscard: () => discards++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('outbound_discard_outbound_0')));
    expect(discards, 1);
    expect(retries, 0);
  });

  testWidgets('MessageBubbleWidget (regression): own sent message still '
      'shows a single tick and no clock', (tester) async {
    await tester.pumpWidget(
      _host(
        MessageBubbleWidget(
          message: Message(
            id: 1,
            conversationId: 1,
            senderId: 1,
            text: 'confirmed',
            status: MessageStatus.sent,
            createdAt: DateTime(2026, 1, 1, 9, 30),
          ),
          isMine: true,
        ),
      ),
    );

    expect(find.text('confirmed'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });
}