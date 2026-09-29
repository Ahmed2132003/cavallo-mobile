import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

/// Part P-075 STEP 2. Hand-rolled test double — this project doesn't use
/// mockito/mocktail anywhere (same convention as
/// `story_upload_queue_provider_test.dart`, P-051).
///
/// `MessageRepository` is a plain (non-final, non-sealed) class, so this
/// extends it and overrides the one method that matters.
class _ScriptedMessageRepository extends MessageRepository {
  _ScriptedMessageRepository(this._outcomes) : super(Dio());

  /// One entry consumed per call to [sendMessage], in order.
  /// `null` means "succeed"; any non-null value is thrown as-is (an
  /// [ApiFailure] for the normal cases, or any other object to simulate
  /// an unexpected exception).
  final List<Object?> _outcomes;

  int callCount = 0;
  final List<({int conversationId, String text})> calls = [];

  @override
  Future<Message> sendMessage({
    required int conversationId,
    required String text,
  }) async {
    final outcome = _outcomes[callCount];
    callCount++;
    calls.add((conversationId: conversationId, text: text));
    if (outcome != null) {
      throw outcome;
    }
    return Message(
      id: 1000 + callCount,
      conversationId: conversationId,
      senderId: 1,
      text: text,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }
}

/// Polls [condition] until it's true or [timeout] elapses. The queue
/// schedules retries via real (though injected-to-near-zero) [Timer]s,
/// so tests must yield back to the event loop between checks.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Builds a container whose queue notifier uses a near-zero backoff by
/// default. Tests that need to OBSERVE the `retrying` state pass a wider
/// [backoff] (1ms can complete a whole fail->retry cycle faster than
/// one 5ms polling interval — the same trap P-051's tests documented).
ProviderContainer _buildContainer(
  List<Object?> outcomes, {
  Duration backoff = const Duration(milliseconds: 1),
  MessageBackoffDelayForAttempt? backoffFn,
}) {
  final repo = _ScriptedMessageRepository(outcomes);
  return ProviderContainer(
    overrides: [
      messageRepositoryProvider.overrideWithValue(repo),
      outboundMessageQueueProvider.overrideWith(
        () => OutboundMessageQueueNotifier(
          backoffDelayForAttempt: backoffFn ?? (_) => backoff,
        ),
      ),
    ],
  );
}

_ScriptedMessageRepository _repoOf(ProviderContainer container) =>
    container.read(messageRepositoryProvider) as _ScriptedMessageRepository;

const _networkDown = NetworkFailure(message: 'Connection lost');

void main() {
  group('eventual success', () {
    for (final failCount in [0, 2]) {
      test(
        'fails $failCount time(s) then succeeds — removed from queue, '
        'sentStream fires once',
        () async {
          final outcomes = <Object?>[
            for (var i = 0; i < failCount; i++) _networkDown,
            null, // succeeds
          ];
          final container = _buildContainer(outcomes);
          addTearDown(container.dispose);
          final repo = _repoOf(container);
          final notifier = container.read(outboundMessageQueueProvider.notifier);

          final sent = <OutboundMessageSent>[];
          notifier.sentStream.listen(sent.add);

          final id = notifier.enqueueMessage(conversationId: 7, text: 'hello');

          await _waitUntil(
            () => container.read(outboundMessageQueueProvider).isEmpty,
          );
          // Let the broadcast stream deliver its event.
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(repo.callCount, failCount + 1);
          expect(
            repo.calls.every((c) => c.conversationId == 7 && c.text == 'hello'),
            isTrue,
          );
          expect(sent, hasLength(1));
          expect(sent.single.localId, id);
          expect(sent.single.message.text, 'hello');
          expect(sent.single.message.conversationId, 7);
        },
      );
    }
  });

  test(
    'always fails with a network error — failed after exactly 5 attempts, '
    'never silently disappears, no sentStream event',
    () async {
      final container = _buildContainer(
        List<Object?>.filled(10, _networkDown),
      );
      addTearDown(container.dispose);
      final repo = _repoOf(container);
      final notifier = container.read(outboundMessageQueueProvider.notifier);

      final sent = <OutboundMessageSent>[];
      notifier.sentStream.listen(sent.add);

      notifier.enqueueMessage(conversationId: 1, text: 'lost?');

      await _waitUntil(() {
        final queue = container.read(outboundMessageQueueProvider);
        return queue.isNotEmpty &&
            queue.single.status == OutboundMessageStatus.failed;
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final message = container.read(outboundMessageQueueProvider).single;
      expect(repo.callCount, 5, reason: 'must stop at the attempt cap');
      expect(message.attempt, 5);
      expect(message.status, OutboundMessageStatus.failed);
      expect(message.errorMessage, 'Connection lost');
      expect(message.text, 'lost?');
      expect(sent, isEmpty);
    },
  );

  group('non-retryable failures fail immediately (no retry loop)', () {
    final cases = <String, ApiFailure>{
      'ValidationFailure (400)': const ValidationFailure(
        message: 'Invalid message.',
        fields: {},
      ),
      'AuthFailure (401/403)': const AuthFailure(message: 'Not allowed.'),
      'ServerFailure (5xx)': const ServerFailure(message: 'Server error.'),
    };

    for (final entry in cases.entries) {
      test('${entry.key} — 1 call only, straight to failed', () async {
        final container = _buildContainer(<Object?>[entry.value, null, null]);
        addTearDown(container.dispose);
        final repo = _repoOf(container);

        container
            .read(outboundMessageQueueProvider.notifier)
            .enqueueMessage(conversationId: 1, text: 'nope');

        await _waitUntil(() {
          final queue = container.read(outboundMessageQueueProvider);
          return queue.isNotEmpty &&
              queue.single.status == OutboundMessageStatus.failed;
        });
        // Give any (wrong) retry timer time to fire before asserting.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final message = container.read(outboundMessageQueueProvider).single;
        expect(repo.callCount, 1, reason: 'must not enter the retry loop');
        expect(message.attempt, 1);
        expect(message.status, OutboundMessageStatus.failed);
        expect(message.errorMessage, entry.value.message);
      });
    }
  });

  test(
    'unexpected non-ApiFailure exception — failed immediately with a '
    'generic message, never silently lost',
    () async {
      final container = _buildContainer(<Object?>[StateError('boom'), null]);
      addTearDown(container.dispose);
      final repo = _repoOf(container);

      container
          .read(outboundMessageQueueProvider.notifier)
          .enqueueMessage(conversationId: 1, text: 'weird');

      await _waitUntil(() {
        final queue = container.read(outboundMessageQueueProvider);
        return queue.isNotEmpty &&
            queue.single.status == OutboundMessageStatus.failed;
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final message = container.read(outboundMessageQueueProvider).single;
      expect(repo.callCount, 1);
      expect(message.errorMessage, 'Failed to send message.');
    },
  );

  test(
    'manual retry of a failed message resets the attempt counter to 1 '
    'and can then succeed',
    () async {
      // 5 network failures exhaust the cap, the 6th call succeeds.
      final container = _buildContainer(<Object?>[
        for (var i = 0; i < 5; i++) _networkDown,
        null,
      ]);
      addTearDown(container.dispose);
      final repo = _repoOf(container);
      final notifier = container.read(outboundMessageQueueProvider.notifier);

      final sent = <OutboundMessageSent>[];
      notifier.sentStream.listen(sent.add);

      final id = notifier.enqueueMessage(conversationId: 3, text: 'again');

      await _waitUntil(() {
        final queue = container.read(outboundMessageQueueProvider);
        return queue.isNotEmpty &&
            queue.single.status == OutboundMessageStatus.failed;
      });
      expect(repo.callCount, 5);

      notifier.retryFailedMessage(id);

      // Synchronously after the call: reset, in flight, error cleared.
      final afterRetry = container.read(outboundMessageQueueProvider).single;
      expect(afterRetry.attempt, 1);
      expect(afterRetry.status, OutboundMessageStatus.sending);
      expect(afterRetry.errorMessage, isNull);

      await _waitUntil(
        () => container.read(outboundMessageQueueProvider).isEmpty,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.callCount, 6);
      expect(sent, hasLength(1));
      expect(sent.single.localId, id);
    },
  );

  test('retryFailedMessage is a no-op for a message that is not failed', () async {
    // Wide backoff so the message sits in `retrying` long enough to poke.
    final container = _buildContainer(
      <Object?>[_networkDown, null],
      backoff: const Duration(milliseconds: 300),
    );
    addTearDown(container.dispose);
    final repo = _repoOf(container);
    final notifier = container.read(outboundMessageQueueProvider.notifier);

    final id = notifier.enqueueMessage(conversationId: 1, text: 'wait');

    await _waitUntil(() {
      final queue = container.read(outboundMessageQueueProvider);
      return queue.isNotEmpty &&
          queue.single.status == OutboundMessageStatus.retrying;
    });

    notifier.retryFailedMessage(id);
    notifier.retryFailedMessage('outbound_does_not_exist');

    final message = container.read(outboundMessageQueueProvider).single;
    expect(message.status, OutboundMessageStatus.retrying);
    expect(message.attempt, 1);
    expect(repo.callCount, 1, reason: 'no extra send may be triggered');

    // The normal automatic retry still completes afterwards.
    await _waitUntil(
      () => container.read(outboundMessageQueueProvider).isEmpty,
    );
    expect(repo.callCount, 2);
  });

  test('discardFailedMessage removes a failed message from the queue', () async {
    final container = _buildContainer(<Object?>[
      const ValidationFailure(message: 'Invalid message.', fields: {}),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(outboundMessageQueueProvider.notifier);

    final id = notifier.enqueueMessage(conversationId: 1, text: 'bad');

    await _waitUntil(() {
      final queue = container.read(outboundMessageQueueProvider);
      return queue.isNotEmpty &&
          queue.single.status == OutboundMessageStatus.failed;
    });

    notifier.discardFailedMessage(id);

    expect(container.read(outboundMessageQueueProvider), isEmpty);
  });

  test(
    'discardFailedMessage does NOT remove a message that is still retrying',
    () async {
      final container = _buildContainer(
        <Object?>[_networkDown, null],
        backoff: const Duration(milliseconds: 300),
      );
      addTearDown(container.dispose);
      final notifier = container.read(outboundMessageQueueProvider.notifier);

      final id = notifier.enqueueMessage(conversationId: 1, text: 'keep');

      await _waitUntil(() {
        final queue = container.read(outboundMessageQueueProvider);
        return queue.isNotEmpty &&
            queue.single.status == OutboundMessageStatus.retrying;
      });

      notifier.discardFailedMessage(id);

      expect(container.read(outboundMessageQueueProvider), hasLength(1));
      expect(
        container.read(outboundMessageQueueProvider).single.status,
        OutboundMessageStatus.retrying,
      );
    },
  );

  test('uses the P-051 backoff schedule: failed attempts 1..4 are passed '
      'to the backoff function', () async {
    final requested = <int>[];
    final container = _buildContainer(
      List<Object?>.filled(10, _networkDown),
      backoffFn: (failedAttempt) {
        requested.add(failedAttempt);
        return const Duration(milliseconds: 1);
      },
    );
    addTearDown(container.dispose);

    container
        .read(outboundMessageQueueProvider.notifier)
        .enqueueMessage(conversationId: 1, text: 'schedule');

    await _waitUntil(() {
      final queue = container.read(outboundMessageQueueProvider);
      return queue.isNotEmpty &&
          queue.single.status == OutboundMessageStatus.failed;
    });

    // Attempt 5 is the cap, so no delay is requested after it.
    expect(requested, [1, 2, 3, 4]);
  });

  test(
    'disposing the container while a retry is pending cancels it — no '
    'extra send, no crash',
    () async {
      final container = _buildContainer(
        <Object?>[_networkDown, null, null],
        backoff: const Duration(milliseconds: 60),
      );
      final repo = _repoOf(container);

      container
          .read(outboundMessageQueueProvider.notifier)
          .enqueueMessage(conversationId: 1, text: 'bye');

      await _waitUntil(() {
        final queue = container.read(outboundMessageQueueProvider);
        return queue.isNotEmpty &&
            queue.single.status == OutboundMessageStatus.retrying;
      });

      // Deliberately no addTearDown(container.dispose) in this test.
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.callCount, 1, reason: 'the pending retry must be cancelled');
    },
  );
}