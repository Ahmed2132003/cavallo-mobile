import '../../domain/comment_entity.dart';

/// Part P-058 scope: parses `CommentSerializer`'s exact wire shape
/// (`social/serializers.py`, confirmed against real backend source):
/// `{id, user, content_type, object_id, text, is_hidden, created_at}`.
class CommentResponseDto {
  const CommentResponseDto({
    required this.id,
    required this.user,
    required this.contentType,
    required this.objectId,
    required this.text,
    required this.isHidden,
    required this.createdAt,
  });

  final int id;
  final int user;
  final String contentType;
  final int objectId;
  final String text;
  final bool isHidden;
  final DateTime createdAt;

  factory CommentResponseDto.fromJson(Map<String, dynamic> json) {
    return CommentResponseDto(
      id: json['id'] as int,
      user: json['user'] as int,
      contentType: json['content_type'] as String,
      objectId: json['object_id'] as int,
      text: json['text'] as String,
      isHidden: json['is_hidden'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  CommentEntity toEntity() => CommentEntity(
    id: id,
    userId: user,
    contentType: contentType,
    objectId: objectId,
    text: text,
    isHidden: isHidden,
    createdAt: createdAt,
  );
}