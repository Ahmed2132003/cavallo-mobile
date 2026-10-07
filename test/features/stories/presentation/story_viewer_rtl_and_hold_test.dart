import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_viewer_screen.dart';

/// Part P-114 STEP 1: story viewer tap zones in LTR and RTL, hold-to-pause,
/// and the header. Same fake-repository convention as the P-050 tests, and the
/// same rule: no `pumpAndSettle()` while a story timer is running.
class _FakeRepository implements StoryPublicRepository {
  _FakeRepository(this.stories);

  final List<PublicStory> stories;
  final List<int> recordedViewIds = <int>[];

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

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository,
  TextDirection direction,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storyPublicRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        builder:
            (BuildContext context, Widget? app) =>
                Directionality(textDirection: direction, child: app!),
        home: const StoryViewerScreen(
          businessId: '1',
          businessName: 'Alpha Traders',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapQuarter(WidgetTester tester, {required bool rightSide}) async {
  final Size size = tester.getSize(find.byType(LayoutBuilder));
  final Offset center = tester.getCenter(find.byType(LayoutBuilder));
  final double dx = rightSide ? size.width / 4 : -size.width / 4;
  await tester.tapAt(Offset(center.dx + dx, center.dy));
  await tester.pump();
}

void main() {
  group('P-114 STEP 1: storyTapAdvances', () {
    test('LTR: right half forward, left half back', () {
      expect(
        storyTapAdvances(dx: 300, width: 400, direction: TextDirection.ltr),
        isTrue,
      );
      expect(
        storyTapAdvances(dx: 100, width: 400, direction: TextDirection.ltr),
        isFalse,
      );
    });

    test('RTL: left half forward, right half back', () {
      expect(
        storyTapAdvances(dx: 100, width: 400, direction: TextDirection.rtl),
        isTrue,
      );
      expect(
        storyTapAdvances(dx: 300, width: 400, direction: TextDirection.rtl),
        isFalse,
      );
    });
  });

  group('P-114 STEP 1: StoryViewerScreen tap zones', () {
    testWidgets('LTR: right goes forward, left goes back', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(201), _story(202), _story(203)],
      );
      await _pump(tester, repository, TextDirection.ltr);
      expect(repository.recordedViewIds, <int>[201]);

      await _tapQuarter(tester, rightSide: true);
      expect(repository.recordedViewIds, <int>[201, 202]);

      await _tapQuarter(tester, rightSide: false);
      expect(repository.recordedViewIds, <int>[201, 202, 201]);
    });

    testWidgets('RTL: left goes forward, right (reading start) goes back', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(211), _story(212), _story(213)],
      );
      await _pump(tester, repository, TextDirection.rtl);
      expect(repository.recordedViewIds, <int>[211]);

      // Left half = reading END = forward.
      await _tapQuarter(tester, rightSide: false);
      expect(repository.recordedViewIds, <int>[211, 212]);

      // Right half = reading START = back.
      await _tapQuarter(tester, rightSide: true);
      expect(repository.recordedViewIds, <int>[211, 212, 211]);
    });
  });

  group('P-114 STEP 1: StoryViewerScreen header and hold', () {
    testWidgets('header shows the business name and a close button', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(221), _story(222)],
      );
      await _pump(tester, repository, TextDirection.ltr);

      expect(find.text('Alpha Traders'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('holding pauses the timer, releasing resumes it', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(231), _story(232), _story(233)],
      );
      await _pump(tester, repository, TextDirection.ltr);
      expect(repository.recordedViewIds, <int>[231]);

      final Offset center = tester.getCenter(find.byType(LayoutBuilder));
      final TestGesture gesture = await tester.startGesture(center);
      // Long-press is recognised after 500 ms.
      await tester.pump(const Duration(milliseconds: 600));

      // 6 s of holding: far past the 5 s story duration, still on story 1.
      await tester.pump(const Duration(seconds: 6));
      expect(repository.recordedViewIds, <int>[231]);

      await gesture.up();
      await tester.pump();

      // Resumed: the remaining ~4.4 s run, then it advances.
      await tester.pump(const Duration(seconds: 5, milliseconds: 200));
      await tester.pump();
      expect(repository.recordedViewIds, <int>[231, 232]);
    });
  });
}