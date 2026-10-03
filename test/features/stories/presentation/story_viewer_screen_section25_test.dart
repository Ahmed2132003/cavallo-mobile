import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_viewer_screen.dart';

/// Part P-097 (STEP 1) scope: the dedicated Architecture Section 25
/// closing pass for `StoryViewerScreen`.
///
/// `story_viewer_screen_test.dart` (P-050) already covers: tap-right
/// advance, end-of-sequence close, tap-left on the FIRST story,
/// a fast swipe-down, a single 5s auto-advance, and a basic
/// "fresh session" check. This file adds only what that file does not:
///
///  - tap-left on a LATER story goes back to the previous story
///  - tap-left on the first story really restarts the timer
///  - auto-advance chains through several stories
///  - auto-advance on the LAST story closes the viewer
///  - a slow drag / upward fling does NOT dismiss the viewer
///  - Section 13 isolation across two real, sequential route sessions
///
/// Same convention as P-050: no `pumpAndSettle()` while a `_StoryPlayer`
/// is mounted (its 5s AnimationController would run to completion and
/// pop/advance before the test's own actions). Plain `pump(duration)` only.
class _FakeStoryPublicRepository implements StoryPublicRepository {
  _FakeStoryPublicRepository({this.stories = const []});

  List<PublicStory> stories;
  final List<int> recordedViewIds = [];

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeStoryPublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storyPublicRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: StoryViewerScreen(businessId: '1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Pushes the viewer as a genuine second route so `Navigator.pop()`
/// (end of sequence, swipe, close button) has a route to reveal.
/// Uses the SAME [container] for every call so a leak into any global
/// provider would be visible across sessions.
Widget _pushHost(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StoryViewerScreen(businessId: '1'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPushed(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  // Finishes the route transition (~300ms), far short of the 5s timer.
  await tester.pump(const Duration(milliseconds: 300));
  // Lets the fetchBusinessStories Future resolve.
  await tester.pump();
}

Future<void> _tapRight(WidgetTester tester) async {
  final width = tester.getSize(find.byType(LayoutBuilder)).width;
  final center = tester.getCenter(find.byType(LayoutBuilder));
  await tester.tapAt(Offset(center.dx + width / 4, center.dy));
  await tester.pump();
}

Future<void> _tapLeft(WidgetTester tester) async {
  final width = tester.getSize(find.byType(LayoutBuilder)).width;
  final center = tester.getCenter(find.byType(LayoutBuilder));
  await tester.tapAt(Offset(center.dx - width / 4, center.dy));
  await tester.pump();
}

// 5s story duration + 100ms buffer: the AnimationController only latches
// its start time on the first tick after forward(), so exactly 5000ms can
// land a hair under 1.0 (same note as the P-050 auto-advance test).
const _storyTickWithBuffer = Duration(seconds: 5, milliseconds: 100);

void main() {
  group('StoryViewerScreen (Section 25) - tap-left goes back', () {
    testWidgets(
      'tapping the left half on a LATER story returns to the previous '
      'story and records its view again',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(101), _story(102), _story(103)],
        );

        await _pumpScreen(tester, repository: repository);
        expect(repository.recordedViewIds, [101]);

        await _tapRight(tester);
        expect(repository.recordedViewIds, [101, 102]);

        await _tapRight(tester);
        expect(repository.recordedViewIds, [101, 102, 103]);

        // Left half on story 3 -> back to story 2.
        await _tapLeft(tester);
        expect(repository.recordedViewIds, [101, 102, 103, 102]);

        // Left half on story 2 -> back to story 1.
        await _tapLeft(tester);
        expect(repository.recordedViewIds, [101, 102, 103, 102, 101]);

        // Still mounted: going back never closes the viewer.
        expect(find.byType(StoryViewerScreen), findsOneWidget);
      },
    );

    testWidgets(
      'tapping left on the FIRST story restarts its 5s timer '
      '(it does not auto-advance at the original 5s mark)',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(111), _story(112)],
        );

        await _pumpScreen(tester, repository: repository);
        expect(repository.recordedViewIds, [111]);

        // 3s in, restart the timer by tapping left on the first story.
        await tester.pump(const Duration(seconds: 3));
        await _tapLeft(tester);

        // 3s more = 6s since mount. Without a restart the story would
        // already have auto-advanced at 5s. With the restart only 3s of
        // the NEW cycle have elapsed.
        await tester.pump(const Duration(seconds: 3));
        expect(repository.recordedViewIds, [111]);

        // 2.2s more = 5.2s of the new cycle -> now it advances.
        await tester.pump(const Duration(seconds: 2, milliseconds: 200));
        await tester.pump();
        expect(repository.recordedViewIds, [111, 112]);
      },
    );
  });

  group('StoryViewerScreen (Section 25) - auto-advance', () {
    testWidgets(
      'auto-advance chains through every story with no taps',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(121), _story(122), _story(123)],
        );

        await _pumpScreen(tester, repository: repository);
        expect(repository.recordedViewIds, [121]);

        await tester.pump(_storyTickWithBuffer);
        await tester.pump();
        expect(repository.recordedViewIds, [121, 122]);

        await tester.pump(_storyTickWithBuffer);
        await tester.pump();
        expect(repository.recordedViewIds, [121, 122, 123]);
      },
    );

    testWidgets(
      'auto-advance on the LAST story closes the viewer by itself',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(131), _story(132)],
        );
        final container = ProviderContainer(
          overrides: [
            storyPublicRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_pushHost(container));
        await _openPushed(tester);
        expect(find.byType(StoryViewerScreen), findsOneWidget);

        // Story 1 -> 2 by timer.
        await tester.pump(_storyTickWithBuffer);
        await tester.pump();
        expect(repository.recordedViewIds, [131, 132]);
        expect(find.byType(StoryViewerScreen), findsOneWidget);

        // Story 2 (last) finishes -> viewer pops itself.
        await tester.pump(_storyTickWithBuffer);
        await tester.pumpAndSettle();

        expect(find.byType(StoryViewerScreen), findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
    );
  });

  group('StoryViewerScreen (Section 25) - swipe-down dismiss', () {
    testWidgets(
      'a slow downward drag (no fling velocity) does NOT dismiss',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(141), _story(142)],
        );

        await _pumpScreen(tester, repository: repository);

        await tester.drag(find.byType(LayoutBuilder), const Offset(0, 300));
        await tester.pump();

        expect(find.byType(StoryViewerScreen), findsOneWidget);
      },
    );

    testWidgets('a fast UPWARD fling does NOT dismiss', (tester) async {
      final repository = _FakeStoryPublicRepository(
        stories: [_story(151), _story(152)],
      );

      await _pumpScreen(tester, repository: repository);

      await tester.fling(
        find.byType(LayoutBuilder),
        const Offset(0, -300),
        1000,
      );
      await tester.pump();

      expect(find.byType(StoryViewerScreen), findsOneWidget);
    });
  });

  group('StoryViewerScreen (Section 25) - Section 13 local-state isolation',
      () {
    testWidgets(
      'two sequential REAL route sessions on one shared container: '
      'session 2 starts at story 1, not where session 1 stopped',
      (tester) async {
        final repository = _FakeStoryPublicRepository(
          stories: [_story(161), _story(162), _story(163)],
        );
        final container = ProviderContainer(
          overrides: [
            storyPublicRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_pushHost(container));

        // --- Session 1: open, advance twice (now on the LAST story). ---
        await _openPushed(tester);
        expect(repository.recordedViewIds, [161]);
        await _tapRight(tester);
        await _tapRight(tester);
        expect(repository.recordedViewIds, [161, 162, 163]);

        // Close via the close button (a real pop, not a widget teardown).
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(StoryViewerScreen), findsNothing);

        // --- Session 2: reopen through the same route + container. ---
        await _openPushed(tester);

        // Exactly ONE new view, and it is story 1 (161). If _currentIndex
        // or timer progress had leaked anywhere, session 2 would resume at
        // story 3 (163) or record extra views.
        expect(repository.recordedViewIds, [161, 162, 163, 161]);

        // And session 2 is itself a normal, independent session: a tap
        // advances to story 2, not to the end.
        await _tapRight(tester);
        expect(repository.recordedViewIds, [161, 162, 163, 161, 162]);
        expect(find.byType(StoryViewerScreen), findsOneWidget);
      },
    );
  });
}
