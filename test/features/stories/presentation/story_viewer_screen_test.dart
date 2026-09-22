import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_viewer_screen.dart';

/// Part P-050 (STEP 7) scope: widget tests for `StoryViewerScreen`.
///
/// Same fake-repository, no-mockito convention as
/// `reel_detail_screen_test.dart` (Part P-045) — see that file's
/// docstring.
///
/// ## Why these tests deliberately avoid `pumpAndSettle()` once a
/// story is loaded
///
/// `_StoryPlayerState.initState` starts a real 5-second
/// `AnimationController.forward()` the instant the first story loads.
/// `pumpAndSettle()` advances the test binding's virtual clock until
/// every scheduled animation finishes — which would silently run that
/// whole 5-second timer (and any auto-advances it triggers) *before*
/// this file's own manual taps ever run. So every test below that
/// reaches a loaded `_StoryPlayer` uses plain `tester.pump()` calls
/// (no duration, or an explicit short duration) to settle the
/// `FutureProvider` without racing the story timer. `pumpAndSettle()`
/// is only used where no story-timer animation is running: the
/// not-found/empty states (no `_StoryPlayer` built at all) and after a
/// route has already popped (the `_StoryPlayerState` — and its
/// `AnimationController` — is disposed by then).
class _FakeStoryPublicRepository implements StoryPublicRepository {
  _FakeStoryPublicRepository({
    this.stories = const [],
    this.fetchError,
    this.pending,
  });

  List<PublicStory> stories;
  Object? fetchError;
  Completer<PaginatedResponse<PublicStory>>? pending;

  int fetchBusinessStoriesCallCount = 0;
  final List<int> recordedViewIds = [];

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    fetchBusinessStoriesCallCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (fetchError != null) {
      throw fetchError!;
    }
    return PaginatedResponse<PublicStory>(
      results: stories,
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {
    recordedViewIds.add(storyId);
  }
}

PublicStory _story(int id) => PublicStory(
  id: id,
  businessId: 1,
  mediaUrl: 'https://example.com/story-$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

/// Simplest mount shape: `StoryViewerScreen` as `MaterialApp`'s `home`.
/// Safe for every test that never advances past the LAST story (so
/// `_advance()` never calls `Navigator.of(context).pop()` on the
/// app's own root route — popping the only route in a `MaterialApp`
/// is not something these tests need to exercise here; see
/// [_pumpPushedScreen] for the tests that DO need a real pop).
Future<void> _pumpScreen(
  WidgetTester tester, {
  required String businessId,
  required _FakeStoryPublicRepository repository,
  String? businessName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyPublicRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: StoryViewerScreen(
          businessId: businessId,
          businessName: businessName,
        ),
      ),
    ),
  );
}

