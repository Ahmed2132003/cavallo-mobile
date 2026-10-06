import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/domain/saved_repository.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_repository.dart';

/// Part P-113 (STEP 3B): shared fakes of the Saved provider and screen tests.

const User savedTestCustomer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User savedTestOtherCustomer = User(
  id: 2,
  email: 'other@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

SavedItem savedTestItem(
  int id,
  SavedContentType type, {
  int? objectId,
  String? text,
  bool unavailable = false,
}) {
  return SavedItem(
    id: id,
    contentType: type,
    objectId: objectId ?? id * 10,
    previewText: unavailable ? null : (text ?? 'Item $id'),
  );
}

/// Pages are addressed by index: the first request (no cursor) returns
/// `pages[0]`, a request with cursor `'1'` returns `pages[1]`, and so on.
/// Every page but the last carries `next` = the index of the following page.
class FakeSavedRepository implements SavedRepository {
  FakeSavedRepository(this.pages);

  final List<List<SavedItem>> pages;
  final List<String?> requestedCursors = <String?>[];

  /// When set, the next call throws this and clears it.
  Object? failNext;

  /// When set, every call with exactly this cursor throws (until cleared).
  String? failOnCursor;

  @override
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor}) async {
    requestedCursors.add(cursor);
    if (failOnCursor != null && cursor == failOnCursor) {
      throw StateError('page $cursor failed');
    }
    final Object? failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final int index = cursor == null ? 0 : int.parse(cursor);
    return PaginatedResponse<SavedItem>(
      results: pages.isEmpty ? <SavedItem>[] : pages[index],
      next: index + 1 < pages.length ? '${index + 1}' : null,
      previous: null,
    );
  }
}

/// Only [unsaveContent] is used by the Saved screen; everything else of the
/// interface would throw if called.
class FakeSocialInteractionRepository implements SocialInteractionRepository {
  final List<({String contentType, int objectId})> unsaved =
      <({String contentType, int objectId})>[];

  /// When set, [unsaveContent] waits for it before returning.
  Completer<void>? hold;

  bool fail = false;

  @override
  Future<bool> unsaveContent({
    required String contentType,
    required int objectId,
  }) async {
    unsaved.add((contentType: contentType, objectId: objectId));
    if (hold != null) {
      await hold!.future;
    }
    if (fail) {
      throw StateError('unsave failed');
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSavedSession extends SessionNotifier {
  FakeSavedSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;

  void signInAs(User user) {
    state = AsyncValue<User?>.data(user);
  }
}
