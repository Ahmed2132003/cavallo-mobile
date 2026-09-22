import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/content/data/post_repository_impl.dart';
import 'package:social_commerce_app/features/content/data/reel_repository_impl.dart';
import 'package:social_commerce_app/features/content/domain/moderation_status.dart';
import 'package:social_commerce_app/features/content/domain/post_entity.dart';
import 'package:social_commerce_app/features/content/domain/post_repository.dart';
import 'package:social_commerce_app/features/content/domain/reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_repository.dart';
import 'package:social_commerce_app/features/content/presentation/content_list_screen.dart';

/// Part P-044 scope, STEP 9 — "Widget tests for status-badge rendering
/// per state" per this part's own Testing section. Hand-rolled test
/// doubles for [PostRepository]/[ReelRepository] — this project doesn't
/// use mockito/mocktail anywhere (confirmed against
/// `own_content_provider_test.dart`'s own note before writing this
/// file). Scoped to exactly what [ContentListScreen] exercises through
/// `ownContentProvider`: [fetchOwnPosts]/[fetchOwnReels] (list + error +
/// pending-for-loading-state). [createPost]/[createReel] are never
/// called by this screen directly (only its `onCreatePost`/
/// `onCreateReel` callbacks are, which this screen's own caller
/// supplies) — implemented only to satisfy the interface, and throw if
/// ever hit, same convention as `product_list_screen_test.dart`'s own
/// `_FakeProductRepository`.
class _FakePostRepository implements PostRepository {
  _FakePostRepository({List<Post> fetchResults = const []})
    : currentPosts = List.of(fetchResults);

  List<Post> currentPosts;
  Object? currentFetchError;
  Completer<PaginatedResponse<Post>>? pendingFetch;

  @override
  Future<PaginatedResponse<Post>> fetchOwnPosts() async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    if (currentFetchError != null) {
      throw currentFetchError!;
    }
    return PaginatedResponse<Post>(
      results: List.of(currentPosts),
      next: null,
      previous: null,
    );
  }

  @override
  Future<Post> createPost({required String caption, File? imageFile}) =>
      throw UnimplementedError('Not used by ContentListScreen');
}

class _FakeReelRepository implements ReelRepository {
  _FakeReelRepository({List<Reel> fetchResults = const []})
    : currentReels = List.of(fetchResults);

  List<Reel> currentReels;
  Object? currentFetchError;
  Completer<PaginatedResponse<Reel>>? pendingFetch;

  @override
  Future<PaginatedResponse<Reel>> fetchOwnReels() async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    if (currentFetchError != null) {
      throw currentFetchError!;
    }
    return PaginatedResponse<Reel>(
      results: List.of(currentReels),
      next: null,
      previous: null,
    );
  }

  @override
  Future<Reel> createReel({
    required String caption,
    required File videoFile,
  }) => throw UnimplementedError('Not used by ContentListScreen');
}

const _pendingPost = Post(
  id: 1,
  businessId: 1,
  caption: 'Pending post',
  status: ModerationStatus.pendingReview,
);

const _publishedPost = Post(
  id: 2,
  businessId: 1,
  caption: 'Published post',
  status: ModerationStatus.published,
);

const _rejectedPost = Post(
  id: 3,
  businessId: 1,
  caption: 'Rejected post',
  status: ModerationStatus.rejected,
  rejectionReason: 'Blurry image, resubmit',
);

const _processingReel = Reel(
  id: 10,
  businessId: 1,
  caption: 'Processing reel',
  processingStatus: ReelProcessingStatus.uploaded,
  // Deliberately `published` here — proves the screen shows the
  // "Processing video..." indicator based on `processingStatus`, never
  // the moderation badge, even if `status` were somehow already
  // published (should not normally happen, but the UI must not trust
  // `status` alone for a still-processing Reel — this part's own
  // Architecture Rule).
  status: ModerationStatus.published,
);

const _failedReel = Reel(
  id: 11,
  businessId: 1,
  caption: 'Failed reel',
  processingStatus: ReelProcessingStatus.failed,
  status: ModerationStatus.pendingReview,
);

const _liveReel = Reel(
  id: 12,
  businessId: 1,
  caption: 'Live reel',
  processingStatus: ReelProcessingStatus.ready,
  status: ModerationStatus.published,
);

