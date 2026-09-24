import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/social_interaction_repository_impl.dart';
import '../domain/social_interaction_state.dart';
import 'content_interaction_key.dart';

/// Part P-058 scope: the optimistic-update state layer for Like/Save/
/// Follow — Share and Report are fire-and-forget (no lasting local
/// state to reconcile beyond a locally-bumped share count, see
/// [ContentInteractionNotifier.share]), and Comment has its own
/// list/input widgets (a later step) that call
/// `socialInteractionRepositoryProvider` directly and report new
/// comments back here via [ContentInteractionNotifier.recordNewComment].
///
/// ## Two separate families — see this part's STEP 3 rationale
///
/// [contentInteractionProvider] (keyed by [ContentInteractionKey] —
/// `contentType` + `objectId`) tracks Like/Save/share-count/comment-
/// count for ONE Post or Reel. [businessFollowProvider] (keyed by a
/// plain `int businessId`) tracks Follow/followerCount for ONE
/// business, shared by every card and the business-profile screen
/// that reference the same business — deliberately NOT folded into
/// the content-keyed family, so two PostCards from the same business
/// can never show two different Follow states.
///
/// ## Optimistic-update contract (both notifiers follow this exact
/// shape)
///
/// 1. Flip the local boolean AND adjust the local count immediately,
///    synchronously, before any `await` — the UI updates on the very
///    next frame, not after a round trip.
/// 2. Fire the real repository call.
/// 3. On success: reconcile the boolean with the server's OWN
///    returned value (belt-and-suspenders — the two should always
///    agree, since every P-052/P-053/P-054 toggle is idempotent, but
///    the server is still the source of truth). The COUNT is never
///    reconciled from the server here, because none of Like/Save's
///    responses include one (`{"liked": bool}` / `{"saved": bool}`
///    only — confirmed against the real `social/views.py`) — the
///    locally-adjusted count is kept as-is.
/// 4. On failure: revert `state` to exactly what it was before step 1
///    (a saved `previous` snapshot, not a hand-unwound diff), then
///    rethrow so the caller (a card's `onPressed`) can show a
///    SnackBar. Never leave `state` in the optimistic-but-unconfirmed
///    shape on failure — see this part's own Architecture Rule
///    ("never let an optimistic UI update silently diverge from
///    server truth indefinitely").
class ContentInteractionNotifier
    extends Notifier<SocialInteractionState> {
  ContentInteractionNotifier(this.key);

  final ContentInteractionKey key;

  @override
  SocialInteractionState build() => const SocialInteractionState();

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

  void recordNewComment() {
    state = state.copyWith(commentsCount: state.commentsCount + 1);
  }
}

final contentInteractionProvider = NotifierProvider.family
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

final businessFollowProvider =
    NotifierProvider.family
      BusinessFollowNotifier,
      SocialInteractionState,
      int
    >((businessId) => BusinessFollowNotifier(businessId));