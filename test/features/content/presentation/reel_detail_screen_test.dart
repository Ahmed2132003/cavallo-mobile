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
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-045 (STEP 8) scope: widget tests for `ReelDetailScreen`
/// (`/reel/:id`). Same fake-repository shape as
/// `post_detail_screen_test.dart`'s `_FakePostPublicRepository`.
///
/// Part P-058 update: every test also overrides the social repository with
/// a controllable fake, since the screen now contains the real action row,
/// the comments section and a Report menu.
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

  // Unused by this screen — implemented to satisfy the interface.
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
  FakeSocialInteractionRepository? social,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reelPublicRepositoryProvider.overrideWithValue(repository),
        socialInteractionRepositoryProvider.overrideWithValue(
          social ?? FakeSocialInteractionRepository(),
        ),
      ],
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
      expect(find.byTooltip('More options'), findsNothing);

      completer.complete(_reel);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ReelDetailScreen — found', () {
    testWidgets(
      'shows the caption, the formatted duration, the real action row and '
      'the comments section',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.text('A published reel, seen at /reel/601.'),
          findsOneWidget,
        );
        // 125 seconds -> 2:05, per ReelDetailScreen's own `_formatDuration`
        // (mm:ss, no leading hour segment).
        expect(find.text('2:05'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
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
      // nothing else on this screen (caption, comments section copy)
      // contains a colon either.
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
      'tapping Like shows the liked state immediately, before any response',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          reelId: '601',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        // Close the gate only now, after the initial comment load finished.
        social.gate = Completer<void>();

        final likeButton = find.byTooltip('Like');
        await tester.ensureVisible(likeButton);
        await tester.pumpAndSettle();

        await tester.tap(likeButton);
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);

        social.gate!.complete();
        await tester.pumpAndSettle();

        expect(social.calls, contains('like:reel:601'));
      },
    );

    testWidgets(
      'posting a comment adds it to the list and bumps the comment count',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          reelId: '601',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();

        await tester.enterText(field, 'nice reel');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(social.calls, contains('createComment:reel:601'));
        expect(find.text('nice reel'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'the AppBar "..." menu appears once loaded and reports the Reel',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          reelId: '601',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
        await tester.pumpAndSettle();

        expect(social.calls, contains('report:reel:601:other'));
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