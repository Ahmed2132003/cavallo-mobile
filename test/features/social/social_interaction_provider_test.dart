import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_state.dart';
import 'package:social_commerce_app/features/social/presentation/content_interaction_key.dart';
import 'package:social_commerce_app/features/social/presentation/social_interaction_provider.dart';

import 'fake_social_interaction_repository.dart';

const ContentInteractionKey postKey = (contentType: 'post', objectId: 7);

ProviderContainer _container(FakeSocialInteractionRepository fake) {
  final container = ProviderContainer(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('contentInteractionProvider: Like', () {
    test('updates state immediately, before the server answers', () async {
      final fake = FakeSocialInteractionRepository()..gate = Completer<void>();
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      final future = notifier.toggleLike();

      // No await yet: the "server" has not answered.
      var state = container.read(contentInteractionProvider(postKey));
      expect(state.isLiked, isTrue);
      expect(state.likesCount, 1);

      fake.gate!.complete();
      await future;

      state = container.read(contentInteractionProvider(postKey));
      expect(state.isLiked, isTrue);
      expect(state.likesCount, 1);
      expect(fake.calls, ['like:post:7']);
    });

    test('reverts to the exact previous state and rethrows on failure', () async {
      final fake = FakeSocialInteractionRepository()
        ..errorToThrow = Exception('boom');
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      final future = notifier.toggleLike();
      expect(
        container.read(contentInteractionProvider(postKey)).isLiked,
        isTrue,
      );

      await expectLater(future, throwsException);

      expect(
        container.read(contentInteractionProvider(postKey)),
        const SocialInteractionState(),
      );
    });

    test('unlikes an already-liked item and lowers the count', () async {
      final fake = FakeSocialInteractionRepository();
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );
      notifier.seed(
        isLiked: true,
        isSaved: false,
        likesCount: 3,
        commentsCount: 0,
        sharesCount: 0,
      );

      await notifier.toggleLike();

      final state = container.read(contentInteractionProvider(postKey));
      expect(state.isLiked, isFalse);
      expect(state.likesCount, 2);
      expect(fake.calls, ['unlike:post:7']);
    });

    test('reconciles the boolean with the server when it disagrees', () async {
      final fake = FakeSocialInteractionRepository()..likedOverride = false;
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      await notifier.toggleLike();

      expect(
        container.read(contentInteractionProvider(postKey)).isLiked,
        isFalse,
      );
    });
  });

  group('contentInteractionProvider: Save, Share, Comment', () {
    test('toggleSave flips immediately and calls save then unsave', () async {
      final fake = FakeSocialInteractionRepository()..gate = Completer<void>();
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      final future = notifier.toggleSave();
      expect(
        container.read(contentInteractionProvider(postKey)).isSaved,
        isTrue,
      );
      fake.gate!.complete();
      await future;

      await notifier.toggleSave();
      expect(
        container.read(contentInteractionProvider(postKey)).isSaved,
        isFalse,
      );
      expect(fake.calls, ['save:post:7', 'unsave:post:7']);
    });

    test('toggleSave reverts on failure', () async {
      final fake = FakeSocialInteractionRepository()
        ..errorToThrow = Exception('boom');
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      await expectLater(notifier.toggleSave(), throwsException);

      expect(
        container.read(contentInteractionProvider(postKey)).isSaved,
        isFalse,
      );
    });

    test('share is never deduplicated: two shares are two calls', () async {
      final fake = FakeSocialInteractionRepository();
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      await notifier.share();
      await notifier.share();

      expect(
        container.read(contentInteractionProvider(postKey)).sharesCount,
        2,
      );
      expect(fake.calls, ['share:post:7', 'share:post:7']);
    });

    test('share reverts its local count on failure', () async {
      final fake = FakeSocialInteractionRepository()
        ..errorToThrow = Exception('boom');
      final container = _container(fake);
      final notifier = container.read(
        contentInteractionProvider(postKey).notifier,
      );

      await expectLater(notifier.share(), throwsException);

      expect(
        container.read(contentInteractionProvider(postKey)).sharesCount,
        0,
      );
    });

    test('recordNewComment bumps the comments count', () {
      final container = _container(FakeSocialInteractionRepository());
      container.read(contentInteractionProvider(postKey).notifier)
          .recordNewComment();

      expect(
        container.read(contentInteractionProvider(postKey)).commentsCount,
        1,
      );
    });
  });

  group('businessFollowProvider', () {
    test('follow updates state immediately, before the server answers', () async {
      final fake = FakeSocialInteractionRepository()..gate = Completer<void>();
      final container = _container(fake);
      final notifier = container.read(businessFollowProvider(5).notifier);
      notifier.seed(isFollowing: false, followersCount: 10);

      final future = notifier.toggleFollow();

      var state = container.read(businessFollowProvider(5));
      expect(state.isFollowing, isTrue);
      expect(state.followersCount, 11);

      fake.gate!.complete();
      await future;

      state = container.read(businessFollowProvider(5));
      expect(state.isFollowing, isTrue);
      expect(state.followersCount, 11);
      expect(fake.calls, ['follow:5']);
    });

    test('follow reverts state and count on failure', () async {
      final fake = FakeSocialInteractionRepository()
        ..errorToThrow = Exception('boom');
      final container = _container(fake);
      final notifier = container.read(businessFollowProvider(5).notifier);
      notifier.seed(isFollowing: false, followersCount: 10);

      final future = notifier.toggleFollow();
      expect(container.read(businessFollowProvider(5)).followersCount, 11);

      await expectLater(future, throwsException);

      final state = container.read(businessFollowProvider(5));
      expect(state.isFollowing, isFalse);
      expect(state.followersCount, 10);
    });

    test('unfollow lowers the count', () async {
      final fake = FakeSocialInteractionRepository();
      final container = _container(fake);
      final notifier = container.read(businessFollowProvider(5).notifier);
      notifier.seed(isFollowing: true, followersCount: 10);

      await notifier.toggleFollow();

      final state = container.read(businessFollowProvider(5));
      expect(state.isFollowing, isFalse);
      expect(state.followersCount, 9);
      expect(fake.calls, ['unfollow:5']);
    });

    test('same business id shares one state; other ids are independent', () async {
      final fake = FakeSocialInteractionRepository();
      final container = _container(fake);

      await container.read(businessFollowProvider(5).notifier).toggleFollow();

      expect(container.read(businessFollowProvider(5)).isFollowing, isTrue);
      expect(container.read(businessFollowProvider(6)).isFollowing, isFalse);
    });
  });
}