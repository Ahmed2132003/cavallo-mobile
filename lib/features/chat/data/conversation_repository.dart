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
///
/// ### CONFIRMED bug fix — [listConversations] response shape
///
/// This method's own STEP 2 doc comment already flagged the risk:
/// "if [`REST_FRAMEWORK.DEFAULT_PAGINATION_CLASS`] turns out to be
/// unset ... this method will fail loudly." Live, real-device testing
/// during P-074's manual-test pass confirmed exactly that: `base.py`'s
/// `REST_FRAMEWORK` dict has no `DEFAULT_PAGINATION_CLASS` entry at
/// all, and `ConversationListView` sets none of its own, so
/// `GET /api/v1/conversations/` returns a **plain JSON array**, not
/// `{results, next, previous}`. Requesting it as
/// `_dio.get<Map<String, dynamic>>(...)` made Dio itself throw trying
/// to cast the decoded `List` to a `Map` — wrapped as a `DioException`
/// whose `.error` was the raw `TypeError`, not an `ApiFailure`,
/// crashing the `on DioException catch (e) { throw e.error as
/// ApiFailure; }` line below with a *second*, more confusing cast
/// failure (`_TypeError is not a subtype of ApiFailure`) — which is
/// what actually surfaced in the running app as an uncaught exception,
/// leaving `ChatListScreen`'s loading spinner stuck forever (its
/// `on ApiFailure catch` never matched an escaped `_TypeError`).
///
/// Fixed below by requesting the response untyped (`dynamic`) and
/// branching on the real runtime shape: a bare `List` is wrapped into a
/// single, non-paginated "page" (`next`/`previous` both `null`); the
/// `{results, next, previous}` envelope is still parsed the original
/// way if the backend is ever changed to emit it (e.g. by giving
/// `ConversationListView` an explicit `pagination_class`, matching
/// whatever convention `ProductListScreen`'s/`ContentListScreen`'s own
/// already-working paginated endpoints use) — so this method keeps
/// working either way, no future Flutter change required.
class ConversationRepository {
  ConversationRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/api/v1/conversations/';

  /// GET /api/v1/conversations/ — the Conversation List screen's primary
  /// fetch (`ConversationListView`).
  ///
  /// See this class's own "CONFIRMED bug fix" doc section above for why
  /// this branches on the response's actual runtime shape instead of
  /// assuming a paginated envelope.
  ///
  /// [cursor] is an opaque full URL from a previous
  /// `PaginatedResponse.next` — pass it to fetch the next page. Omit (or
  /// pass null) for the first page. Currently always `null` in practice
  /// (the backend returns everything in one plain array — see above),
  /// but kept so this method's signature doesn't need to change again
  /// if/when the backend adds real pagination.
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<dynamic>(cursor ?? _basePath);
      final data = response.data;

      if (data is List) {
        // Confirmed live (P-074 manual test): the backend returns a
        // plain array, not {results, next, previous}. Wrap it into a
        // single, non-paginated "page" so ChatListScreen's own
        // pagination handling (harmlessly) just never finds a `next`
        // cursor to follow.
        return PaginatedResponse<Conversation>(
          results: data
              .map(
                (json) => Conversation.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
          next: null,
          previous: null,
        );
      }

      return PaginatedResponse.fromJson(
        data as Map<String, dynamic>,
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

  /// Part P-077 STEP 5 — start (or resume) the conversation with a
  /// business's owner, naming the business by its `BusinessProfile` id
  /// (`POST /api/v1/conversations/start/` with `{"business_id": ...}`).
  /// The backend resolves the owning user itself: no public endpoint
  /// exposes a business owner's user id, so the app could not use
  /// [startConversation]'s `recipient_id` for this.
  ///
  /// That endpoint answers only `{id, created_at, updated_at,
  /// participant_ids}`, and this app deliberately never knows its own
  /// user id, so it cannot tell which participant is "the other one".
  /// So after the POST, the real [Conversation] (with the resolved
  /// display name) is looked up in the conversation list — brand-new,
  /// still-empty conversations are listed too. Returns `null` only if
  /// the conversation was started but is not in the list (should not
  /// happen); the caller must not open a thread in that case.
  ///
  /// Throws the typed [ApiFailure] like every other method here (e.g. a
  /// [ValidationFailure] when a business owner messages their own
  /// business, or when the business no longer exists).
  Future<Conversation?> startConversationWithBusiness({
    required int businessId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_basePath}start/',
        data: {'business_id': businessId},
      );
      final conversationId = response.data!['id'] as int;

      final page = await listConversations();
      for (final conversation in page.results) {
        if (conversation.id == conversationId) return conversation;
      }
      return null;
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
  /// ⚠️ NOT YET given the same defensive fix as [listConversations]
  /// above — `MessageHistoryView`'s own doc comment (per this method's
  /// STEP 2 note) claims a specific, named `StandardCursorPagination`
  /// class, unlike `ConversationListView`, which named none and fell
  /// through to a (missing) project-wide default. That's a real
  /// difference, not just an assumption repeated twice — but it hasn't
  /// been live-tested yet the way [listConversations] just was. If
  /// opening a real chat thread during this part's manual test throws
  /// the same `_TypeError`/`ApiFailure` cast failure at this method's
  /// own `PaginatedResponse.fromJson` line, apply the identical fix
  /// here.
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