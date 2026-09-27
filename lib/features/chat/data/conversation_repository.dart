import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

/// Part P-074 STEP 2 — REST data layer for the Conversation List screen,
/// and for opening a conversation (starting a new one, or fetching an
/// existing one's message history).
///
/// ### Error-handling convention (flagged, not silently decided)
/// No other feature's `data/` layer existed yet in this codebase to copy
/// a convention from — this is the first repository. `dio_client.dart`'s
/// own doc comment says "every feature's data layer should catch
/// [DioException] ... and read `.error`" — read literally, that puts the
/// catch here, not in the presentation layer. So every method below does
/// exactly that: catches `DioException`, pulls out the already-typed
/// `ApiFailure` (`err.error`), and rethrows *that* — never a raw
/// `DioException` — so every caller of this repository only ever needs
/// to catch `ApiFailure`. Revisit this file if a later part introduces a
/// different shared convention (e.g. a `Result<T>` return type).
///
/// ### Endpoint paths (verified against `chat/views.py`'s own docstrings,
/// `config/urls.py` was not available to double-check the mount prefix)
/// All four routes below are stated explicitly, more than once, in
/// `chat/views.py`'s class docstrings as living under
/// `/api/v1/conversations/` — that is the basis for `_basePath`.
class ConversationRepository {
  ConversationRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/api/v1/conversations/';

  /// GET /api/v1/conversations/ — the Conversation List screen's primary
  /// fetch (`ConversationListView`).
  ///
  /// Assumed paginated (`{results, next, previous}`, parsed via the
  /// shared `PaginatedResponse`) because `ConversationListView` sets no
  /// `pagination_class` of its own and therefore falls back to whatever
  /// `REST_FRAMEWORK.DEFAULT_PAGINATION_CLASS` is configured project-wide
  /// — `config/settings.py` was not available to confirm this directly.
  /// **Flagging this explicitly**: if that default turns out to be unset
  /// (a plain, non-paginated array, the same shape
  /// `MessageFetchSinceView` returns), this method will fail loudly at
  /// `PaginatedResponse.fromJson`'s `json['results']` cast rather than
  /// silently — that failure is the signal to change this method's
  /// return type to `Future<List<Conversation>>` instead.
  ///
  /// [cursor] is an opaque full URL from a previous
  /// `PaginatedResponse.next` — pass it to fetch the next page. Omit (or
  /// pass null) for the first page.
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        cursor ?? _basePath,
      );
      return PaginatedResponse.fromJson(
        response.data!,
        Conversation.fromJson,
      );
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// POST /api/v1/conversations/start/ — resolves to an existing
  /// conversation with [recipientId] if one exists, or creates a new one
  /// (`ConversationStartView`, P-066).
  ///
  /// Returns only the new/existing conversation's id, not a full
  /// `Conversation` — flagged deliberately: `ConversationStartView`
  /// responds with the plain `ConversationSerializer` shape (`{id,
  /// created_at, updated_at, participant_ids}`), not
  /// `ConversationListSerializer`'s richer shape, so there is no
  /// `other_participant`/`last_message`/`unread_count` to build a full
  /// `Conversation` from here. Every known caller only needs the id to
  /// navigate to `/chat/:id`; the thread screen fetches its own detail.
  Future<int> startConversation({required int recipientId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_basePath}start/',
        data: {'recipient_id': recipientId},
      );
      return response.data!['id'] as int;
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET `/api/v1/conversations/<conversationId>/messages/` — the initial,
  /// paginated message-history fetch for opening a thread
  /// (`MessageHistoryView`, no `since` query param). Newest-first on the
  /// wire (`StandardCursorPagination`'s own convention) — per that
  /// view's own doc comment, the caller (the message thread screen,
  /// P-074's later steps) is expected to reverse each page's items
  /// before appending them to the top of the thread, since
  /// oldest-to-newest is the on-screen order, not the wire order. This
  /// repository does not reverse it — that is a presentation-layer
  /// concern, not a data-layer one.
  ///
  /// [cursor]: same opaque-next-URL convention as [listConversations].
  Future<PaginatedResponse<Message>> fetchMessageHistory(
    int conversationId, {
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        cursor ?? '$_basePath$conversationId/messages/',
      );
      return PaginatedResponse.fromJson(response.data!, Message.fromJson);
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }
}

/// A `Provider`, not a singleton — same pattern as `dioClientProvider`
/// and `chatConnectionManagerProvider`, so this is trivially overridable
/// in tests with a fake/mock `Dio`.
final conversationRepositoryProvider = Provider<ConversationRepository>((
  ref,
) {
  return ConversationRepository(ref.watch(dioClientProvider));
});