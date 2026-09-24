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
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/comment_entity.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-045 (STEP 8) scope: widget tests for `PostDetailScreen`
/// (`/post/:id`). Hand-rolled fake, same shape as every other fake
/// repository in this project (no mockito/mocktail): a mutable
/// result/error, an optional pending [Completer] for a deterministic
/// loading state, and a call counter so the non-numeric-id test can assert
/// zero network calls.
///
/// Part P-058 update: the screen now also contains the real action row, the
/// comments section and a Report menu, so every test also overrides the
/// social repository with a controllable fake (never the real Dio one).
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

  // Unused by this screen — implemented to satisfy the interface.
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
  FakeSocialInteractionRepository? social,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postPublicRepositoryProvider.overrideWithValue(repository),
        socialInteractionRepositoryProvider.overrideWithValue(
          social ?? FakeSocialInteractionRepository(),
        ),
      ],
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
      // No Report menu until the Post itself has loaded.
      expect(find.byTooltip('More options'), findsNothing);

      completer.complete(_post);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('PostDetailScreen — found', () {
    testWidgets(
      'shows the caption, the real action row and the comments section',
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
        expect(find.text('Comments'), findsOneWidget);
        expect(
          find.text('No comments yet. Be the first to comment.'),
          findsOneWidget,
        );
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
      'tapping Like shows the liked state immediately, before any response',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          postId: '501',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        // Close the gate only now, after the initial comment load finished.
        social.gate = Completer<void>();

        // Full-screen image at the default 800×600 test surface can push
        // the action row below the fold — ensureVisible scrolls it into
        // view before the tap.
        final likeButton = find.byTooltip('Like');
        await tester.ensureVisible(likeButton);
        await tester.pumpAndSettle();

        await tester.tap(likeButton);
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);

        social.gate!.complete();
        await tester.pumpAndSettle();

        expect(social.calls, contains('like:post:501'));
      },
    );

    testWidgets('shows the comments the API returned, as-is', (tester) async {
      final repository = _FakePostPublicRepository(result: _post);
      final social = FakeSocialInteractionRepository()
        ..commentsToReturn = [
          CommentEntity(
            id: 1,
            userId: 42,
            contentType: 'post',
            objectId: 501,
            text: 'Lovely colours!',
            isHidden: false,
            createdAt: DateTime.utc(2026, 9, 24, 10),
          ),
        ];

      await _pumpScreen(
        tester,
        postId: '501',
        repository: repository,
        social: social,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lovely colours!'), findsOneWidget);
      expect(find.text('User #42'), findsOneWidget);
      expect(social.calls, contains('listComments:post:501'));
    });

    testWidgets(
      'posting a comment adds it to the list and bumps the comment count',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          postId: '501',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();

        await tester.enterText(field, 'great post');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(social.calls, contains('createComment:post:501'));
        // Shown once, in the list (the input field was cleared).
        expect(find.text('great post'), findsOneWidget);
        // The comment counter next to the Comment icon.
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'the AppBar "..." menu appears once loaded and reports the Post',
      (tester) async {
        final repository = _FakePostPublicRepository(result: _post);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          postId: '501',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        // No comments loaded, so this is the only "..." menu on screen.
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Spam'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
        await tester.pumpAndSettle();

        expect(social.calls, contains('report:post:501:spam'));
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