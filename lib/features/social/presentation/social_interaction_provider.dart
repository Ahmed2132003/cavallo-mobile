import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/social_interaction_repository_impl.dart';
import '../domain/social_interaction_state.dart';
import 'content_interaction_key.dart';

/// Part P-058: optimistic-update state layer for Like / Save / Share /
/// Follow.
///
/// Two separate families:
/// - [contentInteractionProvider] keyed by (contentType, objectId):
///   Like / Save / share-count / comment-count for ONE Post or Reel.
/// - [businessFollowProvider] keyed by businessId: Follow state and
///   followers count for ONE business, shared by every card and the
///   business profile screen, so they can never disagree.
///
/// Optimistic-update contract:
/// 1. Flip the local state immediately, before any await.
/// 2. Call the repository.
/// 3. On success, reconcile the boolean with the server's returned value.
/// 4. On failure, restore the saved `previous` snapshot and rethrow so the
///    UI can show a SnackBar.
class ContentInteractionNotifier extends Notifier<SocialInteractionState> {
  ContentInteractionNotifier(this.key);

  final ContentInteractionKey key;

  @override
  SocialInteractionState build() => const SocialInteractionState();

  /// One-time seed from counts the caller already has. Do not call after a
  /// toggle has run, because it replaces the whole state.
  void seed({
    required bool isLiked,
    required bool isSaved,
    required int likesCount,
    required int commentsCount,
    required int sharesCount,
  }) {
    state = SocialInteractionState(
      isLiked: isLiked,
      isSaved: isSaved,
      likesCount: likesCount,
      commentsCount: commentsCount,
      sharesCount: sharesCount,
    );
  }

  Future<void> toggleLike() async {
    final wasLiked = state.isLiked;
    final previous = state;
    state = state.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? state.likesCount - 1 : state.likesCount + 1,
    );

    final repo = ref.read(socialInteractionRepositoryProvider);
    try {
      final serverLiked = wasLiked
          ? await repo.unlikeContent(
              contentType: key.contentType,
              objectId: key.objectId,
            )
          : await repo.likeContent(
              contentType: key.contentType,
              objectId: key.objectId,
            );
      if (serverLiked != state.isLiked) {
        state = state.copyWith(isLiked: serverLiked);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> toggleSave() async {
    final wasSaved = state.isSaved;
    final previous = state;
    state = state.copyWith(isSaved: !wasSaved);

    final repo = ref.read(socialInteractionRepositoryProvider);
    try {
      final serverSaved = wasSaved
          ? await repo.unsaveContent(
              contentType: key.contentType,
              objectId: key.objectId,
            )
          : await repo.saveContent(
              contentType: key.contentType,
              objectId: key.objectId,
            );
      if (serverSaved != state.isSaved) {
        state = state.copyWith(isSaved: serverSaved);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Share is deliberately non-idempotent on the backend (P-056): no local
  /// dedupe or debounce here.
  Future<void> share() async {
    final previous = state;
    state = state.copyWith(sharesCount: state.sharesCount + 1);
    try {
      await ref
          .read(socialInteractionRepositoryProvider)
          .shareContent(contentType: key.contentType, objectId: key.objectId);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Called by the comment input widget after a successful createComment.
  void recordNewComment() {
    state = state.copyWith(commentsCount: state.commentsCount + 1);
  }
}

/// Part BUGFIX-058: `.autoDispose` — combined with the seed-from-real-data
/// fix in `ContentActionRow`, this closes the cross-account state-leakage
/// bug from two directions. `.autoDispose` means a key with no active
/// watcher (e.g. a card scrolled out of the feed and disposed) drops its
/// state entirely rather than persisting in memory for the app process's
/// lifetime; `sessionProvider`'s `logout()` (`session_provider.dart`)
/// additionally calls `ref.invalidate(contentInteractionProvider)` — with
/// no key argument, this invalidates every currently-alive instance of
/// this family at once — so even a still-mounted widget's interaction
/// state is force-cleared the moment a session ends, not just eventually
/// reclaimed once nothing is watching it.
final contentInteractionProvider = NotifierProvider.autoDispose.family<
  ContentInteractionNotifier,
  SocialInteractionState,
  ContentInteractionKey
>((key) => ContentInteractionNotifier(key));

class BusinessFollowNotifier extends Notifier<SocialInteractionState> {
  BusinessFollowNotifier(this.businessId);

  final int businessId;

  @override
  SocialInteractionState build() => const SocialInteractionState();

  void seed({required bool isFollowing, required int followersCount}) {
    state = SocialInteractionState(
      isFollowing: isFollowing,
      followersCount: followersCount,
    );
  }

  Future<void> toggleFollow() async {
    final wasFollowing = state.isFollowing;
    final previous = state;
    state = state.copyWith(
      isFollowing: !wasFollowing,
      followersCount: wasFollowing
          ? state.followersCount - 1
          : state.followersCount + 1,
    );

    final repo = ref.read(socialInteractionRepositoryProvider);
    try {
      final serverFollowing = wasFollowing
          ? await repo.unfollowBusiness(businessId)
          : await repo.followBusiness(businessId);
      if (serverFollowing != state.isFollowing) {
        state = state.copyWith(isFollowing: serverFollowing);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

/// Part BUGFIX-058: `.autoDispose`, same reasoning as
/// [contentInteractionProvider] above — paired with
/// `ref.invalidate(businessFollowProvider)` in `SessionNotifier.logout()`.
final businessFollowProvider = NotifierProvider.autoDispose.family<
  BusinessFollowNotifier,
  SocialInteractionState,
  int
>((businessId) => BusinessFollowNotifier(businessId));