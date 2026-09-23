import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';

/// Part P-051 STEP 3. Hand-rolled test double — this project doesn't
/// use mockito/mocktail anywhere (confirmed against
/// `own_products_provider_test.dart`'s own note). `StoryCreationRepository`
/// has no domain interface (STEP 1's own flagged decision), so this
/// extends the concrete class and overrides the one method that
/// matters, exactly as `StoryCreationRepository` itself is a plain
/// (non-final, non-sealed) class allowing it.
class _ScriptedStoryCreationRepository extends StoryCreationRepository {
  _ScriptedStoryCreationRepository(this._outcomes) : super(dio: Dio());

  /// One entry consumed per call to [uploadStoryMedia], in order.
  /// `null` means "succeed"; non-null means "throw a DioException whose
  /// `.error` is this ApiFailure."
  final List<ApiFailure?> _outcomes;

  int callCount = 0;

  @override
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) async {
    final outcome = _outcomes[callCount];
    callCount++;
    if (outcome != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/stories/'),
        error: outcome,
      );
    }
  }
}

Future<File> _tempFile() async {
  final file = File(
    '${Directory.systemTemp.path}/p051_queue_test_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
  return file;
}

/// Polls [condition] until it's true or [timeout] elapses. The queue
/// notifier schedules retries via real (though injected-to-near-zero)
/// [Timer]s, so tests need to yield back to the event loop between
/// checks rather than asserting synchronously right after a call.
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

ProviderContainer _buildContainer(
  List<ApiFailure?> outcomes, {
  Duration backoff = const Duration(milliseconds: 1),
}) {
  final repo = _ScriptedStoryCreationRepository(outcomes);
  final container = ProviderContainer(
    overrides: [
      storyCreationRepositoryProvider.overrideWithValue(repo),
      // Near-zero backoff so retry tests run in milliseconds, not the
      // real 2s/4s/8s/16s schedule. Production code never overrides
      // this — see the provider's own FLAGGED SCOPE DECISION 2.
      //
      // [backoff] is overridable per-container because the cancel test
      // below needs a window wide enough to reliably OBSERVE the
      // 'retrying' state before it auto-advances to the next attempt
      // — 1ms is too fast for a 5ms poll loop to reliably catch mid-
      // flight (confirmed by reproducing the resulting timeout
      // directly, not assumed): the whole fail→retry→succeed sequence
      // can complete faster than one polling interval, so the poll
      // loop can miss the 'retrying' state entirely and see only the
      // already-empty (succeeded) queue, spinning until its own
      // timeout. Every other test doesn't care how long 'retrying'
      // lasts, so they keep the fast 1ms default.
      storyUploadQueueProvider.overrideWith(
        () => StoryUploadQueueNotifier(backoffDelayForAttempt: (_) => backoff),
      ),
    ],
  );
  return container;
}

void main() {
  group('eventual success', () {
    for (final failCount in [0, 2]) {
      test('fails $failCount time(s) then succeeds — task is removed', () async {
        final outcomes = [
          for (var i = 0; i < failCount; i++)
            const NetworkFailure(message: 'Connection lost'),
          null, // succeeds
        ];
        final container = _buildContainer(outcomes);
        addTearDown(container.dispose);
        final repo =
            container.read(storyCreationRepositoryProvider)
                as _ScriptedStoryCreationRepository;

        final file = await _tempFile();
        container.read(storyUploadQueueProvider.notifier).enqueueUpload(file);

        await _waitUntil(
          () => container.read(storyUploadQueueProvider).isEmpty,
        );

        expect(repo.callCount, failCount + 1);
        await file.delete();
      });
    }
  });

  test(
    'always fails — reaches a failed state after exactly 5 attempts, task never silently disappears',
    () async {
      final outcomes = List<ApiFailure?>.filled(
        10,
        const NetworkFailure(message: 'Connection lost'),
      );
      final container = _buildContainer(outcomes);
      addTearDown(container.dispose);
      final repo =
          container.read(storyCreationRepositoryProvider)
              as _ScriptedStoryCreationRepository;

      final file = await _tempFile();
      container.read(storyUploadQueueProvider.notifier).enqueueUpload(file);

      await _waitUntil(
        () => container.read(storyUploadQueueProvider).isNotEmpty &&
            container.read(storyUploadQueueProvider).single.status ==
                UploadTaskStatus.failed,
      );

      final task = container.read(storyUploadQueueProvider).single;
      expect(repo.callCount, 5, reason: 'must stop at the attempt cap');
      expect(task.attempt, 5);
      expect(task.errorMessage, 'Connection lost');
      await file.delete();
    },
  );

  test(
    'a validation failure fails immediately — no retry loop triggered',
    () async {
      final outcomes = [
        const ValidationFailure(
          message: 'Unsupported file type.',
          fields: {
            'media': ['Unsupported file type.'],
          },
        ),
      ];
      final container = _buildContainer(outcomes);
      addTearDown(container.dispose);
      final repo =
          container.read(storyCreationRepositoryProvider)
              as _ScriptedStoryCreationRepository;

      final file = await _tempFile();
      container.read(storyUploadQueueProvider.notifier).enqueueUpload(file);

      await _waitUntil(
        () => container.read(storyUploadQueueProvider).isNotEmpty &&
            container.read(storyUploadQueueProvider).single.status ==
                UploadTaskStatus.failed,
      );

      // The one and only call — never retried.
      expect(repo.callCount, 1);
      final task = container.read(storyUploadQueueProvider).single;
      expect(task.errorMessage, 'Unsupported file type.');
      await file.delete();
    },
  );

  test('cancel mid-retry-wait removes the task and cancels its token', () async {
    final outcomes = [
      const NetworkFailure(message: 'Connection lost'),
      null,
    ];
    // A wider backoff than the 1ms default — see _buildContainer's own
    // doc comment for why this specific test needs it. 300ms is far
    // longer than the 5ms poll interval below (reliable to observe)
    // and still fast for a test (no real 2s+ wait).
    final container = _buildContainer(
      outcomes,
      backoff: const Duration(milliseconds: 300),
    );
    addTearDown(container.dispose);

    final file = await _tempFile();
    final notifier = container.read(storyUploadQueueProvider.notifier);
    final taskId = notifier.enqueueUpload(file);

    // Wait for the first attempt to fail and enter 'retrying' (waiting
    // out the backoff) before cancelling mid-wait.
    await _waitUntil(
      () => container.read(storyUploadQueueProvider).isNotEmpty &&
          container.read(storyUploadQueueProvider).single.status ==
              UploadTaskStatus.retrying,
    );
    final cancelToken =
        container.read(storyUploadQueueProvider).single.cancelToken;

    notifier.cancel(taskId);

    expect(container.read(storyUploadQueueProvider), isEmpty);
    expect(cancelToken.isCancelled, isTrue);
    await file.delete();
  });

  test('discard removes a failed task without retrying', () async {
    final outcomes = [
      const ValidationFailure(message: 'Unsupported file type.', fields: {}),
    ];
    final container = _buildContainer(outcomes);
    addTearDown(container.dispose);
    final repo =
        container.read(storyCreationRepositoryProvider)
            as _ScriptedStoryCreationRepository;

    final file = await _tempFile();
    final notifier = container.read(storyUploadQueueProvider.notifier);
    final taskId = notifier.enqueueUpload(file);

    await _waitUntil(
      () => container.read(storyUploadQueueProvider).isNotEmpty &&
          container.read(storyUploadQueueProvider).single.status ==
              UploadTaskStatus.failed,
    );

    notifier.discard(taskId);

    expect(container.read(storyUploadQueueProvider), isEmpty);
    expect(repo.callCount, 1, reason: 'discard must not trigger another call');
    await file.delete();
  });

  test(
    'manual retry after cap exhaustion resets the attempt counter and can succeed',
    () async {
      final outcomes = [
        const NetworkFailure(message: 'Connection lost'),
        const NetworkFailure(message: 'Connection lost'),
        const NetworkFailure(message: 'Connection lost'),
        const NetworkFailure(message: 'Connection lost'),
        const NetworkFailure(message: 'Connection lost'),
        null, // the manual retry succeeds
      ];
      final container = _buildContainer(outcomes);
      addTearDown(container.dispose);
      final repo =
          container.read(storyCreationRepositoryProvider)
              as _ScriptedStoryCreationRepository;

      final file = await _tempFile();
      final notifier = container.read(storyUploadQueueProvider.notifier);
      final taskId = notifier.enqueueUpload(file);

      await _waitUntil(
        () => container.read(storyUploadQueueProvider).isNotEmpty &&
            container.read(storyUploadQueueProvider).single.status ==
                UploadTaskStatus.failed,
      );
      expect(repo.callCount, 5);

      notifier.retryFailedTask(taskId);

      await _waitUntil(
        () => container.read(storyUploadQueueProvider).isEmpty,
      );
      expect(repo.callCount, 6);
      await file.delete();
    },
  );
}