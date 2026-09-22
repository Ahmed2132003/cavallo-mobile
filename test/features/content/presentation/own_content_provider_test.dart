import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/content/data/post_repository_impl.dart';
import 'package:social_commerce_app/features/content/data/reel_repository_impl.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/domain/moderation_status.dart';
import 'package:social_commerce_app/features/content/domain/post_entity.dart';
import 'package:social_commerce_app/features/content/domain/post_repository.dart';
import 'package:social_commerce_app/features/content/domain/reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_repository.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';

/// Part P-044 scope, STEP 9 — the "repository test for the unified
/// own-content list correctly tagging each item's type" this part's
/// own Testing section asks for. Exercises [OwnContentNotifier]
/// (`ownContentProvider`) against hand-rolled [PostRepository]/
/// [ReelRepository] fakes — this project doesn't use mockito/mocktail
/// anywhere (confirmed against `own_products_provider_test.dart`'s own
/// note before writing this file), so both fakes below mirror
/// `FakeProductRepository`'s exact shape (Part P-033) split across the
/// two content types this notifier merges.
class FakePostRepository implements PostRepository {
  FakePostRepository({List<Post> fetchResults = const [], Object? fetchError})
    : currentPosts = List.of(fetchResults),
      currentFetchError = fetchError;

  /// Mutable, same reasoning as `FakeProductRepository.currentProducts`
  /// (Part P-033) — [OwnContentNotifier.refresh] re-runs the same GET
  /// and must see whatever this fake now returns, not a frozen snapshot.
  List<Post> currentPosts;
  Object? currentFetchError;

  /// `null` (the default) appends a fixed successful [Post] to
  /// [currentPosts] and returns it — mirroring a real POST's persisted
  /// effect. Set to make [createPost] throw instead, simulating a
  /// backend rejection.
  Object? createPostError;

  int fetchOwnPostsCallCount = 0;
  int createPostCallCount = 0;

  static const _defaultCreatedPost = Post(
    id: 200,
    businessId: 1,
    caption: 'New post',
    status: ModerationStatus.pendingReview,
  );

  @override
  Future<PaginatedResponse<Post>> fetchOwnPosts() async {
    fetchOwnPostsCallCount++;
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
  Future<Post> createPost({required String caption, File? imageFile}) async {
    createPostCallCount++;
    if (createPostError != null) {
      throw createPostError!;
    }
    currentPosts = [...currentPosts, _defaultCreatedPost];
    return _defaultCreatedPost;
  }
}

class FakeReelRepository implements ReelRepository {
  FakeReelRepository({List<Reel> fetchResults = const [], Object? fetchError})
    : currentReels = List.of(fetchResults),
      currentFetchError = fetchError;

  List<Reel> currentReels;
  Object? currentFetchError;

  /// Same shape as `FakePostRepository.createPostError`.
  Object? createReelError;

  int fetchOwnReelsCallCount = 0;
  int createReelCallCount = 0;

  static const _defaultCreatedReel = Reel(
    id: 300,
    businessId: 1,
    caption: 'New reel',
    processingStatus: ReelProcessingStatus.uploaded,
    status: ModerationStatus.pendingReview,
  );

  @override
  Future<PaginatedResponse<Reel>> fetchOwnReels() async {
    fetchOwnReelsCallCount++;
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
  }) async {
    createReelCallCount++;
    if (createReelError != null) {
      throw createReelError!;
    }
    currentReels = [...currentReels, _defaultCreatedReel];
    return _defaultCreatedReel;
  }
}

final _olderPost = Post(
  id: 1,
  businessId: 1,
  caption: 'Older post',
  status: ModerationStatus.published,
  createdAt: DateTime.utc(2026, 1, 1),
);

final _newerReel = Reel(
  id: 2,
  businessId: 1,
  caption: 'Newer reel',
  processingStatus: ReelProcessingStatus.ready,
  status: ModerationStatus.pendingReview,
  createdAt: DateTime.utc(2026, 6, 1),
);

