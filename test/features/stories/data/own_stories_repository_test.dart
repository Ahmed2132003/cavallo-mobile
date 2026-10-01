import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/stories/data/own_stories_repository.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';

/// Part P-083 scope. Exercises [OwnStoriesRepositoryImpl] against a mocked
/// Dio adapter shaped like the REAL `GET /api/v1/stories/` contract:
/// `StoryListCreateView` + `StandardCursorPagination` + `StorySerializer`
/// (confirmed by reading `stories/views.py`, `stories/serializers.py` and
/// `core/pagination.py` in cavallo-app) -- a `{results, next, previous}`
/// envelope, not a bare array.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late OwnStoriesRepositoryImpl repository;

  Map<String, dynamic> storyJson({
    required int id,
    required String status,
    Map<String, dynamic>? extra,
  }) {
    return {
      'id': id,
      'business': 7,
      'media': 'https://cdn.example.com/stories/$id.png',
      'published_at': '2026-09-30T10:00:00Z',
      'expires_at': '2026-10-01T10:00:00Z',
      'status': status,
      'created_at': '2026-09-30T10:00:00Z',
      'updated_at': '2026-09-30T10:05:00Z',
      ...?extra,
    };
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
    repository = OwnStoriesRepositoryImpl(dio: dio);
  });

  group('listOwnStories', () {
    test(
      'parses the {results, next, previous} envelope with every status',
      () async {
        adapter.onGet(
          '/api/v1/stories/',
          (server) => server.reply(200, {
            'results': [
              storyJson(id: 3, status: 'published'),
              storyJson(id: 2, status: 'pending_review'),
              storyJson(id: 1, status: 'rejected'),
            ],
            'next': null,
            'previous': null,
          }),
        );

        final page = await repository.listOwnStories();

        expect(page.results.map((s) => s.id), [3, 2, 1]);
        expect(page.results[0].status, OwnStoryStatus.published);
        expect(page.results[1].status, OwnStoryStatus.pendingReview);
        expect(page.results[2].status, OwnStoryStatus.rejected);
        expect(page.results.first.businessId, 7);
        expect(
          page.results.first.mediaUrl,
          'https://cdn.example.com/stories/3.png',
        );
        expect(page.results.first.publishedAt, DateTime.utc(2026, 9, 30, 10));
        expect(page.results.first.expiresAt, DateTime.utc(2026, 10, 1, 10));
      },
    );

    test('carries the cursor next/previous through', () async {
      adapter.onGet(
        '/api/v1/stories/',
        (server) => server.reply(200, {
          'results': [storyJson(id: 1, status: 'published')],
          'next': 'https://api.test/api/v1/stories/?cursor=abc',
          'previous': null,
        }),
      );

      final page = await repository.listOwnStories();

      expect(page.next, 'https://api.test/api/v1/stories/?cursor=abc');
      expect(page.previous, isNull);
    });

    test('an empty results list is valid, not an error', () async {
      adapter.onGet(
        '/api/v1/stories/',
        (server) => server.reply(200, {
          'results': <dynamic>[],
          'next': null,
          'previous': null,
        }),
      );

      final page = await repository.listOwnStories();

      expect(page.results, isEmpty);
    });

    test(
      'rejection_reason is null when the backend does not send it',
      () async {
        adapter.onGet(
          '/api/v1/stories/',
          (server) => server.reply(200, {
            'results': [storyJson(id: 1, status: 'rejected')],
            'next': null,
            'previous': null,
          }),
        );

        final page = await repository.listOwnStories();

        expect(page.results.single.rejectionReason, isNull);
      },
    );

    test(
      'rejection_reason is read when present, and blank becomes null',
      () async {
        adapter.onGet(
          '/api/v1/stories/',
          (server) => server.reply(200, {
            'results': [
              storyJson(
                id: 2,
                status: 'rejected',
                extra: {'rejection_reason': 'Blurry image'},
              ),
              storyJson(
                id: 1,
                status: 'rejected',
                extra: {'rejection_reason': '   '},
              ),
            ],
            'next': null,
            'previous': null,
          }),
        );

        final page = await repository.listOwnStories();

        expect(page.results[0].rejectionReason, 'Blurry image');
        expect(page.results[1].rejectionReason, isNull);
      },
    );

    test(
      'an unexpected status string maps to unknown instead of throwing',
      () async {
        adapter.onGet(
          '/api/v1/stories/',
          (server) => server.reply(200, {
            'results': [storyJson(id: 1, status: 'archived')],
            'next': null,
            'previous': null,
          }),
        );

        final page = await repository.listOwnStories();

        expect(page.results.single.status, OwnStoryStatus.unknown);
      },
    );

    test('a 500 surfaces as a typed ServerFailure', () async {
      adapter.onGet(
        '/api/v1/stories/',
        (server) => server.reply(500, {
          'error': {'code': 'SERVER_ERROR', 'message': 'boom'},
        }),
      );

      await expectLater(
        repository.listOwnStories(),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<ServerFailure>(),
          ),
        ),
      );
    });

    test('a 401 surfaces as a typed AuthFailure', () async {
      adapter.onGet(
        '/api/v1/stories/',
        (server) => server.reply(401, {
          'error': {'code': 'NOT_AUTHENTICATED', 'message': 'no'},
        }),
      );

      await expectLater(
        repository.listOwnStories(),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<AuthFailure>(),
          ),
        ),
      );
    });
  });
}
