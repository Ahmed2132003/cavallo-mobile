import 'dart:async';

import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/social/domain/comment_entity.dart';
import 'package:social_commerce_app/features/social/domain/report_reason.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_repository.dart';

/// Hand-rolled fake (same convention as the project's other test fakes) that
/// can be made to succeed, fail, or pause on demand:
///
/// - [gate]: while non-null, every call waits on it. Lets a test look at the
///   UI/provider state BEFORE the "server" answers (the optimistic state).
/// - [errorToThrow]: when non-null, every call throws it (after the gate).
/// - [likedOverride]: makes the "server" disagree with the optimistic like.
class FakeSocialInteractionRepository implements SocialInteractionRepository {
  Completer<void>? gate;
  Object? errorToThrow;
  bool? likedOverride;
  List<CommentEntity> commentsToReturn = [];

  /// Every call in order, e.g. `like:post:7`, `follow:5`.
  final List<String> calls = [];

  Future<void> _pass(String call) async {
    calls.add(call);
    final pending = gate;
    if (pending != null) await pending.future;
    final error = errorToThrow;
    if (error != null) throw error;
  }

  @override
  Future<bool> followBusiness(int businessId) async {
    await _pass('follow:$businessId');
    return true;
  }

  @override
  Future<bool> unfollowBusiness(int businessId) async {
    await _pass('unfollow:$businessId');
    return false;
  }

  @override
  Future<bool> likeContent({
    required String contentType,
    required int objectId,
  }) async {
    await _pass('like:$contentType:$objectId');
    return likedOverride ?? true;
  }

  @override
  Future<bool> unlikeContent({
    required String contentType,
    required int objectId,
  }) async {
    await _pass('unlike:$contentType:$objectId');
    return likedOverride ?? false;
  }

  @override
  Future<bool> saveContent({
    required String contentType,
    required int objectId,
  }) async {
    await _pass('save:$contentType:$objectId');
    return true;
  }

  @override
  Future<bool> unsaveContent({
    required String contentType,
    required int objectId,
  }) async {
    await _pass('unsave:$contentType:$objectId');
    return false;
  }

  @override
  Future<CommentEntity> createComment({
    required String contentType,
    required int objectId,
    required String text,
  }) async {
    await _pass('createComment:$contentType:$objectId');
    return CommentEntity(
      id: 99,
      userId: 1,
      contentType: contentType,
      objectId: objectId,
      text: text,
      isHidden: false,
      createdAt: DateTime.utc(2026, 9, 24, 12),
    );
  }

  @override
  Future<PaginatedResponse<CommentEntity>> listComments({
    required String contentType,
    required int objectId,
    String? pageUrl,
  }) async {
    await _pass('listComments:$contentType:$objectId');
    return PaginatedResponse<CommentEntity>(
      results: List<CommentEntity>.of(commentsToReturn),
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> shareContent({
    required String contentType,
    required int objectId,
  }) async {
    await _pass('share:$contentType:$objectId');
  }

  @override
  Future<void> reportTarget({
    required String contentType,
    required int objectId,
    required ReportReason reason,
    String? details,
  }) async {
    await _pass('report:$contentType:$objectId:${reason.wireValue}');
  }
}