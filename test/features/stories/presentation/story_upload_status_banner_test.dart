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

Future<File> _tempFile() async {
  final file = File(
    '${Directory.systemTemp.path}/p051_banner_test_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
  return file;
}

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
    timeout: const Timeout(Duration(seconds: 10)),
    (tester) async {
      // ignore: avoid_print
      print('DEBUG 1: creating container');
      final container = ProviderContainer(
        overrides: [
          storyCreationRepositoryProvider.overrideWithValue(
            _AlwaysValidationFailureRepository(),
          ),
        ],
      );
      addTearDown(() {
        // ignore: avoid_print
        print('DEBUG teardown: disposing container');
        container.dispose();
        // ignore: avoid_print
        print('DEBUG teardown: container disposed');
      });

      // ignore: avoid_print
      print('DEBUG 2: writing temp file');
      final mediaFile = await _tempFile();
      addTearDown(() => mediaFile.delete());
      // ignore: avoid_print
      print('DEBUG 3: temp file ready, pumping widget');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: StoryUploadStatusBanner()),
          ),
        ),
      );
      // ignore: avoid_print
      print('DEBUG 4: widget pumped, calling enqueueUpload');

      final taskId = container
          .read(storyUploadQueueProvider.notifier)
          .enqueueUpload(mediaFile);
      // ignore: avoid_print
      print('DEBUG 5: enqueueUpload returned taskId=$taskId, pump 1');
      await tester.pump();
      // ignore: avoid_print
      print('DEBUG 6: pump 1 done, pump 2');
      await tester.pump();
      // ignore: avoid_print
      print('DEBUG 7: pump 2 done, first expects');

      expect(
        find.text('Story upload failed: Unsupported file type.'),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('DEBUG 8: failed-text expect passed');
      expect(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('DEBUG 9: retry-button expect passed');
      expect(
        find.byKey(Key('storyUploadStatusBanner_discard_$taskId')),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('DEBUG 10: discard-button expect passed');
      expect(
        find.byKey(Key('storyUploadStatusBanner_cancel_$taskId')),
        findsNothing,
      );
      // ignore: avoid_print
      print('DEBUG 11: no-cancel expect passed, tapping retry');

      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
      );
      // ignore: avoid_print
      print('DEBUG 12: tapped retry, pump 1');
      await tester.pump();
      // ignore: avoid_print
      print('DEBUG 13: pump 1 done, pump 2');
      await tester.pump();
      // ignore: avoid_print
      print('DEBUG 14: pump 2 done, re-check retry button');

      expect(
        find.byKey(Key('storyUploadStatusBanner_retry_$taskId')),
        findsOneWidget,
      );
      // ignore: avoid_print
      print('DEBUG 15: retry-button re-check passed, tapping discard');

      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_discard_$taskId')),
      );
      // ignore: avoid_print
      print('DEBUG 16: tapped discard, pump');
      await tester.pump();
      // ignore: avoid_print
      print('DEBUG 17: pump done, final expects');

      expect(find.byKey(const Key('storyUploadStatusBanner')), findsNothing);
      // ignore: avoid_print
      print('DEBUG 18: banner-gone expect passed');
      expect(container.read(storyUploadQueueProvider), isEmpty);
      // ignore: avoid_print
      print('DEBUG 19: queue-empty expect passed — test body finished');
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

      final mediaFile = await _tempFile();
      addTearDown(() => mediaFile.delete());

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