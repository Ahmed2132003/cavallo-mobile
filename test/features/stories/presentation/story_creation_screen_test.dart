import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_creation_screen.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';

/// Never resolves — see the banner test's own copy of this class for
/// why (deterministic `uploading` state, no Timer race).
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

/// Returns a [File] pointing at a throwaway path — never actually
/// created or read. FIX: see `story_upload_status_banner_test.dart`'s
/// own `_fakeMediaFile()` doc comment for the full root-cause —
/// `_NeverCompletesRepository` never touches `mediaFile`'s bytes, so a
/// real file write was pure overhead and, on one Windows machine, hung
/// indefinitely (antivirus/real-time-scan interference on that
/// machine's Temp folder, not a bug in this codebase).
File _fakeMediaFile() => File(
  '${Directory.systemTemp.path}/p051_screen_test_'
  '${DateTime.now().microsecondsSinceEpoch}.png',
);

void main() {
  // NOTE (flagged, not silently skipped): neither test here drives the
  // "Add Photo"/"Add Video" buttons — both call the real `image_picker`
  // plugin, which throws `MissingPluginException` with no platform
  // channel mock in a plain widget test. `product_form_screen_test.dart`
  // (P-033) hits the identical limitation and doesn't exercise its own
  // `_pickImage` either. The real pick→submit path is covered by this
  // part's own planned manual test (STEP 6, real airplane-mode test),
  // not here.

  testWidgets(
    'shows a validation error when Post Story is tapped with no media',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StoryCreationScreen())),
      );

      await tester.tap(find.byKey(const Key('storyCreation_submitButton')));
      await tester.pump();

      expect(find.text('Add a photo or video first.'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the persistent status banner once a Story is enqueued, and '
    'Cancel removes it',
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
          child: const MaterialApp(home: StoryCreationScreen()),
        ),
      );

      container.read(storyUploadQueueProvider.notifier).enqueueUpload(
        mediaFile,
      );
      await tester.pump();

      expect(
        find.text('Uploading story... (attempt 1 of 5)'),
        findsOneWidget,
      );

      final taskId = container.read(storyUploadQueueProvider).single.id;
      await tester.tap(
        find.byKey(Key('storyUploadStatusBanner_cancel_$taskId')),
      );
      await tester.pump();

      expect(
        find.text('Uploading story... (attempt 1 of 5)'),
        findsNothing,
      );
      expect(container.read(storyUploadQueueProvider), isEmpty);
    },
  );
}