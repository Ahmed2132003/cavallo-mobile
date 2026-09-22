import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/content/data/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/presentation/reel_detail_screen.dart';

/// Part P-045 (STEP 8) scope: widget tests for `ReelDetailScreen`
/// (`/reel/:id`). Same fake-repository shape as
/// `post_detail_screen_test.dart`'s `_FakePostPublicRepository` — see
/// that file's docstring for the "no mockito/mocktail" convention this
/// mirrors.
class _FakeReelPublicRepository implements ReelPublicRepository {
  _FakeReelPublicRepository({this.result, this.error, this.pending});

  PublicReel? result;
  Object? error;
  Completer<PublicReel?>? pending;
  int fetchPublicReelCallCount = 0;

  @override
  Future<PublicReel?> fetchPublicReel(int id) async {
    fetchPublicReelCallCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }

  // Unused by this screen — same "implemented to satisfy the interface"
  // convention as _FakePostPublicRepository.fetchBusinessPosts.
  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async => const PaginatedResponse<PublicReel>(
    results: [],
    next: null,
    previous: null,
  );
}

const _reel = PublicReel(
  id: 601,
  businessId: 7,
  caption: 'A published reel, seen at /reel/601.',
  videoUrl: 'https://example.com/reel-601.mp4',
  thumbnailUrl: 'https://example.com/reel-601-thumb.jpg',
  durationSeconds: 125,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required String reelId,
  required _FakeReelPublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reelPublicRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: ReelDetailScreen(reelId: reelId)),
    ),
  );
}

void main() {
  group('ReelDetailScreen — non-numeric id', () {
    testWidgets(
      'shows not-found immediately, without calling the repository',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(
          tester,
          reelId: 'not-a-number',
          repository: repository,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Reel not found.\nIt may have been removed.'),
          findsOneWidget,
        );
        expect(repository.fetchPublicReelCallCount, 0);
      },
    );
  });

  group('ReelDetailScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PublicReel?>();
      final repository = _FakeReelPublicRepository(pending: completer);

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_reel);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ReelDetailScreen — found', () {
    testWidgets(
      'shows the caption, the formatted duration, and the stub action row',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.text('A published reel, seen at /reel/601.'),
          findsOneWidget,
        );
        // 125 seconds -> 2:05, per ReelDetailScreen's own
        // `_formatDuration` (mm:ss, no leading hour segment).
        expect(find.text('2:05'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      },
    );

    testWidgets('no durationSeconds means no duration label is shown', (
      tester,
    ) async {
      final repository = _FakeReelPublicRepository(
        result: const PublicReel(
          id: 602,
          businessId: 7,
          caption: 'No duration on this one.',
        ),
      );

      await _pumpScreen(tester, reelId: '602', repository: repository);
      await tester.pumpAndSettle();

      // No mm:ss label anywhere on screen when durationSeconds is null —
      // the caption itself deliberately contains no colon, so this also
      // confirms _ReelDetailView's `if (duration != null)` guard.
      expect(find.textContaining(':'), findsNothing);
    });

    testWidgets('an empty caption shows the placeholder copy', (
      tester,
    ) async {
      final repository = _FakeReelPublicRepository(
        result: const PublicReel(id: 603, businessId: 7, caption: ''),
      );

      await _pumpScreen(tester, reelId: '603', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('No caption.'), findsOneWidget);
    });

    testWidgets(
      'tapping the play stub shows an honest "coming soon" SnackBar '
      'instead of pretending to play real video',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        final playIcon = find.byIcon(Icons.play_arrow);
        await tester.ensureVisible(playIcon);
        await tester.pumpAndSettle();

        await tester.tap(playIcon);
        await tester.pump();

        expect(find.text('Video playback — Coming soon'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a like/comment/share stub icon shows the honest '
      '"coming soon" SnackBar',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        final shareIcon = find.byIcon(Icons.share_outlined);
        await tester.ensureVisible(shareIcon);
        await tester.pumpAndSettle();

        await tester.tap(shareIcon);
        await tester.pump();

        expect(find.text('Share — Coming soon'), findsOneWidget);
      },
    );
  });

  group(
    'ReelDetailScreen — not found (numeric id, real 404 / unpublished / not-ready)',
    () {
      testWidgets(
        'AsyncData(null) shows the not-found state, not a generic error',
        (tester) async {
          final repository = _FakeReelPublicRepository(result: null);

          await _pumpScreen(
            tester,
            reelId: '999999',
            repository: repository,
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Reel not found.\nIt may have been removed.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('ReelDetailScreen — error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button',
      (tester) async {
        final repository = _FakeReelPublicRepository(
          error: const ServerFailure(message: 'Something broke.'),
        );

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Something broke.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('tapping Retry re-invokes the repository', (tester) async {
      final repository = _FakeReelPublicRepository(
        error: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicReelCallCount, 1);

      repository.error = null;
      repository.result = _reel;

      final retryButton = find.widgetWithText(AppButton, 'Retry');
      await tester.ensureVisible(retryButton);
      await tester.pumpAndSettle();

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicReelCallCount, 2);
      expect(
        find.text('A published reel, seen at /reel/601.'),
        findsOneWidget,
      );
    });
  });
}