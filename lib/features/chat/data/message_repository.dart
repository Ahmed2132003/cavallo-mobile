import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/message.dart';
import '../domain/shared_content.dart';

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

  /// Part P-076 — POST the SAME endpoint as [sendMessage], but as
  /// multipart with a `media` file (and an optional `text` caption).
  ///
  /// Kept as a separate method (not extra optional parameters on
  /// [sendMessage]) so [sendMessage]'s signature — which P-075's test
  /// doubles override — stays byte-for-byte unchanged.
  ///
  /// The `FormData` is built INSIDE this method on purpose: Dio can
  /// only send a given `FormData` once ("has already been finalized"),
  /// so `OutboundMessageQueueNotifier` retrying by calling this method
  /// again gets a brand-new `FormData` every attempt.
  ///
  /// `text` is omitted from the body when empty (a media-only message).
  /// The client never sends a media type — the backend sniffs the real
  /// content type via `validate_upload()` and reports it back as
  /// `media_type`.
  ///
  /// Like [sendMessage], throws the typed [ApiFailure] for any Dio
  /// failure. A missing/unreadable local file throws the underlying
  /// `FileSystemException` instead, which the queue treats as a
  /// non-retryable failure.
  Future<Message> sendMediaMessage({
    required int conversationId,
    required String text,
    required String mediaPath,
  }) async {
    try {
      final data = FormData.fromMap({
        if (text.isNotEmpty) 'text': text,
        'media': await MultipartFile.fromFile(
          mediaPath,
          filename: _fileNameOf(mediaPath),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath$conversationId/messages/',
        data: data,
      );
      return Message.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// Part P-077 — POST the SAME endpoint as [sendMessage], but as JSON
  /// carrying a `shared_content_type` / `shared_object_id` pair that
  /// references an existing Post / Reel / Product (resolved and
  /// authorized server-side by `resolve_shareable_target()`), with an
  /// optional `text` alongside (e.g. "check this out!").
  ///
  /// Kept as a separate method for the same reason as
  /// [sendMediaMessage]: [sendMessage]'s signature stays byte-for-byte
  /// unchanged. `text` is omitted from the body when empty. The client
  /// never sends preview data — the backend derives the card's preview
  /// itself and returns it as `shared_content` on the persisted message.
  ///
  /// Error mapping is the typed [ApiFailure] like the other methods:
  /// the backend answers 404 for a missing / unpublished / inactive
  /// target, 400 for a type outside the whitelist, and 403 when the
  /// caller is not a participant of the conversation.
  Future<Message> sendSharedContentMessage({
    required int conversationId,
    required SharedContentType contentType,
    required int objectId,
    String text = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath$conversationId/messages/',
        data: {
          if (text.isNotEmpty) 'text': text,
          'shared_content_type': contentType.raw,
          'shared_object_id': objectId,
        },
      );
      return Message.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  static String _fileNameOf(String path) => path.split(RegExp(r'[\\/]')).last;

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