import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/outbound_message_queue_provider.dart';

/// Part P-076 — the media-send path of the outbound queue, proven against
/// the SAME retry/backoff behavior P-075's text tests establish
/// (`outbound_message_queue_provider_test.dart`). These are adaptations of
/// those exact cases, run through `enqueueMediaMessage`. The test double
/// makes the TEXT path throw, so a pass also proves media never falls
/// back to (or is confused with) the text send.
class _ScriptedMediaRepository extends MessageRepository {
  _ScriptedMediaRepository(this._outcomes) : super(Dio());

  /// One entry consumed per [sendMediaMessage] call, in order. `null`
  /// means "succeed"; anything else is thrown as-is.
  final List<Object?> _outcomes;

  int mediaCallCount = 0;
  int textCallCount = 0;
  final List<({int conversationId, String text, String mediaPath})> calls = [];

  @override
  Future<Message> sendMessage({
    required int conversationId,
    required String text,
  }) async {
    textCallCount++;
    throw StateError('text send path must not be used for a media message');
  }

  @override
  Future<Message> sendMediaMessage({
    required int conversationId,
    required String text,
    required String mediaPath,
  }) async {
    final outcome = _outcomes[mediaCallCount];
    mediaCallCount++;
    calls.add((
      conversationId: conversationId,
      text: text,
      mediaPath: mediaPath,
    ));
    if (outcome != null) {
      throw outcome;
    }
    return Message(
      id: 2000 + mediaCallCount,
      conversationId: conversationId,
      senderId: 1,
      text: text,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 1, 1),
      mediaUrl: 'http://media.local/chat/media/x.png',
      mediaType: ChatMediaType.image,
    );
  }
}

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

ProviderContainer _buildContainer(List<Object?> outcomes) {
  final repo = _ScriptedMediaRepository(outcomes);
  return ProviderContainer(
    overrides: [
      messageRepositoryProvider.overrideWithValue(repo),
      outboundMessageQueueProvider.overrideWith(
        () => OutboundMessageQueueNotifier(
          backoffDelayForAttempt: (_) => const Duration(milliseconds: 1),
        ),
      ),
    ],
  );
}

_ScriptedMediaRepository _repoOf(ProviderContainer container) =>
    container.read(messageRepositoryProvider) as _ScriptedMediaRepository;

const _networkDown = NetworkFailure(message: 'Connection lost');

String _enqueue(ProviderContainer container, {String text = 'caption'}) {
  return container
      .read(outboundMessageQueueProvider.notifier)
      .enqueueMediaMessage(
        conversationId: 7,
        text: text,
        mediaPath: '/tmp/photo.jpg',
        mediaType: ChatMediaType.image,
      );
}

bool _isFailed(ProviderContainer container) {
  final queue = container.read(outboundMessageQueueProvider);
  return queue.isNotEmpty && queue.single.status == OutboundMessageStatus.failed;
}

