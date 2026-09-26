import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';

/// Part P-062 scope. Mirrors `feed_repository_test.dart`'s (Part P-061)
/// exact setup convention: a real [ErrorInterceptor] on a mocked Dio
/// adapter.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late DiscoverRepositoryImpl repository;

  const postJson = {
    'content_type': 'post',
    'id': 201,
    'business': 11,
    'caption': 'General content',
    'image': 'https://cdn.example.com/posts/201.png',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };

  const reelJson = {
    'content_type': 'reel',
    'id': 77,
    'business': 12,
    'caption': 'Discover me',
    'video': 'https://cdn.example.com/reels/77.mp4',
    'thumbnail': 'https://cdn.example.com/reels/77_thumb.png',
    'duration_seconds': 9,
    'created_at': '2026-09-01T09:00:00Z',
    'updated_at': '2026-09-01T09:00:00Z',
  };

  Map<String, dynamic> storyJson({
    required int id,
    required int businessId,
    required String createdAt,
  }) => {
    'id': id,
    'business': businessId,
    'media': 'https://cdn.example.com/stories/$id.jpg',
    'published_at': createdAt,
    'expires_at': '2026-09-02T10:00:00Z',
    'created_at': createdAt,
    'updated_at': createdAt,
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = DiscoverRepositoryImpl(dio: dio);
  });

  group('fetchDiscoverFeed', () {
    test(
      'first page (no cursor) sends no cursor query param and parses '
      'mixed post/reel items in order',
      () async {
        adapter.onGet(
          '/api/v1/feed/discover/',
          (server) => server.reply(200, {
            'items': [postJson, reelJson],
            'next_cursor': 'opaque-discover-cursor',
          }),
        );

        final page = await repository.fetchDiscoverFeed();

        expect(page.items, hasLength(2));
        expect(page.items[0], isA<PostFeedItem>());
        expect((page.items[0] as PostFeedItem).post.id, 201);
        expect(page.items[1], isA<ReelFeedItem>());
        expect((page.items[1] as ReelFeedItem).reel.id, 77);
        expect(page.nextCursor, 'opaque-discover-cursor');
      },
    );

    test(
      'a non-null cursor is sent back to the server completely verbatim',
      () async {
        const opaqueCursor = 'eyJ2IjoxLCJwIjoiYiJ9-weird-but-opaque';
        adapter.onGet(
          '/api/v1/feed/discover/',
          (server) => server.reply(200, {'items': [], 'next_cursor': null}),
          queryParameters: {'cursor': opaqueCursor},
        );

        final page = await repository.fetchDiscoverFeed(cursor: opaqueCursor);

        expect(page.items, isEmpty);
        expect(page.nextCursor, isNull);
      },
    );

    test('an unknown content_type throws FormatException', () async {
      adapter.onGet(
        '/api/v1/feed/discover/',
        (server) => server.reply(200, {
          'items': [
            {...postJson, 'content_type': 'story'},
          ],
          'next_cursor': null,
        }),
      );

      expect(() => repository.fetchDiscoverFeed(), throwsFormatException);
    });

    test('a genuine 500 propagates as ServerFailure', () async {
      adapter.onGet(
        '/api/v1/feed/discover/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'Something broke'},
        }),
      );

      try {
        await repository.fetchDiscoverFeed();
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerFailure>());
      }
    });
  });

  group('fetchActiveStoryGroups', () {
    test('calls the public stories endpoint with no business_id filter '
        'and groups results by business, preserving newest-first order', () async {
      adapter.onGet(
        '/api/v1/stories/public/',
        (server) => server.reply(200, {
          'results': [
            storyJson(id: 3, businessId: 5, createdAt: '2026-09-01T12:00:00Z'),
            storyJson(id: 2, businessId: 6, createdAt: '2026-09-01T11:00:00Z'),
            storyJson(id: 1, businessId: 5, createdAt: '2026-09-01T10:00:00Z'),
          ],
          'next': null,
          'previous': null,
        }),
      );

      final groups = await repository.fetchActiveStoryGroups();

      expect(groups, hasLength(2));
      expect(groups[0].businessId, 5);
      expect(groups[0].stories.map((s) => s.id), [3, 1]);
      expect(groups[1].businessId, 6);
      expect(groups[1].stories.map((s) => s.id), [2]);
    });

    test('an empty result list yields an empty group list', () async {
      adapter.onGet(
        '/api/v1/stories/public/',
        (server) =>
            server.reply(200, {'results': [], 'next': null, 'previous': null}),
      );

      final groups = await repository.fetchActiveStoryGroups();

      expect(groups, isEmpty);
    });
  });
}