/// Pushes `StoryViewerScreen` as a genuine second route (behind an
/// "open" button), so tests that trigger `Navigator.pop()` — reaching
/// the end of the sequence, or swiping down — have a real route
/// underneath to reveal, instead of trying to pop a `MaterialApp`'s
/// only route.
Future<void> _pumpPushedScreen(
  WidgetTester tester, {
  required String businessId,
  required _FakeStoryPublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyPublicRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StoryViewerScreen(businessId: businessId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  // Finishes the push route's own transition animation (~300ms) —
  // well short of the 5-second story timer, so this never risks an
  // accidental auto-advance.
  await tester.pump(const Duration(milliseconds: 300));
  // Lets the (non-delayed) fetchBusinessStories Future resolve.
  await tester.pump();
}

void main() {
  group('StoryViewerScreen — non-numeric id', () {
    testWidgets(
      'shows not-found immediately, without calling the repository',
      (tester) async {
        final repository = _FakeStoryPublicRepository(stories: [_story(1)]);

        await _pumpScreen(
          tester,
          businessId: 'not-a-number',
          repository: repository,
        );
        await tester.pumpAndSettle();

        expect(find.text('Story not found.'), findsOneWidget);
        expect(repository.fetchBusinessStoriesCallCount, 0);
      },
    );
  });

  group('StoryViewerScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PaginatedResponse<PublicStory>>();
      final repository = _FakeStoryPublicRepository(pending: completer);

      await _pumpScreen(tester, businessId: '1', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        PaginatedResponse<PublicStory>(
          results: [_story(71)],
          next: null,
          previous: null,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('StoryViewerScreen — empty', () {
    testWidgets('AsyncData([]) shows the empty state, not an error', (
      tester,
    ) async {
      final repository = _FakeStoryPublicRepository(stories: const []);

      await _pumpScreen(tester, businessId: '1', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('No stories to show right now.'), findsOneWidget);
    });
  });

  group('StoryViewerScreen — tap-to-advance / tap-to-go-back', () {
    testWidgets(
      'tapping the right half advances to the next story and records a '
      'view for each story as it comes into view',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(11), _story(12), _story(13)],
        );

        await _pumpScreen(tester, businessId: '1', repository: repository);
        await tester.pump();
        await tester.pump();

        // First story's view is recorded the instant the player mounts.
        expect(repository.recordedViewIds, [11]);

        final width = tester.getSize(find.byType(LayoutBuilder)).width;
        final center = tester.getCenter(find.byType(LayoutBuilder));

        // Right half -> advance.
        await tester.tapAt(Offset(center.dx + width / 4, center.dy));
        await tester.pump();

        expect(repository.recordedViewIds, [11, 12]);

        await tester.tapAt(Offset(center.dx + width / 4, center.dy));
        await tester.pump();

        expect(repository.recordedViewIds, [11, 12, 13]);
      },
    );

    testWidgets('reaching the end of the sequence closes the viewer', (
      tester,
    ) async {
      final repository = _FakeStoryPublicRepository(
        stories: [_story(21), _story(22)],
      );

      await _pumpPushedScreen(
        tester,
        businessId: '1',
        repository: repository,
      );

      expect(find.byType(StoryViewerScreen), findsOneWidget);

      final width = tester.getSize(find.byType(LayoutBuilder)).width;
      final center = tester.getCenter(find.byType(LayoutBuilder));

      // Story 1 -> 2.
      await tester.tapAt(Offset(center.dx + width / 4, center.dy));
      await tester.pump();
      // Story 2 (the last one) -> viewer closes.
      await tester.tapAt(Offset(center.dx + width / 4, center.dy));
      await tester.pumpAndSettle();

      expect(find.byType(StoryViewerScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      'tapping the left half on the first story restarts its timer '
      'instead of closing the viewer',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(31), _story(32)],
        );

        await _pumpScreen(tester, businessId: '1', repository: repository);
        await tester.pump();
        await tester.pump();

        final width = tester.getSize(find.byType(LayoutBuilder)).width;
        final center = tester.getCenter(find.byType(LayoutBuilder));

        // Left half, on the very first story -- nothing to go back to.
        await tester.tapAt(Offset(center.dx - width / 4, center.dy));
        await tester.pump();

        // Still on story 1: no additional recordView call, and the
        // viewer is still mounted (didn't close).
        expect(repository.recordedViewIds, [31]);
        expect(find.byType(StoryViewerScreen), findsOneWidget);
      },
    );
  });

  group('StoryViewerScreen — swipe-down-to-dismiss', () {
    testWidgets('a fast downward drag closes the viewer', (tester) async {
      final repository = _FakeStoryPublicRepository(stories: [_story(61)]);

      await _pumpPushedScreen(
        tester,
        businessId: '1',
        repository: repository,
      );

      expect(find.byType(StoryViewerScreen), findsOneWidget);

      await tester.fling(find.byType(LayoutBuilder), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(StoryViewerScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('StoryViewerScreen — auto-advance timer', () {
    testWidgets(
      'auto-advances to the next story after the documented 5-second '
      'duration, with no tap required',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(41), _story(42)],
        );

        await _pumpScreen(tester, businessId: '1', repository: repository);
        await tester.pump();
        await tester.pump();

        expect(repository.recordedViewIds, [41]);

        // Advances the test binding's virtual clock -- the same
        // AnimationController driving `_ProgressBars` completes for
        // real, exactly as it would on a device after 5 real seconds.
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(repository.recordedViewIds, [41, 42]);
      },
    );
  });

  group(
    'StoryViewerScreen — Architecture Section 13: no global-provider leak',
    () {
      testWidgets(
        'closing the viewer mid-sequence and reopening it starts a fresh '
        'session at story 1, not wherever the previous session left off',
        (tester) async {
          final repository = _FakeStoryPublicRepository(
            stories: [_story(51), _story(52), _story(53)],
          );

          final container = ProviderContainer(
            overrides: [
              storyPublicRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(container.dispose);

          Widget buildViewer() => UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StoryViewerScreen(businessId: '1')),
          );

          // --- Session 1: open, advance once. ---
          await tester.pumpWidget(buildViewer());
          await tester.pump();
          await tester.pump();
          expect(repository.recordedViewIds, [51]);

          final width = tester.getSize(find.byType(LayoutBuilder)).width;
          final center = tester.getCenter(find.byType(LayoutBuilder));
          await tester.tapAt(Offset(center.dx + width / 4, center.dy));
          await tester.pump();
          expect(repository.recordedViewIds, [51, 52]);

          // Tear the whole widget tree down -- the concrete proof that
          // nothing survives, per `_StoryPlayerState.dispose()`'s own
          // doc: this is the same observable effect closing the viewer
          // has (an AnimationController with nowhere left to live).
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          // --- Session 2: a brand-new StoryViewerScreen, same
          // ProviderContainer -- proving any leak would have to show
          // up in THIS shared container, since it's the one and only
          // place a leaked global provider could have lived. ---
          await tester.pumpWidget(buildViewer());
          await tester.pump();
          await tester.pump();

          // If `_currentIndex` had leaked into any provider keyed by
          // businessId, this second session would resume at story 2
          // (id 52) instead of starting over at story 1 (id 51).
          expect(repository.recordedViewIds.last, 51);
        },
      );
    },
  );
}