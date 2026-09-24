/// Part P-058 scope: the per-item interaction state tracked by
/// `socialInteractionProvider` (Step 3). One instance per content
/// item (Post/Reel) OR per business (Follow) — the provider's family
/// key decides which fields are meaningful for a given instance (a
/// Post/Reel key never mutates `isFollowing`/`followersCount`; a
/// Business key never mutates `isLiked`/`isSaved`/`likesCount`/
/// `sharesCount`). Kept as one flat class rather than three separate
/// state types because PostCard/ReelCard render like+save+share
/// together and a single read is simpler than three provider watches
/// per card.
library;

class SocialInteractionState {
  const SocialInteractionState({
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowing = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.followersCount = 0,
  });

  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int followersCount;

  SocialInteractionState copyWith({
    bool? isLiked,
    bool? isSaved,
    bool? isFollowing,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? followersCount,
  }) {
    return SocialInteractionState(
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowing: isFollowing ?? this.isFollowing,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      followersCount: followersCount ?? this.followersCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SocialInteractionState &&
          other.isLiked == isLiked &&
          other.isSaved == isSaved &&
          other.isFollowing == isFollowing &&
          other.likesCount == likesCount &&
          other.commentsCount == commentsCount &&
          other.sharesCount == sharesCount &&
          other.followersCount == followersCount);

  @override
  int get hashCode => Object.hash(
    isLiked,
    isSaved,
    isFollowing,
    likesCount,
    commentsCount,
    sharesCount,
    followersCount,
  );

  @override
  String toString() =>
      'SocialInteractionState(isLiked: $isLiked, isSaved: $isSaved, '
      'isFollowing: $isFollowing, likesCount: $likesCount, '
      'commentsCount: $commentsCount, sharesCount: $sharesCount, '
      'followersCount: $followersCount)';
}