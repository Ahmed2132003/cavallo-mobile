import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/loading_indicator.dart';
import 'package:social_commerce_app/features/stories/data/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/story_list_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-083 scope. Exercises [StoryListScreen] with a hand-rolled fake
/// repository (this project uses no mockito/mocktail) and a pinned clock.

class _FakeOwnStoriesRepository implements OwnStoriesRepository {
  _FakeOwnStoriesRepository({List<OwnStory> results = const []})
    : results = List.of(results);

  List<OwnStory> results;
  Object? error;
  Completer<PaginatedResponse<OwnStory>>? pendingFetch;
  int calls = 0;

  @override
  Future<PaginatedResponse<OwnStory>> listOwnStories() async {
    calls++;
    final pending = pendingFetch;
    if (pending != null) return pending.future;
    final e = error;
    if (e != null) throw e;
    return PaginatedResponse<OwnStory>(
      results: List.of(results),
      next: null,
      previous: null,
    );
  }
}

final _now = DateTime.utc(2026, 9, 30, 12);

OwnStory _story({
  required int id,
  OwnStoryStatus status = OwnStoryStatus.published,
  Duration expiresIn = const Duration(hours: 5, minutes: 30),
  String? media,
  String? rejectionReason,
}) {
  final expiresAt = _now.add(expiresIn);
  return OwnStory(
    id: id,
    businessId: 7,
    mediaUrl: media ?? 'https://cdn.example.com/stories/$id.png',
    status: status,
    publishedAt: expiresAt.subtract(const Duration(hours: 24)),
    expiresAt: expiresAt,
    rejectionReason: rejectionReason,
  );
}

Future<void> _pump(WidgetTester tester, _FakeOwnStoriesRepository fake) async {
  final router = GoRouter(
    initialLocation: '/stories',
    routes: [
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoryListScreen(),
      ),
      GoRoute(
        path: RouteNames.storyFormPath,
        name: RouteNames.storyForm,
        builder:
            (context, state) => const Scaffold(
              body: Text('story form stub', key: Key('story-form-stub')),
            ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ownStoriesRepositoryProvider.overrideWithValue(fake),
        storyListClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

DioException _serverError() {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/stories/'),
    error: const ServerFailure(message: 'boom'),
  );
}

void main() {
  testWidgets('shows the loading indicator while the first fetch is pending', (
    tester,
  ) async {
    final fake =
        _FakeOwnStoriesRepository()
          ..pendingFetch = Completer<PaginatedResponse<OwnStory>>();

    await _pump(tester, fake);
    await tester.pump();

    expect(find.byType(LoadingIndicator), findsOneWidget);

    fake.pendingFetch!.complete(
      const PaginatedResponse<OwnStory>(
        results: [],
        next: null,
        previous: null,
      ),
    );
    await tester.pump();
  });

  testWidgets('has a "Stories" AppBar and the Create Story button', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository(results: [_story(id: 1)]);

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Stories')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('story-list-create-button')), findsOneWidget);
    expect(find.text('Create Story'), findsOneWidget);
  });

  testWidgets('shows the right status chip for each kind of story', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository(
      results: [
        _story(id: 1), // published, live
        _story(id: 2, status: OwnStoryStatus.pendingReview),
        _story(id: 3, status: OwnStoryStatus.rejected),
        _story(id: 4, expiresIn: const Duration(minutes: -5)), // expired
      ],
    );

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    Finder chip(int id, String label) => find.descendant(
      of: find.byKey(Key('story-status-$id')),
      matching: find.text(label),
    );

    expect(chip(1, 'Published'), findsOneWidget);
    expect(chip(2, 'Pending'), findsOneWidget);
    expect(chip(3, 'Rejected'), findsOneWidget);
    expect(chip(4, 'Expired'), findsOneWidget);
  });

  testWidgets('shows the remaining time only for a live published story', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository(
      results: [
        _story(id: 1),
        _story(id: 2, status: OwnStoryStatus.pendingReview),
        _story(id: 3, status: OwnStoryStatus.rejected),
        _story(id: 4, expiresIn: const Duration(minutes: -5)),
      ],
    );

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(find.text('5h 30m left'), findsOneWidget);
    expect(find.textContaining('left'), findsOneWidget);
  });

  testWidgets('shows the rejection reason only when the backend sent one', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository(
      results: [
        _story(
          id: 1,
          status: OwnStoryStatus.rejected,
          rejectionReason: 'Blurry image',
        ),
        _story(id: 2, status: OwnStoryStatus.rejected),
      ],
    );

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(find.text('Reason: Blurry image'), findsOneWidget);
    expect(find.textContaining('Reason:'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state and keeps the Create button', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository();

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
    expect(find.byKey(const Key('story-list-error')), findsNothing);
    expect(find.byKey(const Key('story-list-create-button')), findsOneWidget);
  });

  testWidgets('a failed load shows the error state with the real message', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository()..error = _serverError();

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-list-error')), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.byKey(const Key('story-list-create-button')), findsOneWidget);
  });

  testWidgets('Retry reloads and replaces the error with the list', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository()..error = _serverError();

    await _pump(tester, fake);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-list-error')), findsOneWidget);

    fake.error = null;
    fake.results = [_story(id: 1)];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-list-error')), findsNothing);
    expect(find.byKey(const Key('story-list-item-1')), findsOneWidget);
    expect(fake.calls, 2);
  });

  testWidgets('pull-to-refresh on the list re-fetches', (tester) async {
    final fake = _FakeOwnStoriesRepository(results: [_story(id: 1)]);

    await _pump(tester, fake);
    await tester.pumpAndSettle();
    expect(fake.calls, 1);

    fake.results = [_story(id: 2), _story(id: 1)];
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(fake.calls, 2);
    expect(find.byKey(const Key('story-list-item-2')), findsOneWidget);
  });

  testWidgets('pull-to-refresh works on the empty state too', (tester) async {
    final fake = _FakeOwnStoriesRepository();

    await _pump(tester, fake);
    await tester.pumpAndSettle();
    expect(fake.calls, 1);

    fake.results = [_story(id: 1)];
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(fake.calls, 2);
    expect(find.byKey(const Key('story-list-empty')), findsNothing);
    expect(find.byKey(const Key('story-list-item-1')), findsOneWidget);
  });

  testWidgets('the Create Story button opens the story creation route', (
    tester,
  ) async {
    // A video URL on purpose: the screen renders a video icon for it, so no
    // Image.network is created. With a photo, the pushed route pauses the
    // image stream listener and the test HTTP layer's 400 would surface as an
    // unhandled image-load exception (a test-environment artifact only).
    final fake = _FakeOwnStoriesRepository(
      results: [_story(id: 1, media: 'https://cdn.example.com/stories/1.mp4')],
    );

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('story-list-create-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-form-stub')), findsOneWidget);
  });

  testWidgets('a video story shows the video icon, a photo shows the image', (
    tester,
  ) async {
    final fake = _FakeOwnStoriesRepository(
      results: [
        _story(id: 1),
        _story(id: 2, media: 'https://cdn.example.com/stories/2.mp4?x=1'),
      ],
    );

    await _pump(tester, fake);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
