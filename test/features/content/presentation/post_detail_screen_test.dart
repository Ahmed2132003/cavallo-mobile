import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/content/data/post_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/post_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/presentation/post_detail_screen.dart';

/// Part P-045 (STEP 8) scope: widget tests for `PostDetailScreen`
/// (`/post/:id`) — the Testing section's own explicit requirement
/// ("Widget tests for ... both detail screens"). Hand-rolled fake, same
/// shape as every other fake repository in this project (no
/// mockito/mocktail — confirmed against PROJECT_PROGRESS.md's own
/// P-021a note): a mutable result/error, an optional pending
/// [Completer] for a deterministic loading state, and a call counter so
/// the non-numeric-id test can assert zero network calls.
class _FakePostPublicRepository implements PostPublicRepository {
  _FakePostPublicRepository({this.result, this.error, this.pending});

  PublicPost? result;
  Object? error;
  Completer<PublicPost?>? pending;
  int fetchPublicPostCallCount = 0;

  @override
  Future<PublicPost?> fetchPublicPost(int id) async {
    fetchPublicPostCallCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }

  // Unused by this screen (PostDetailScreen only reads
  // postPublicDetailProvider, which calls fetchPublicPost) — implemented
  // to satisfy the interface, same convention as this project's other
  // single-purpose fakes.
  @override
  Future<PaginatedResponse<PublicPost>> fetchBusinessPosts(
    int businessId,
  ) async => const PaginatedResponse<PublicPost>(
    results: [],
    next: null,
    previous: null,
  );
}

const _post = PublicPost(
  id: 501,
  businessId: 7,
  caption: 'A published post, seen at /post/501.',
  imageUrl: 'https://example.com/post-501.jpg',
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required String postId,
  required _FakePostPublicRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [postPublicRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: PostDetailScreen(postId: postId)),
    ),
  );
}

void main() {
  group('PostDetailScreen — non-numeric id', () {
    testWidgets(
      'shows not-found immediately, without calling the repository',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);

        await _pumpScreen(
          tester,
          postId: 'not-a-number',
          repository: repository,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Post not found.\nIt may have been removed.'),
          findsOneWidget,
        );
        expect(repository.fetchPublicPostCallCount, 0);
      },
    );
  });

  group('PostDetailScreen — loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PublicPost?>();
      final repository = _FakePostPublicRepository(pending: completer);

      await _pumpScreen(tester, postId: '501', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_post);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('PostDetailScreen — found', () {
    testWidgets(
      'shows the caption and the stub action row for a published post',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);

        await _pumpScreen(tester, postId: '501', repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.text('A published post, seen at /post/501.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      },
    );

    testWidgets('an empty caption shows the placeholder copy', (
      tester,
    ) async {
      final repository = _FakePostPublicRepository(
        result: const PublicPost(id: 502, businessId: 7, caption: ''),
      );

      await _pumpScreen(tester, postId: '502', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('No caption.'), findsOneWidget);
    });

    testWidgets(
      'tapping a stub icon shows the honest "coming soon" SnackBar '
      'instead of doing nothing silently',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);

        await _pumpScreen(tester, postId: '501', repository: repository);
        await tester.pumpAndSettle();

        // Full-screen image at the default 800×600 test surface can push
        // the action row below the fold (same reasoning as
        // post_card_test.dart's own overflow note) — ensureVisible
        // scrolls it into view before the tap, same fix already proven
        // in business_profile_public_content_section_test.dart.
        final likeIcon = find.byIcon(Icons.favorite_border);
        await tester.ensureVisible(likeIcon);
        await tester.pumpAndSettle();

        await tester.tap(likeIcon);
        await tester.pump();

        expect(find.text('Like — Coming soon'), findsOneWidget);
      },
    );
  });

  group(
    'PostDetailScreen — not found (numeric id, real 404 / unpublished)',
    () {
      testWidgets(
        'AsyncData(null) shows the not-found state, not a generic error',
        (tester) async {
          final repository = _FakePostPublicRepository(result: null);

          await _pumpScreen(
            tester,
            postId: '999999',
            repository: repository,
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Post not found.\nIt may have been removed.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('PostDetailScreen — error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button',
      (tester) async {
        final repository = _FakePostPublicRepository(
          error: const ServerFailure(message: 'Something broke.'),
        );

        await _pumpScreen(tester, postId: '501', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Something broke.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
        expect(
          find.text('Post not found.\nIt may have been removed.'),
          findsNothing,
        );
      },
    );

    testWidgets('tapping Retry re-invokes the repository', (tester) async {
      final repository = _FakePostPublicRepository(
        error: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, postId: '501', repository: repository);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicPostCallCount, 1);

      repository.error = null;
      repository.result = _post;

      final retryButton = find.widgetWithText(AppButton, 'Retry');
      await tester.ensureVisible(retryButton);
      await tester.pumpAndSettle();

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicPostCallCount, 2);
      expect(
        find.text('A published post, seen at /post/501.'),
        findsOneWidget,
      );
    });
  });
}