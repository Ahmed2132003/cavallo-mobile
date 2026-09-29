import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';

import 'fake_http_client_adapter.dart';

/// Part P-076 — data-layer tests: multipart upload shape, and parsing of
/// the new `media` / `media_type` fields on every path they can arrive
/// (REST `Message`, WebSocket `MessageReceived`, list `LastMessagePreview`).
void main() {
  late FakeHttpClientAdapter adapter;
  late Dio dio;
  late MessageRepository repository;
  late Directory tempDir;
  late File photo;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    repository = MessageRepository(dio);
    tempDir = Directory.systemTemp.createTempSync('chat_media_test_');
    photo = File('${tempDir.path}${Platform.pathSeparator}photo.png')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    // Best-effort cleanup. On Windows the fake adapter never reads the
    // FormData stream, so the picked file's handle can still be open and
    // deletion fails with errno 32. That is a test-harness artifact, not
    // an app problem — and the OS temp dir is cleaned up anyway.
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  Map<String, dynamic> serverResponse({
    String text = '',
    String? media = 'http://media.local/chat/media/photo.png',
    String mediaType = 'image',
  }) => {
    'id': 90,
    'conversation': 5,
    'sender': 1,
    'text': text,
    'media': media,
    'media_type': mediaType,
    'status': 'sent',
    'created_at': '2026-09-29T11:00:00Z',
  };

  group('sendMediaMessage', () {
    test('POSTs multipart with the media file and caption, parses media', () async {
      adapter.enqueue(statusCode: 201, data: serverResponse(text: 'look'));

      final message = await repository.sendMediaMessage(
        conversationId: 5,
        text: 'look',
        mediaPath: photo.path,
      );

      expect(message.id, 90);
      expect(message.text, 'look');
      expect(message.mediaUrl, 'http://media.local/chat/media/photo.png');
      expect(message.mediaType, ChatMediaType.image);

      final sent = adapter.requestedOptions.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/conversations/5/messages/');
      final form = sent.data as FormData;
      expect(form.files.single.key, 'media');
      expect(form.files.single.value.filename, 'photo.png');
      expect(form.fields.map((e) => '${e.key}=${e.value}'), ['text=look']);
    });

    test('a media-only message sends NO text field', () async {
      adapter.enqueue(statusCode: 201, data: serverResponse());

      final message = await repository.sendMediaMessage(
        conversationId: 5,
        text: '',
        mediaPath: photo.path,
      );

      expect(message.text, '');
      final form = adapter.requestedOptions.single.data as FormData;
      expect(form.fields, isEmpty);
      expect(form.files.single.key, 'media');
    });
  });

  group('parsing media fields', () {
    test('Message.fromJson parses a video message', () {
      final message = Message.fromJson(
        serverResponse(
          media: 'http://media.local/chat/media/clip.mp4',
          mediaType: 'video',
        ),
      );
      expect(message.mediaUrl, 'http://media.local/chat/media/clip.mp4');
      expect(message.mediaType, ChatMediaType.video);
    });

    test('Message.fromJson: text-only message has no media', () {
      final message = Message.fromJson(
        serverResponse(text: 'hi', media: null, mediaType: ''),
      );
      expect(message.mediaUrl, isNull);
      expect(message.mediaType, isNull);
    });

    test('Message.fromJson still parses a legacy payload with no media keys', () {
      final message = Message.fromJson({
        'id': 1,
        'conversation': 5,
        'sender': 1,
        'text': 'old shape',
        'status': 'sent',
        'created_at': '2026-09-27T11:00:00Z',
      });
      expect(message.mediaUrl, isNull);
      expect(message.mediaType, isNull);
    });

    test('copyWithStatus keeps the media fields', () {
      final message = Message.fromJson(serverResponse());
      final read = message.copyWithStatus(message.status);
      expect(read.mediaUrl, message.mediaUrl);
      expect(read.mediaType, message.mediaType);
    });

    test('ChatEvent.fromJson: a media chat_message frame carries media', () {
      final event = ChatEvent.fromJson(serverResponse(text: 'pic'));
      expect(event, isA<MessageReceived>());
      final received = event as MessageReceived;
      expect(received.mediaUrl, 'http://media.local/chat/media/photo.png');
      expect(received.mediaType, 'image');
    });

    test('ChatEvent.fromJson: a text-only frame has null media', () {
      final event = ChatEvent.fromJson(
        serverResponse(text: 'hi', media: null, mediaType: ''),
      );
      final received = event as MessageReceived;
      expect(received.mediaUrl, isNull);
      expect(received.mediaType, isNull);
    });

    test('LastMessagePreview.previewText: text wins, else Photo/Video label', () {
      LastMessagePreview preview(String text, String mediaType) =>
          LastMessagePreview.fromJson({
            'id': 1,
            'text': text,
            'media_type': mediaType,
            'sender_id': 2,
            'status': 'sent',
            'created_at': '2026-09-29T11:00:00Z',
          });

      expect(preview('caption', 'image').previewText, 'caption');
      expect(preview('', 'image').previewText, 'Photo');
      expect(preview('', 'video').previewText, 'Video');
      expect(preview('hello', '').previewText, 'hello');
    });
  });
}