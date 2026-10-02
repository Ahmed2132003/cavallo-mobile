import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';

/// Part P-085 scope. Same setup convention as the other repository tests:
/// a real [ErrorInterceptor] on a mocked Dio adapter. Each `onGet` pins the
/// exact path AND the exact query parameters, so a wrong param name (e.g.
/// `from` instead of P-084's `date_from`) makes the request fail loudly.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AnalyticsRepositoryImpl repository;

  const path = '/api/v1/analytics/business/42/daily/';

  Map<String, dynamic> row(
    String date, {
    int followers = 0,
    int likes = 0,
    int comments = 0,
    int storyViews = 0,
    int newRatings = 0,
    String averageRating = '0.00',
    int activeProducts = 0,
    int publishedPosts = 0,
    int publishedReels = 0,
  }) => {
    'date': date,
    'new_followers': followers,
    'total_likes_received': likes,
    'total_comments_received': comments,
    'total_story_views': storyViews,
    'new_ratings_count': newRatings,
    'average_rating_snapshot': averageRating,
    'active_products_count': activeProducts,
    'published_posts_count': publishedPosts,
    'published_reels_count': publishedReels,
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
    repository = AnalyticsRepositoryImpl(dio: dio);
  });

  final from = DateTime.utc(2026, 10, 1);
  final to = DateTime.utc(2026, 10, 7);
  final weekParams = {
    'date_from': '2026-10-01',
    'date_to': '2026-10-07',
    'page_size': 7,
  };

  group('fetchDailyStats — success', () {
    test('sends date_from/date_to/page_size and parses the paginated '
        'envelope into entities, oldest first', () async {
      // The backend answers NEWEST first.
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': null,
          'previous': null,
          'results': [
            row(
              '2026-10-03',
              followers: 5,
              likes: 9,
              comments: 2,
              storyViews: 30,
              newRatings: 2,
              averageRating: '4.25',
              activeProducts: 8,
              publishedPosts: 5,
              publishedReels: 3,
            ),
            row('2026-10-02', followers: 1, likes: 4),
            row('2026-10-01', followers: 0),
          ],
        }),
        queryParameters: weekParams,
      );

      final stats = await repository.fetchDailyStats(
        businessId: 42,
        from: from,
        to: to,
      );

      expect(stats.map((s) => s.date).toList(), [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
        DateTime.utc(2026, 10, 3),
      ]);
      expect(
        stats.last,
        DailyStats(
          date: DateTime.utc(2026, 10, 3),
          newFollowers: 5,
          totalLikesReceived: 9,
          totalCommentsReceived: 2,
          totalStoryViews: 30,
          newRatingsCount: 2,
          averageRatingSnapshot: 4.25,
          activeProductsCount: 8,
          publishedPostsCount: 5,
          publishedReelsCount: 3,
        ),
      );
    });

    test('does NOT zero-fill days the backend returned no row for', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': null,
          'previous': null,
          'results': [row('2026-10-05', followers: 2), row('2026-10-02')],
        }),
        queryParameters: weekParams,
      );

      final stats = await repository.fetchDailyStats(
        businessId: 42,
        from: from,
        to: to,
      );

      expect(stats, hasLength(2));
    });

    test('an empty results list returns an empty list', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': null,
          'previous': null,
          'results': <Object>[],
        }),
        queryParameters: weekParams,
      );

      final stats = await repository.fetchDailyStats(
        businessId: 42,
        from: from,
        to: to,
      );

      expect(stats, isEmpty);
    });

    test('page_size is capped at the server maximum of 100', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': null,
          'previous': null,
          'results': <Object>[],
        }),
        queryParameters: {
          'date_from': '2026-01-01',
          'date_to': '2026-10-07',
          'page_size': 100,
        },
      );

      final stats = await repository.fetchDailyStats(
        businessId: 42,
        from: DateTime.utc(2026, 1, 1),
        to: to,
      );

      expect(stats, isEmpty);
    });

    test('follows a "next" link using only its cursor value against the '
        'app base URL (not the absolute URL host)', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next':
              'http://some-other-host:8095$path?date_from=2026-10-01'
              '&date_to=2026-10-07&page_size=7&cursor=abc123',
          'previous': null,
          'results': [row('2026-10-07', followers: 1)],
        }),
        queryParameters: weekParams,
      );
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': null,
          'previous': null,
          'results': [row('2026-10-06', followers: 2)],
        }),
        queryParameters: {...weekParams, 'cursor': 'abc123'},
      );

      final stats = await repository.fetchDailyStats(
        businessId: 42,
        from: from,
        to: to,
      );

      expect(stats.map((s) => s.date).toList(), [
        DateTime.utc(2026, 10, 6),
        DateTime.utc(2026, 10, 7),
      ]);
    });

    test(
      'only the y/m/d of from/to matter (time and zone are ignored)',
      () async {
        adapter.onGet(
          path,
          (server) => server.reply(200, {
            'next': null,
            'previous': null,
            'results': <Object>[],
          }),
          queryParameters: weekParams,
        );

        final stats = await repository.fetchDailyStats(
          businessId: 42,
          from: DateTime(2026, 10, 1, 23, 59),
          to: DateTime(2026, 10, 7, 0, 1),
        );

        expect(stats, isEmpty);
      },
    );
  });

  group('fetchDailyStats — failures', () {
    Future<Object?> failure() async {
      try {
        await repository.fetchDailyStats(businessId: 42, from: from, to: to);
      } catch (e) {
        return e;
      }
      return null;
    }

    test('401 surfaces as AuthFailure', () async {
      adapter.onGet(
        path,
        (server) => server.reply(401, {'detail': 'Not authenticated.'}),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<AuthFailure>());
    });

    test('403 (not the owner) surfaces as AuthFailure', () async {
      adapter.onGet(
        path,
        (server) => server.reply(403, {'detail': 'Forbidden.'}),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<AuthFailure>());
    });

    test('500 surfaces as ServerFailure', () async {
      adapter.onGet(
        path,
        (server) => server.reply(500, {'detail': 'boom'}),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<ServerFailure>());
    });

    test('no connectivity surfaces as NetworkFailure', () async {
      adapter.onGet(
        path,
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: path),
            reason: 'Failed host lookup',
          ),
        ),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<NetworkFailure>());
    });

    test('a bare JSON array (not the paginated envelope) is an '
        'UnknownFailure, not a silent empty result', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, [row('2026-10-01')]),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<UnknownFailure>());
    });

    test(
      'a row missing a metric is an UnknownFailure (no defaulting to 0)',
      () async {
        adapter.onGet(
          path,
          (server) => server.reply(200, {
            'next': null,
            'previous': null,
            'results': [
              {'date': '2026-10-01', 'new_followers': 1},
            ],
          }),
          queryParameters: weekParams,
        );

        expect(await failure(), isA<UnknownFailure>());
      },
    );

    test('a "next" link without a cursor is an UnknownFailure', () async {
      adapter.onGet(
        path,
        (server) => server.reply(200, {
          'next': 'http://host$path?page_size=7',
          'previous': null,
          'results': [row('2026-10-07')],
        }),
        queryParameters: weekParams,
      );

      expect(await failure(), isA<UnknownFailure>());
    });

    test('from after to is rejected before any request is made', () {
      expect(
        () => repository.fetchDailyStats(businessId: 42, from: to, to: from),
        throwsArgumentError,
      );
    });
  });
}