/// Pumps [ContentListScreen] with `postRepositoryProvider`/
/// `reelRepositoryProvider` overridden. Deliberately a plain
/// [MaterialApp] — NOT `MaterialApp.router`/`GoRouter` — per
/// `content_list_screen.dart`'s own docstring: navigation is injected
/// via `onCreatePost`/`onCreateReel`, so no router is needed to test
/// this screen at all. Same convention as
/// `product_list_screen_test.dart`'s own `_pumpScreen`.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakePostRepository postRepository,
  required _FakeReelRepository reelRepository,
  VoidCallback? onCreatePost,
  VoidCallback? onCreateReel,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(postRepository),
        reelRepositoryProvider.overrideWithValue(reelRepository),
      ],
      child: MaterialApp(
        home: ContentListScreen(
          onCreatePost: onCreatePost ?? () {},
          onCreateReel: onCreateReel ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('ContentListScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PaginatedResponse<Post>>();
      final postRepository = _FakePostRepository()..pendingFetch = completer;
      final reelRepository = _FakeReelRepository();

      await _pumpScreen(
        tester,
        postRepository: postRepository,
        reelRepository: reelRepository,
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const PaginatedResponse<Post>(
          results: [_pendingPost],
          next: null,
          previous: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Pending post'), findsOneWidget);
    });
  });

  group('ContentListScreen — empty', () {
    testWidgets(
      'a business with no posts or reels yet shows the empty state',
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostRepository(),
          reelRepository: _FakeReelRepository(),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No posts or reels yet.\nTap "New Post" or "New Reel" to '
            'share your first one.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('ContentListScreen — status badges', () {
    testWidgets('a pending Post shows the amber "Under review" badge', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(fetchResults: [_pendingPost]),
        reelRepository: _FakeReelRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Pending post'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('a published Post shows the green "Live" badge', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(fetchResults: [_publishedPost]),
        reelRepository: _FakeReelRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets(
      'a rejected Post shows the red "Rejected: {reason}" badge with '
      "the backend's real reason text",
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostRepository(fetchResults: [_rejectedPost]),
          reelRepository: _FakeReelRepository(),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Rejected: Blurry image, resubmit'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a Reel still processing shows "Processing video..." — NEVER '
      '"Under review", even with a published status underneath',
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostRepository(),
          reelRepository: _FakeReelRepository(
            fetchResults: [_processingReel],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Processing video'), findsOneWidget);
        expect(find.text('Under review'), findsNothing);
        expect(find.text('Live'), findsNothing);
      },
    );

    testWidgets('a Reel whose transcoding failed shows the failure badge', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(),
        reelRepository: _FakeReelRepository(fetchResults: [_failedReel]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video processing failed'), findsOneWidget);
    });

    testWidgets(
      'a Reel that finished processing and was published shows the '
      'real moderation badge, exactly like a Post',
      (tester) async {
        await _pumpScreen(
          tester,
          postRepository: _FakePostRepository(),
          reelRepository: _FakeReelRepository(fetchResults: [_liveReel]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live'), findsOneWidget);
        expect(find.textContaining('Processing video'), findsNothing);
      },
    );

    testWidgets('Posts and Reels render together, each correctly labeled', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(fetchResults: [_pendingPost]),
        reelRepository: _FakeReelRepository(fetchResults: [_liveReel]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Post'), findsOneWidget);
      expect(find.text('Reel'), findsOneWidget);
      expect(find.text('Pending post'), findsOneWidget);
      expect(find.text('Live reel'), findsOneWidget);
    });
  });

  group('ContentListScreen — creation entry points', () {
    testWidgets('tapping "New Post" invokes onCreatePost', (tester) async {
      var tapped = false;

      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(),
        reelRepository: _FakeReelRepository(),
        onCreatePost: () => tapped = true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Post'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('tapping "New Reel" invokes onCreateReel', (tester) async {
      var tapped = false;

      await _pumpScreen(
        tester,
        postRepository: _FakePostRepository(),
        reelRepository: _FakeReelRepository(),
        onCreateReel: () => tapped = true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Reel'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('ContentListScreen — error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button',
      (tester) async {
        final postRepository = _FakePostRepository()
          ..currentFetchError = const ServerFailure(
            message: 'Something broke.',
          );

        await _pumpScreen(
          tester,
          postRepository: postRepository,
          reelRepository: _FakeReelRepository(),
        );
        await tester.pumpAndSettle();

        expect(find.text('Something broke.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('tapping Retry re-fetches and shows the recovered list', (
      tester,
    ) async {
      final postRepository = _FakePostRepository()
        ..currentFetchError = const ServerFailure(message: 'Something broke.');
      final reelRepository = _FakeReelRepository();

      await _pumpScreen(
        tester,
        postRepository: postRepository,
        reelRepository: reelRepository,
      );
      await tester.pumpAndSettle();

      postRepository.currentFetchError = null;
      postRepository.currentPosts = [_pendingPost];

      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Pending post'), findsOneWidget);
    });
  });
}