import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/message.dart';

/// Part P-074 STEP 2 — REST data layer for sending a message and for
/// resuming a conversation after being away (fetch-since).
///
/// See `ConversationRepository`'s own doc comment for this project's
/// error-handling convention (catch `DioException`, rethrow the typed
/// `ApiFailure`) — followed identically here.
///
/// Deliberately does NOT send message content over the WebSocket
/// (`ChatConnectionManager`, P-073). `MessageSendView`'s own docstring
/// (`chat/views.py`) documents persistence as the one thing that
/// determines request success, with the broadcast as a separate,
/// best-effort step after the fact — and this part's own execution
/// prompt is explicit that actual message content always goes over
/// REST, never the socket. The socket (P-073) is receive-only for
/// message content (`MessageReceived` events) and send-only for the
/// ephemeral events (`sendTyping`/`sendHeartbeat`/`sendMarkDelivered`/
/// `sendMarkRead`).
class MessageRepository {
  MessageRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/api/v1/conversations/';

  /// POST `/api/v1/conversations/<conversationId>/messages/` —
  /// `MessageSendView` (P-068). Returns the persisted `Message` exactly
  /// as the backend echoes it back (`status` will be `"sent"` — the
  /// model's own default — since this is the same synchronous
  /// request/response cycle that just created it; any later
  /// `"delivered"`/`"read"` transition arrives separately as a
  /// `StatusUpdate` WebSocket event, P-073).
  Future<Message> sendMessage({
    required int conversationId,
    required String text,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath$conversationId/messages/',
        data: {'text': text},
      );
      return Message.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET
  /// `/api/v1/conversations/<conversationId>/messages/?since=<sinceMessageId>`
  /// — `MessageFetchSinceView` (P-072). Returns every message with
  /// `id > sinceMessageId`, oldest-to-newest (the model's own default
  /// ordering).
  ///
  /// Unlike `ConversationRepository.fetchMessageHistory`, this response
  /// is a **plain JSON array**, not the `{results, next, previous}`
  /// envelope: `MessageFetchSinceView` is a plain `APIView`
  /// (`Response(serializer.data)` directly), not a
  /// `generics.ListAPIView` with a `pagination_class` — so there is no
  /// pagination here and no `PaginatedResponse` wrapper to parse it
  /// into.
  Future<List<Message>> fetchMessagesSince({
    required int conversationId,
    required int sinceMessageId,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$_basePath$conversationId/messages/',
        queryParameters: {'since': sinceMessageId},
      );
      return response.data!
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(dioClientProvider));
});