void main() {
  test('enqueueMediaMessage stores the path, type and caption', () async {
    final container = _buildContainer(<Object?>[null]);
    addTearDown(container.dispose);

    _enqueue(container);
    final queued = container.read(outboundMessageQueueProvider).single;

    expect(queued.mediaPath, '/tmp/photo.jpg');
    expect(queued.mediaType, ChatMediaType.image);
    expect(queued.text, 'caption');
    expect(queued.status, OutboundMessageStatus.sending);

    await _waitUntil(
      () => container.read(outboundMessageQueueProvider).isEmpty,
    );
  });

  group('eventual success (same cases as P-075 text)', () {
    for (final failCount in [0, 2]) {
      test('media fails $failCount time(s) then succeeds — sentStream fires once', () async {
        final container = _buildContainer(<Object?>[
          for (var i = 0; i < failCount; i++) _networkDown,
          null,
        ]);
        addTearDown(container.dispose);
        final repo = _repoOf(container);
        final notifier = container.read(outboundMessageQueueProvider.notifier);

        final sent = <OutboundMessageSent>[];
        notifier.sentStream.listen(sent.add);

        final id = _enqueue(container);

        await _waitUntil(
          () => container.read(outboundMessageQueueProvider).isEmpty,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(repo.mediaCallCount, failCount + 1);
        expect(repo.textCallCount, 0);
        expect(
          repo.calls.every(
            (c) =>
                c.conversationId == 7 &&
                c.text == 'caption' &&
                c.mediaPath == '/tmp/photo.jpg',
          ),
          isTrue,
        );
        expect(sent, hasLength(1));
        expect(sent.single.localId, id);
        expect(sent.single.message.mediaType, ChatMediaType.image);
      });
    }
  });

  test(
    'always fails with a network error — failed after exactly 5 attempts, '
    'file path kept for manual retry, no sentStream event',
    () async {
      final container = _buildContainer(List<Object?>.filled(10, _networkDown));
      addTearDown(container.dispose);
      final repo = _repoOf(container);
      final notifier = container.read(outboundMessageQueueProvider.notifier);

      final sent = <OutboundMessageSent>[];
      notifier.sentStream.listen(sent.add);

      _enqueue(container);

      await _waitUntil(() => _isFailed(container));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final message = container.read(outboundMessageQueueProvider).single;
      expect(repo.mediaCallCount, 5, reason: 'must stop at the attempt cap');
      expect(message.attempt, 5);
      expect(message.status, OutboundMessageStatus.failed);
      expect(message.errorMessage, 'Connection lost');
      expect(message.mediaPath, '/tmp/photo.jpg');
      expect(sent, isEmpty);
    },
  );

  group('non-retryable failures fail immediately (same as P-075 text)', () {
    final cases = <String, ApiFailure>{
      'ValidationFailure (400 — e.g. file too large / bad type)':
          const ValidationFailure(message: 'Invalid media.', fields: {}),
      'AuthFailure (401/403)': const AuthFailure(message: 'Not allowed.'),
      'ServerFailure (5xx)': const ServerFailure(message: 'Server error.'),
    };

    for (final entry in cases.entries) {
      test('${entry.key} — 1 call only, straight to failed', () async {
        final container = _buildContainer(<Object?>[entry.value, null, null]);
        addTearDown(container.dispose);
        final repo = _repoOf(container);

        _enqueue(container);

        await _waitUntil(() => _isFailed(container));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final message = container.read(outboundMessageQueueProvider).single;
        expect(repo.mediaCallCount, 1, reason: 'must not enter the retry loop');
        expect(message.attempt, 1);
        expect(message.errorMessage, entry.value.message);
      });
    }
  });

  test('unexpected exception (e.g. missing local file) — failed, never lost', () async {
    final container = _buildContainer(<Object?>[
      const FileSystemExceptionStandIn(),
      null,
    ]);
    addTearDown(container.dispose);
    final repo = _repoOf(container);

    _enqueue(container);

    await _waitUntil(() => _isFailed(container));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final message = container.read(outboundMessageQueueProvider).single;
    expect(repo.mediaCallCount, 1);
    expect(message.errorMessage, 'Failed to send message.');
  });

  test('manual retry resets the counter to 1 and can then succeed', () async {
    final container = _buildContainer(<Object?>[
      for (var i = 0; i < 5; i++) _networkDown,
      null,
    ]);
    addTearDown(container.dispose);
    final repo = _repoOf(container);
    final notifier = container.read(outboundMessageQueueProvider.notifier);

    final sent = <OutboundMessageSent>[];
    notifier.sentStream.listen(sent.add);

    final id = _enqueue(container);

    await _waitUntil(() => _isFailed(container));
    expect(repo.mediaCallCount, 5);

    notifier.retryFailedMessage(id);

    final afterRetry = container.read(outboundMessageQueueProvider).single;
    expect(afterRetry.attempt, 1);
    expect(afterRetry.status, OutboundMessageStatus.sending);
    expect(afterRetry.errorMessage, isNull);
    expect(afterRetry.mediaPath, '/tmp/photo.jpg');

    await _waitUntil(
      () => container.read(outboundMessageQueueProvider).isEmpty,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.mediaCallCount, 6);
    expect(repo.textCallCount, 0);
    expect(sent, hasLength(1));
    expect(sent.single.localId, id);
  });

  test('discardFailedMessage removes a failed media message', () async {
    final container = _buildContainer(<Object?>[
      const ValidationFailure(message: 'Invalid media.', fields: {}),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(outboundMessageQueueProvider.notifier);

    final id = _enqueue(container);

    await _waitUntil(() => _isFailed(container));
    notifier.discardFailedMessage(id);

    expect(container.read(outboundMessageQueueProvider), isEmpty);
  });
}

/// Stands in for the `FileSystemException` a missing local file would
/// throw — anything that is not an [ApiFailure] must land in `failed`.
class FileSystemExceptionStandIn implements Exception {
  const FileSystemExceptionStandIn();
}