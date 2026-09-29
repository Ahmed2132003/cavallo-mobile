import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';

import 'fake_http_client_adapter.dart';

/// Part P-077 STEP 2 — data-layer tests: the JSON request shape for
/// sending shared content, and parsing of the new `shared_content` /
/// `shared_content_type` fields on every path they can arrive (REST
/// `Message`, WebSocket `MessageReceived`, list `LastMessagePreview`).
void main() {
  late FakeHttpClientAdapter adapter;
  late Dio dio;
  late MessageRepository repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    repository = MessageRepository(dio);
  });

  Map<String, dynamic> sharedPayload({
    String contentType = 'post',
    int objectId = 42,
    bool available = true,
  }) => {
    'content_type': contentType,
    'object_id': objectId,
    'available': available,
    'business_id': available ? 7 : null,
    'business_name': available ? 'Al Anaqa Store' : null,
    'preview': available
        ? {
            'preview_text': 'New summer collection',
            'preview_image_url': 'http://media.local/posts/summer.png',
          }
        : null,
  };

  Map<String, dynamic> serverResponse({
    String text = '',
    Map<String, dynamic>? sharedContent,
  }) => {
    'id': 91,
    'conversation': 5,
    'sender': 1,
    'text': text,
    'media': null,
    'media_type': '',
    'shared_content': sharedContent,
    'status': 'sent',
    'created_at': '2026-09-29T12:00:00Z',
  };

  group('SharedContentType', () {
    test('fromRaw maps the three whitelisted strings, else null', () {
      expect(SharedContentType.fromRaw('post'), SharedContentType.post);
      expect(SharedContentType.fromRaw('reel'), SharedContentType.reel);
      expect(SharedContentType.fromRaw('product'), SharedContentType.product);
      expect(SharedContentType.fromRaw(''), isNull);
      expect(SharedContentType.fromRaw(null), isNull);
      expect(SharedContentType.fromRaw('user'), isNull);
    });
  });

  group('sendSharedContentMessage', () {
    test('POSTs JSON with type + id and NO text when text is empty', () async {
      adapter.enqueue(
        statusCode: 201,
        data: serverResponse(sharedContent: sharedPayload()),
      );

      final message = await repository.sendSharedContentMessage(
        conversationId: 5,
        contentType: SharedContentType.post,
        objectId: 42,
      );

      final sent = adapter.requestedOptions.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/conversations/5/messages/');
      expect(sent.data, {
        'shared_content_type': 'post',
        'shared_object_id': 42,
      });

      expect(message.id, 91);
      expect(message.text, '');
      expect(message.sharedContent, isNotNull);
      expect(message.sharedContent!.type, SharedContentType.post);
      expect(message.sharedContent!.objectId, 42);
    });

    test('includes text alongside the shared reference when given', () async {
      adapter.enqueue(
        statusCode: 201,
        data: serverResponse(
          text: 'check this out!',
          sharedContent: sharedPayload(contentType: 'product', objectId: 9),
        ),
      );

      final message = await repository.sendSharedContentMessage(
        conversationId: 5,
        contentType: SharedContentType.product,
        objectId: 9,
        text: 'check this out!',
      );

      expect(adapter.requestedOptions.single.data, {
        'text': 'check this out!',
        'shared_content_type': 'product',
        'shared_object_id': 9,
      });
      expect(message.text, 'check this out!');
      expect(message.sharedContent!.type, SharedContentType.product);
    });
  });

  group('parsing shared_content', () {
    test('Message.fromJson parses an available shared post with preview', () {
      final message = Message.fromJson(
        serverResponse(sharedContent: sharedPayload()),
      );

      final shared = message.sharedContent!;
      expect(shared.type, SharedContentType.post);
      expect(shared.objectId, 42);
      expect(shared.available, isTrue);
      expect(shared.businessId, 7);
      expect(shared.businessName, 'Al Anaqa Store');
      expect(shared.previewText, 'New summer collection');
      expect(shared.previewImageUrl, 'http://media.local/posts/summer.png');
    });

    test('Message.fromJson parses an UNAVAILABLE shared reel (all null)', () {
      final message = Message.fromJson(
        serverResponse(
          sharedContent: sharedPayload(
            contentType: 'reel',
            objectId: 3,
            available: false,
          ),
        ),
      );

      final shared = message.sharedContent!;
      expect(shared.type, SharedContentType.reel);
      expect(shared.objectId, 3);
      expect(shared.available, isFalse);
      expect(shared.businessId, isNull);
      expect(shared.businessName, isNull);
      expect(shared.previewText, isNull);
      expect(shared.previewImageUrl, isNull);
    });

    test('Message.fromJson: explicit null and missing key both mean none', () {
      final explicitNull = Message.fromJson(serverResponse());
      expect(explicitNull.sharedContent, isNull);

      final legacy = Message.fromJson({
        'id': 1,
        'conversation': 5,
        'sender': 1,
        'text': 'old shape',
        'status': 'sent',
        'created_at': '2026-09-27T11:00:00Z',
      });
      expect(legacy.sharedContent, isNull);
    });

    test('an unknown content_type is treated as nothing shared', () {
      final message = Message.fromJson(
        serverResponse(sharedContent: sharedPayload(contentType: 'user')),
      );
      expect(message.sharedContent, isNull);
      // ...and the rest of the message still parses.
      expect(message.id, 91);
    });

    test('copyWithStatus keeps sharedContent', () {
      final message = Message.fromJson(
        serverResponse(sharedContent: sharedPayload()),
      );
      final copy = message.copyWithStatus(message.status);
      expect(copy.sharedContent, message.sharedContent);
      expect(copy, message);
    });

    test('ChatEvent.fromJson: a shared frame carries the raw map', () {
      final event = ChatEvent.fromJson(
        serverResponse(sharedContent: sharedPayload(contentType: 'reel')),
      );
      final received = event as MessageReceived;
      expect(received.sharedContent, isNotNull);
      expect(received.sharedContent!['content_type'], 'reel');
      expect(received.sharedContent!['object_id'], 42);

      // Two frames with equal nested content are equal (value equality
      // despite Dart's identity-based Map ==).
      final again = ChatEvent.fromJson(
        serverResponse(sharedContent: sharedPayload(contentType: 'reel')),
      );
      expect(again, received);
      expect(again.hashCode, received.hashCode);
    });

    test('ChatEvent.fromJson: a text-only frame has null sharedContent', () {
      final event = ChatEvent.fromJson(serverResponse(text: 'hi'));
      expect((event as MessageReceived).sharedContent, isNull);
    });

    test('LastMessagePreview.previewText: text wins, else shared label', () {
      LastMessagePreview preview(String text, String sharedType) =>
          LastMessagePreview.fromJson({
            'id': 1,
            'text': text,
            'media_type': '',
            'shared_content_type': sharedType,
            'sender_id': 2,
            'status': 'sent',
            'created_at': '2026-09-29T12:00:00Z',
          });

      expect(preview('look', 'post').previewText, 'look');
      expect(preview('', 'post').previewText, 'Shared a post');
      expect(preview('', 'reel').previewText, 'Shared a reel');
      expect(preview('', 'product').previewText, 'Shared a product');
      expect(preview('hello', '').previewText, 'hello');
    });

    test('LastMessagePreview: legacy payload without the key still parses', () {
      final preview = LastMessagePreview.fromJson({
        'id': 1,
        'text': 'hey',
        'sender_id': 2,
        'status': 'sent',
        'created_at': '2026-09-29T12:00:00Z',
      });
      expect(preview.sharedContentType, isNull);
      expect(preview.previewText, 'hey');
    });
  });
}