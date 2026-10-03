import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/stories/data/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';

/// Part P-083 scope. Exercises [OwnStoriesNotifier] against a fake
/// repository and a fake upload queue (no network, no real uploads).

class _FakeOwnStoriesRepository implements OwnStoriesRepository {
  _FakeOwnStoriesRepository(this.results);

  List<OwnStory> results;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<PaginatedResponse<OwnStory>> listOwnStories() async {
    calls++;
    await gate?.future;
    final e = error;
    if (e != null) throw e;
    return PaginatedResponse<OwnStory>(
      results: results,
      next: null,
      previous: null,
    );
  }
}

/// Lets a test drive `storyUploadQueueProvider`'s state directly, without
/// performing real uploads.
class _FakeUploadQueue extends StoryUploadQueueNotifier {
  void emit(List<UploadTask> tasks) => state = tasks;
}

OwnStory _story(int id) {
  return OwnStory(
    id: id,
    businessId: 7,
    mediaUrl: 'https://cdn.example.com/stories/$id.png',
    status: OwnStoryStatus.published,
    publishedAt: DateTime.utc(2026, 9, 30, 10),
    expiresAt: DateTime.utc(2026, 10, 1, 10),
  );
}

UploadTask _task(String id, UploadTaskStatus status) {
  return UploadTask(
    id: id,
    mediaFile: File('story.png'),
    attempt: 1,
    status: status,
    cancelToken: CancelToken(),
  );
}

DioException _serverError() {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/stories/'),
    error: const ServerFailure(message: 'boom'),
  );
}

ProviderContainer _container(_FakeOwnStoriesRepository fake) {
  final container = ProviderContainer(
    overrides: [
      ownStoriesRepositoryProvider.overrideWithValue(fake),
      storyUploadQueueProvider.overrideWith(_FakeUploadQueue.new),
    ],
  );
  // The provider is autoDispose: keep it alive for the whole test.
  container.listen(ownStoriesProvider, (previous, next) {});
  addTearDown(container.dispose);
  return container;
}

_FakeUploadQueue _queue(ProviderContainer container) {
  return container.read(storyUploadQueueProvider.notifier) as _FakeUploadQueue;
}

void main() {
  test('build() loads the first page of own stories', () async {
    final fake = _FakeOwnStoriesRepository([_story(2), _story(1)]);
    final container = _container(fake);

    final stories = await container.read(ownStoriesProvider.future);

    expect(stories.map((s) => s.id), [2, 1]);
    expect(fake.calls, 1);
  });

  test('an empty page is valid data, not an error', () async {
    final fake = _FakeOwnStoriesRepository([]);
    final container = _container(fake);

    final stories = await container.read(ownStoriesProvider.future);

    expect(stories, isEmpty);
    expect(container.read(ownStoriesProvider).hasError, isFalse);
  });

  test('build() failure settles into AsyncError', () async {
    final fake = _FakeOwnStoriesRepository([])..error = _serverError();
    final container = _container(fake);

    await expectLater(
      container.read(ownStoriesProvider.future),
      throwsA(isA<DioException>()),
    );

    expect(container.read(ownStoriesProvider).hasError, isTrue);
  });

  test('refresh() re-fetches and replaces the list', () async {
    final fake = _FakeOwnStoriesRepository([_story(1)]);
    final container = _container(fake);
    await container.read(ownStoriesProvider.future);

    fake.results = [_story(2), _story(1)];
    await container.read(ownStoriesProvider.notifier).refresh();

    expect(container.read(ownStoriesProvider).value!.map((s) => s.id), [2, 1]);
    expect(fake.calls, 2);
  });

  test('refresh() keeps the current list on screen while reloading', () async {
    final fake = _FakeOwnStoriesRepository([_story(1)]);
    final container = _container(fake);
    await container.read(ownStoriesProvider.future);

    final gate = Completer<void>();
    fake.gate = gate;
    final future = container.read(ownStoriesProvider.notifier).refresh();
    await Future<void>.delayed(Duration.zero);

    final during = container.read(ownStoriesProvider);
    expect(during.isLoading, isFalse);
    expect(during.value, [_story(1)]);

    gate.complete();
    await future;
  });

  test(
    'refresh() failure becomes AsyncError and a later refresh recovers',
    () async {
      final fake = _FakeOwnStoriesRepository([_story(1)]);
      final container = _container(fake);
      await container.read(ownStoriesProvider.future);
      final notifier = container.read(ownStoriesProvider.notifier);

      fake.error = _serverError();
      await notifier.refresh();
      expect(container.read(ownStoriesProvider).hasError, isTrue);

      fake.error = null;
      fake.results = [_story(3)];
      await notifier.refresh();

      final recovered = container.read(ownStoriesProvider);
      expect(recovered.hasError, isFalse);
      expect(recovered.value!.map((s) => s.id), [3]);
    },
  );

  test('an upload leaving the queue triggers one refresh', () async {
    final fake = _FakeOwnStoriesRepository([_story(1)]);
    final container = _container(fake);
    await container.read(ownStoriesProvider.future);
    final queue = _queue(container);

    queue.emit([_task('upload_0', UploadTaskStatus.uploading)]);
    await pumpEventQueue();
    expect(fake.calls, 1);

    fake.results = [_story(2), _story(1)];
    queue.emit(const []);
    await pumpEventQueue();

    expect(fake.calls, 2);
    expect(container.read(ownStoriesProvider).value!.map((s) => s.id), [2, 1]);
  });

  test('enqueueing an upload does not refresh', () async {
    final fake = _FakeOwnStoriesRepository([_story(1)]);
    final container = _container(fake);
    await container.read(ownStoriesProvider.future);

    _queue(container).emit([_task('upload_0', UploadTaskStatus.uploading)]);
    await pumpEventQueue();

    expect(fake.calls, 1);
  });

  test('discarding a failed task does not refresh', () async {
    final fake = _FakeOwnStoriesRepository([_story(1)]);
    final container = _container(fake);
    await container.read(ownStoriesProvider.future);
    final queue = _queue(container);

    queue.emit([_task('upload_0', UploadTaskStatus.failed)]);
    await pumpEventQueue();
    queue.emit(const []);
    await pumpEventQueue();

    expect(fake.calls, 1);
  });
}