final _rejectedPost = Post(
  id: 3,
  businessId: 1,
  caption: 'Rejected post',
  status: ModerationStatus.rejected,
  rejectionReason: 'Blurry image',
  createdAt: DateTime.utc(2026, 3, 1),
);

ProviderContainer _makeContainer({
  FakePostRepository? postRepo,
  FakeReelRepository? reelRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(
        postRepo ?? FakePostRepository(),
      ),
      reelRepositoryProvider.overrideWithValue(
        reelRepo ?? FakeReelRepository(),
      ),
    ],
  );
  return container;
}

void main() {
  group('OwnContentNotifier.build — merging and type-tagging', () {
    test(
      'merges Posts and Reels into one list, each tagged with its own '
      'type, sorted newest-first by createdAt',
      () async {
        final postRepo = FakePostRepository(
          fetchResults: [_olderPost, _rejectedPost],
        );
        final reelRepo = FakeReelRepository(fetchResults: [_newerReel]);
        final container = _makeContainer(
          postRepo: postRepo,
          reelRepo: reelRepo,
        );
        addTearDown(container.dispose);

        final result = await container.read(ownContentProvider.future);

        expect(result, hasLength(3));
        // Newest first: _newerReel (Jun) > _rejectedPost (Mar) >
        // _olderPost (Jan).
        expect(result[0], isA<ReelContentItem>());
        expect(result[0].id, _newerReel.id);
        expect(result[0].type, 'reel');
        expect(result[1], isA<PostContentItem>());
        expect(result[1].id, _rejectedPost.id);
        expect(result[1].type, 'post');
        expect(result[2], isA<PostContentItem>());
        expect(result[2].id, _olderPost.id);
        expect(result[2].type, 'post');
      },
    );

    test(
      'a rejected item exposes the real rejectionReason through the '
      'unified ContentItem, not just the underlying Post',
      () async {
        final postRepo = FakePostRepository(fetchResults: [_rejectedPost]);
        final container = _makeContainer(postRepo: postRepo);
        addTearDown(container.dispose);

        final result = await container.read(ownContentProvider.future);

        expect(result.single.moderationStatus, ModerationStatus.rejected);
        expect(result.single.rejectionReason, 'Blurry image');
      },
    );

    test(
      'resolves to AsyncData([]) — not AsyncError — for a business with '
      'no posts or reels yet',
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        final result = await container.read(ownContentProvider.future);

        expect(result, isEmpty);
        expect(container.read(ownContentProvider).hasError, isFalse);
      },
    );

    test(
      'when the Reel fetch fails, the whole merge fails — no partial '
      '"Posts loaded, Reels silently missing" state',
      () async {
        final postRepo = FakePostRepository(fetchResults: [_olderPost]);
        final reelRepo = FakeReelRepository(
          fetchError: Exception('reels endpoint down'),
        );
        final container = _makeContainer(
          postRepo: postRepo,
          reelRepo: reelRepo,
        );
        addTearDown(container.dispose);

        container.listen(
          ownContentProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(ownContentProvider);
        expect(state.hasError, isTrue);
        expect(state.hasValue, isFalse);
      },
    );

    test(
      'when the Post fetch fails, the whole merge fails the same way',
      () async {
        final postRepo = FakePostRepository(
          fetchError: Exception('posts endpoint down'),
        );
        final reelRepo = FakeReelRepository(fetchResults: [_newerReel]);
        final container = _makeContainer(
          postRepo: postRepo,
          reelRepo: reelRepo,
        );
        addTearDown(container.dispose);

        container.listen(
          ownContentProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        await Future<void>.delayed(Duration.zero);

        final state = container.read(ownContentProvider);
        expect(state.hasError, isTrue);
      },
    );
  });

  group('sortContentItems', () {
    test('an item with a null createdAt sorts last, never crashes', () {
      const noDate = PostContentItem(
        Post(
          id: 99,
          businessId: 1,
          caption: 'No date',
          status: ModerationStatus.pendingReview,
        ),
      );
      final withDate = PostContentItem(_olderPost);

      final sorted = sortContentItems([noDate, withDate]);

      expect(sorted.first, withDate);
      expect(sorted.last, noDate);
    });
  });

  group('OwnContentNotifier.createPost', () {
    test(
      'on success, forwards to PostRepository and refreshes the merged '
      'list to include the created Post',
      () async {
        final postRepo = FakePostRepository(fetchResults: [_olderPost]);
        final reelRepo = FakeReelRepository(fetchResults: [_newerReel]);
        final container = _makeContainer(
          postRepo: postRepo,
          reelRepo: reelRepo,
        );
        addTearDown(container.dispose);
        await container.read(ownContentProvider.future);

        await container
            .read(ownContentProvider.notifier)
            .createPost(caption: 'New post');

        expect(postRepo.createPostCallCount, 1);
        final state = container.read(ownContentProvider);
        expect(state.value, hasLength(3));
        expect(
          state.value!.any((item) => item.type == 'post' && item.id == 200),
          isTrue,
        );
      },
    );

    test(
      'on failure, rethrows to the caller and leaves state untouched',
      () async {
        final failure = Exception('caption too long');
        final postRepo = FakePostRepository(fetchResults: [_olderPost])
          ..createPostError = failure;
        final container = _makeContainer(postRepo: postRepo);
        addTearDown(container.dispose);
        await container.read(ownContentProvider.future);

        await expectLater(
          container
              .read(ownContentProvider.notifier)
              .createPost(caption: 'New post'),
          throwsA(failure),
        );

        final state = container.read(ownContentProvider);
        expect(state.value, hasLength(1));
        expect(state.value!.single.id, _olderPost.id);
      },
    );
  });

  group('OwnContentNotifier.createReel', () {
    test(
      'on success, forwards to ReelRepository and refreshes the merged '
      'list to include the created Reel',
      () async {
        final postRepo = FakePostRepository(fetchResults: [_olderPost]);
        final reelRepo = FakeReelRepository();
        final container = _makeContainer(
          postRepo: postRepo,
          reelRepo: reelRepo,
        );
        addTearDown(container.dispose);
        await container.read(ownContentProvider.future);

        await container
            .read(ownContentProvider.notifier)
            .createReel(caption: 'New reel', videoFile: File('dummy.mp4'));

        expect(reelRepo.createReelCallCount, 1);
        final state = container.read(ownContentProvider);
        expect(state.value, hasLength(2));
        expect(
          state.value!.any((item) => item.type == 'reel' && item.id == 300),
          isTrue,
        );
      },
    );

    test(
      'on failure, rethrows to the caller and leaves state untouched',
      () async {
        final failure = Exception('unsupported video format');
        final reelRepo = FakeReelRepository(fetchResults: [_newerReel])
          ..createReelError = failure;
        final container = _makeContainer(reelRepo: reelRepo);
        addTearDown(container.dispose);
        await container.read(ownContentProvider.future);

        await expectLater(
          container
              .read(ownContentProvider.notifier)
              .createReel(caption: 'New reel', videoFile: File('dummy.mp4')),
          throwsA(failure),
        );

        final state = container.read(ownContentProvider);
        expect(state.value, hasLength(1));
        expect(state.value!.single.id, _newerReel.id);
      },
    );
  });

  group('OwnContentNotifier.refresh', () {
    test('a failed refresh becomes AsyncError without throwing', () async {
      final postRepo = FakePostRepository(fetchResults: [_olderPost]);
      final container = _makeContainer(postRepo: postRepo);
      addTearDown(container.dispose);
      await container.read(ownContentProvider.future);

      postRepo.currentFetchError = Exception('network down');

      // Deliberately not awaited via expectLater/throwsA — refresh()
      // must NOT throw at all, unlike createPost/createReel above.
      await container.read(ownContentProvider.notifier).refresh();

      final state = container.read(ownContentProvider);
      expect(state.hasError, isTrue);
    });
  });
}