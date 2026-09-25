import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/feed/data/feed_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';

/// Part P-061 scope. Exercises [FeedRepositoryImpl] against a mocked
/// Dio adapter shaped like the real `GET /api/v1/feed/home/` contract
/// documented in `PROJECT_PROGRESS.md` (Parts P-059/P-060). Same setup
/// convention as `product_public_repository_test.dart` (Part P-034): a
/// real [ErrorInterceptor] on a mocked adapter.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late FeedRepositoryImpl repository;

  const postJson = {
    'content_type': 'post',
    'id': 101,
    'business': 7,
    'caption': 'New arrivals',
    'image': 'https://cdn.example.com/posts/101.png',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };

  const reelJson = {
    'content_type': 'reel',
    'id': 55,
    'business': 9,
    'caption': 'Behind the scenes',
    'video': 'https://cdn.example.com/reels/55.mp4',
    'thumbnail': 'https://cdn.example.com/reels/55_thumb.png',
    'duration_seconds': 14,
    'created_at': '2026-09-01T09:00:00Z',
    'updated_at': '2026-09-01T09:00:00Z',
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = FeedRepositoryImpl(dio: dio);
  });

  group('fetchHomeFeed', () {
    test(
      'first page (no cursor) sends no cursor query param and parses '
      'mixed post/reel items in order',
      () async {
        adapter.onGet(
          '/api/v1/feed/home/',
          (server) => server.reply(200, {
            'items': [postJson, reelJson],
            'next_cursor': 'abc123opaque',
          }),
        );

        final page = await repository.fetchHomeFeed();

        expect(page.items, hasLength(2));
        expect(page.items[0], isA<PostFeedItem>());
        expect((page.items[0] as PostFeedItem).post.id, 101);
        expect(page.items[1], isA<ReelFeedItem>());
        expect((page.items[1] as ReelFeedItem).reel.id, 55);
        expect((page.items[1] as ReelFeedItem).reel.durationSeconds, 14);
        expect(page.nextCursor, 'abc123opaque');
      },
    );

    test(
      'a non-null cursor is sent back to the server completely verbatim, '
      'never parsed or rebuilt',
      () async {
        const opaqueCursor = 'eyJ2IjoxLCJwIjoiZiJ9-weird-but-opaque';
        adapter.onGet(
          '/api/v1/feed/home/',
          (server) => server.reply(200, {'items': [], 'next_cursor': null}),
          queryParameters: {'cursor': opaqueCursor},
        );

        final page = await repository.fetchHomeFeed(cursor: opaqueCursor);

        expect(page.items, isEmpty);
        expect(page.nextCursor, isNull);
      },
    );

    test('next_cursor: null means no more pages', () async {
      adapter.onGet(
        '/api/v1/feed/home/',
        (server) => server.reply(200, {
          'items': [postJson],
          'next_cursor': null,
        }),
      );

      final page = await repository.fetchHomeFeed();

      expect(page.nextCursor, isNull);
    });

    test('an unknown content_type throws FormatException', () async {
      adapter.onGet(
        '/api/v1/feed/home/',
        (server) => server.reply(200, {
          'items': [
            {...postJson, 'content_type': 'story'},
          ],
          'next_cursor': null,
        }),
      );

      expect(() => repository.fetchHomeFeed(), throwsFormatException);
    });

    test('a genuine 500 propagates as ServerFailure', () async {
      adapter.onGet(
        '/api/v1/feed/home/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
      );

      try {
        await repository.fetchHomeFeed();
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });
  });
}