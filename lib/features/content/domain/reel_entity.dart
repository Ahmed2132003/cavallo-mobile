/// Part P-044 scope: the clean domain representation of a single Reel
/// owned by the signed-in Business account — same convention as [Post]
/// in `post_entity.dart`.
///
/// Field list confirmed against the real backend
/// (`content.serializers.ReelSerializer`, Parts P-042/P-044 — read on
/// GitHub, not guessed):
/// `{id, business, caption, video, thumbnail, duration_seconds,
/// processing_status, status, rejection_reason, created_at,
/// updated_at}`.
library;

import 'moderation_status.dart';

/// Mirrors `content.models.Reel.processing_status` exactly
/// (`"uploaded"` / `"processing"` / `"ready"` / `"failed"`, Part
/// P-042). This is a SEPARATE, two-stage status from [ModerationStatus]
/// — a Reel must finish transcoding before it even enters moderation
/// review (P-042's `auto_enqueue_on_create = False` mechanism). The
/// Flutter UI must never conflate the two into one generic "loading"
/// state — P-044's own explicit Architecture Rule.
enum ReelProcessingStatus {
  uploaded,
  processing,
  ready,
  failed;

  /// Parses the backend's raw `processing_status` string. Throws
  /// [FormatException] on anything unrecognized, same convention as
  /// [ModerationStatus.fromWire].
  static ReelProcessingStatus fromWire(String value) {
    switch (value) {
      case 'uploaded':
        return ReelProcessingStatus.uploaded;
      case 'processing':
        return ReelProcessingStatus.processing;
      case 'ready':
        return ReelProcessingStatus.ready;
      case 'failed':
        return ReelProcessingStatus.failed;
      default:
        throw FormatException(
          'Unknown reel processing_status from backend: $value',
        );
    }
  }

  /// True while the Reel has not yet reached moderation review at all
  /// — a later step's `ContentListScreen` must show a distinct
  /// "Processing video..." indicator instead of any moderation badge
  /// for these two states, never "Under review".
  bool get isBeforeModeration =>
      this == ReelProcessingStatus.uploaded ||
      this == ReelProcessingStatus.processing;
}

class Reel {
  const Reel({
    required this.id,
    required this.businessId,
    required this.caption,
    required this.processingStatus,
    required this.status,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// Read-only. Same reasoning as `Post.businessId`.
  final int businessId;

  final String caption;

  /// `video` is a REQUIRED field on `content.models.Reel` — this app
  /// never constructs a [Reel] without one. Kept nullable purely for
  /// DTO-parsing symmetry with [thumbnailUrl]/[durationSeconds] below,
  /// same as every other `*Url` field in this project.
  final String? videoUrl;

  /// Read-only — set exclusively by `content.tasks.transcode_reel()`.
  /// `null` until [processingStatus] reaches
  /// [ReelProcessingStatus.ready].
  final String? thumbnailUrl;

  /// Read-only, same reasoning as [thumbnailUrl].
  final int? durationSeconds;

  final ReelProcessingStatus processingStatus;
  final ModerationStatus status;

  /// Non-null only when [status] is [ModerationStatus.rejected].
  final String? rejectionReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reel copyWith({
    int? id,
    int? businessId,
    String? caption,
    String? videoUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    ReelProcessingStatus? processingStatus,
    ModerationStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      caption: caption ?? this.caption,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      processingStatus: processingStatus ?? this.processingStatus,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reel &&
          other.id == id &&
          other.businessId == businessId &&
          other.caption == caption &&
          other.videoUrl == videoUrl &&
          other.thumbnailUrl == thumbnailUrl &&
          other.durationSeconds == durationSeconds &&
          other.processingStatus == processingStatus &&
          other.status == status &&
          other.rejectionReason == rejectionReason &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    caption,
    videoUrl,
    thumbnailUrl,
    durationSeconds,
    processingStatus,
    status,
    rejectionReason,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Reel(id: $id, processingStatus: $processingStatus, '
      'status: $status, businessId: $businessId)';
}