/// Part P-058 scope: domain representation of a `social.Comment` row,
/// mirroring `CommentSerializer`'s exact field set
/// (`social/serializers.py`, Part P-055) — confirmed against the real
/// backend source, not assumed from the master plan.
///
/// KNOWN GAP (flagged, not silently worked around): the backend's
/// `user` field is a bare integer pk, not an expanded
/// {id, username, avatar} object — there is no author display name or
/// avatar available anywhere in this payload. `comment_list_widget.dart`
/// (a later step) can only render `User #<id>` until a future backend
/// part adds an author object. This mirrors the exact gap P-055's own
/// "Remaining work" section already flagged for P-058.
library;

class CommentEntity {
  const CommentEntity({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.objectId,
    required this.text,
    required this.isHidden,
    required this.createdAt,
  });

  final int id;
  final int userId;

  /// Lowercase wire value, e.g. `"post"` / `"reel"` — matches
  /// `SocialInteractionRepository`'s own `contentType` parameters
  /// verbatim, no local re-mapping.
  final String contentType;
  final int objectId;
  final String text;

  /// `true` only when this comment has crossed
  /// `COMMENT_AUTO_HIDE_THRESHOLD` (Part P-055) — the backend only
  /// ever returns a hidden comment to its own author or a moderator
  /// (`CommentListView`'s visibility rule); every other viewer never
  /// receives it in the list at all. So `isHidden: true` here always
  /// means "shown to you specifically because you're allowed to see
  /// your own/a moderated hidden comment," never a generic flag.
  final bool isHidden;

  final DateTime createdAt;

  CommentEntity copyWith({
    int? id,
    int? userId,
    String? contentType,
    int? objectId,
    String? text,
    bool? isHidden,
    DateTime? createdAt,
  }) {
    return CommentEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contentType: contentType ?? this.contentType,
      objectId: objectId ?? this.objectId,
      text: text ?? this.text,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommentEntity &&
          other.id == id &&
          other.userId == userId &&
          other.contentType == contentType &&
          other.objectId == objectId &&
          other.text == text &&
          other.isHidden == isHidden &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    contentType,
    objectId,
    text,
    isHidden,
    createdAt,
  );

  @override
  String toString() =>
      'CommentEntity(id: $id, userId: $userId, isHidden: $isHidden)';
}