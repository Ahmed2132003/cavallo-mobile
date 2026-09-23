import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late StoryCreationRepository repository;
  List<dynamic>? capturedRequestData;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    capturedRequestData = [];
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedRequestData!.add(options.data);
          handler.next(options);
        },
      ),
    );

    repository = StoryCreationRepository(dio: dio);
  });

  group('uploadStoryMedia', () {
    test('sends a multipart body with the media file under "media"', () async {
      final tempFile = await _writeTempPng();

      dio.httpClientAdapter = _FakeJsonAdapter(
        {
          'id': 1,
          'business': 1,
          'media': 'https://cdn.example.com/stories/1.png',
          'published_at': '2026-09-23T10:00:00Z',
          'expires_at': '2026-09-24T10:00:00Z',
          'status': 'pending_review',
          'created_at': '2026-09-23T10:00:00Z',
          'updated_at': '2026-09-23T10:00:00Z',
        },
        statusCode: 201,
      );

      await repository.uploadStoryMedia(mediaFile: tempFile);

      final sent = capturedRequestData!.single;
      expect(sent, isA<FormData>());
      final formData = sent as FormData;
      expect(formData.files, hasLength(1));
      expect(formData.files.single.key, 'media');

      await tempFile.delete();
    });

    test('passes the cancelToken through to the request', () async {
      final tempFile = await _writeTempPng();
      final cancelToken = CancelToken();

      dio.httpClientAdapter = _FakeJsonAdapter(
        {
          'id': 1,
          'business': 1,
          'media': 'https://cdn.example.com/stories/1.png',
          'published_at': '2026-09-23T10:00:00Z',
          'expires_at': '2026-09-24T10:00:00Z',
          'status': 'pending_review',
          'created_at': '2026-09-23T10:00:00Z',
          'updated_at': '2026-09-23T10:00:00Z',
        },
        statusCode: 201,
      );

      await repository.uploadStoryMedia(
        mediaFile: tempFile,
        cancelToken: cancelToken,
      );

      expect(cancelToken.isCancelled, isFalse);
      await tempFile.delete();
    });

    test('a 400 validation error surfaces as ValidationFailure, not silently swallowed', () async {
      dio.httpClientAdapter = _FakeJsonAdapter(
        {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Unsupported media type.',
            'fields': {
              'media': ['Unsupported file type.'],
            },
          },
        },
        statusCode: 400,
      );

      final tempFile = await _writeTempPng();

      try {
        await repository.uploadStoryMedia(mediaFile: tempFile);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationFailure>());
        final failure = e.error as ValidationFailure;
        expect(failure.fields['media'], contains('Unsupported file type.'));
      }

      await tempFile.delete();
    });
  });
}

Future<File> _writeTempPng() async {
  const pngBytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  final file = File(
    '${Directory.systemTemp.path}/p051_test_image_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(pngBytes);
  return file;
}

class _FakeJsonAdapter implements HttpClientAdapter {
  _FakeJsonAdapter(this.jsonBody, {required this.statusCode});

  final Map<String, dynamic> jsonBody;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    final bytes = utf8.encode(jsonEncode(jsonBody));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}