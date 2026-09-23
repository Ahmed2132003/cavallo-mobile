import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_status_banner.dart';

/// Part P-051 STEP 5. Two small scripted [StoryCreationRepository]
/// doubles, file-local — mirrors `story_upload_queue_provider_test.dart`'s
/// own precedent (STEP 3) of a fresh, narrowly-scoped fake per test
/// file, since `StoryCreationRepository` has no domain interface to
/// mock against (STEP 1's own flagged decision).
class _AlwaysValidationFailureRepository extends StoryCreationRepository {
  _AlwaysValidationFailureRepository() : super(dio: Dio());

  @override
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/stories/'),
      error: const ValidationFailure(
        message: 'Unsupported file type.',
        fields: {
          'media': ['Unsupported file type.'],
        },
      ),
    );
  }
}

/// Never resolves — lets a test observe the `uploading` state
/// deterministically without racing a real/near-zero backoff Timer.
class _NeverCompletesRepository extends StoryCreationRepository {
  _NeverCompletesRepository() : super(dio: Dio());

  @override
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) {
    return Completer<void>().future;
  }
}

/// Returns a [File] pointing at a throwaway path — the file is never
/// actually created or read.
///
/// FIX (was: `await file.writeAsBytes(...)`): every repository double
/// in this file throws or never-completes without ever touching
/// `mediaFile`'s bytes (neither `_AlwaysValidationFailureRepository`
/// nor `_NeverCompletesRepository` calls `.readAsBytes()`, `.path` for
/// upload, or anything else on it), so a real file on disk was never
/// actually required here — it was pure overhead. Reproduced directly
/// (via DEBUG prints) that `File.writeAsBytes` into
/// `Directory.systemTemp` hung indefinitely for this test on one
/// Windows machine (almost certainly antivirus/real-time-scan
/// interference on that machine's Temp folder — a machine-specific
/// I/O stall, not a bug in this codebase's Riverpod or widget code).
/// Removing the real write removes the dependency on that behavior
/// entirely rather than working around it.
File _fakeMediaFile() => File(
  '${Directory.systemTemp.path}/p051_banner_test_'
  '${DateTime.now().microsecondsSinceEpoch}.png',
);

void main() {
  testWidgets('renders nothing when the queue is empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: StoryUploadStatusBanner())),
      ),
    );

    expect(find.byKey(const Key('storyUploadStatusBanner')), findsNothing);
  });

  testWidgets(
    'shows Retry/Discard for a failed task; Retry re-fails, Discard removes it',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          storyCreationRepositoryProvider.overrideWithValue(
            _AlwaysValidationFailureRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final mediaFile = _fakeMediaFile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: StoryUploadStatusBanner()),
          ),
        ),
      );

      final taskId = container
          .read(storyUploadQueueProvider.notifier)
          .enqueueUpload(mediaFile);
      // A ValidationFailure is never retried (STEP 3's `_isRetryable`) —
      // the task reaches `failed` after exactly one attempt, no backoff
      // wait involved, so two bounded pumps are enough (no pending
      // Timer, so no pumpAndSettle risk either way).
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Story upload failed: Unsupported file type.'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('storyUploadStatusBanner_discard_$taskId')),
        findsOneWidget,
      );
      // A failed task shows no Cancel action — Cancel is only for a
      // task still in flight or waiting out a backoff.
      expect(
        find.byKey(Key('storyUploadStatusBanner_cancel_$taskId')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
      );
      await tester.pump();
      await tester.pump();

      // retryFailedTask resets the attempt counter and fires
      // immediately — with the same always-fails repository, it lands
      // back in `failed` again, same task id.
      expect(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_discard_$taskId')),
      );
      await tester.pump();

      expect(find.byKey(const Key('storyUploadStatusBanner')), findsNothing);
      expect(container.read(storyUploadQueueProvider), isEmpty);
    },
  );

  testWidgets(
    'shows Cancel for an in-flight task; Cancel removes it from the queue',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          storyCreationRepositoryProvider.overrideWithValue(
            _NeverCompletesRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final mediaFile = _fakeMediaFile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: StoryUploadStatusBanner()),
          ),
        ),
      );

      final taskId = container
          .read(storyUploadQueueProvider.notifier)
          .enqueueUpload(mediaFile);
      await tester.pump();

      expect(
        find.text('Uploading story... (attempt 1 of 5)'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_cancel_$taskId')),
      );
      await tester.pump();

      expect(find.byKey(const Key('storyUploadStatusBanner')), findsNothing);
      expect(container.read(storyUploadQueueProvider), isEmpty);
    },
  );
}