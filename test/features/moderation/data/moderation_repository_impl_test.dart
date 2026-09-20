import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/moderation/data/moderation_repository_impl.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';

/// Part P-040 scope. Exercises [ModerationRepositoryImpl] against a mocked
/// Dio adapter shaped exactly like the real `/api/v1/moderation/` contract
/// (Part P-038 — confirmed by reading `moderation/views.py` and
/// `moderation/serializers.py`), with a real `ErrorInterceptor` attached
/// like `dioClientProvider`'s chain, so failure assertions see genuine
/// `ApiFailure` variants. Same setup as `auth_repository_impl_test.dart`.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ModerationRepositoryImpl repository;

  Map<String, dynamic> rowJson({
    int id = 5,
    String status = 'pending',
    String priority = 'normal',
  }) => {
    'id': id,
    'content_type': 'post',
    'object_id': 12,
    'status': status,
    'priority': priority,
    'created_at': '2026-09-20T10:00:00Z',
    'age': 120,
    'preview': {'preview_text': 'A caption', 'preview_image_url': null},
    'submitter': {'business_name': 'Elegance Store'},
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    repository = ModerationRepositoryImpl(dio: dio);
  });

  group('fetchQueue', () {
    test(
      'requests the max page size, and parses a paginated '
      '{results, next, previous} response into QueueItems',
      () async {
        adapter.onGet(
          '/api/v1/moderation/queue/',
          (server) => server.reply(200, {
            'results': [
              rowJson(id: 5, priority: 'fast_path'),
              rowJson(id: 6),
            ],
            'next': null,
            'previous': null,
          }),
          queryParameters: {'page_size': 100},
        );

        final page = await repository.fetchQueue();

        expect(page.results, hasLength(2));
        expect(page.results.first.id, 5);
        expect(page.results.first.priority, QueuePriority.fastPath);
        expect(page.results.last.priority, QueuePriority.normal);
        expect(page.results.first.submitterBusinessName, 'Elegance Store');
        expect(page.next, isNull);
      },
    );

    test('sends ?priority=fast_path when a priority filter is given', () async {
      adapter.onGet(
        '/api/v1/moderation/queue/',
        (server) => server.reply(200, {
          'results': [rowJson(id: 9, priority: 'fast_path')],
          'next': null,
          'previous': null,
        }),
        queryParameters: {'page_size': 100, 'priority': 'fast_path'},
      );

      final page = await repository.fetchQueue(priority: QueuePriority.fastPath);

      expect(page.results, hasLength(1));
      expect(page.results.single.id, 9);
    });

    test('carries the next-page cursor through when more items exist', () async {
      adapter.onGet(
        '/api/v1/moderation/queue/',
        (server) => server.reply(200, {
          'results': [rowJson()],
          'next': 'https://api.test/api/v1/moderation/queue/?cursor=abc',
          'previous': null,
        }),
        queryParameters: {'page_size': 100},
      );

      final page = await repository.fetchQueue();

      expect(page.next, 'https://api.test/api/v1/moderation/queue/?cursor=abc');
    });

    test(
      'a 403 (caller lacks can_moderate_content) surfaces as AuthFailure',
      () async {
        adapter.onGet(
          '/api/v1/moderation/queue/',
          (server) => server.reply(403, {
            'error': {
              'code': 'PERMISSION_DENIED',
              'message': 'Missing required capability: can_moderate_content.',
            },
          }),
          queryParameters: {'page_size': 100},
        );

        try {
          await repository.fetchQueue();
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.error, isA<AuthFailure>());
        }
      },
    );
  });

  group('approve', () {
    test('POSTs to the item\'s approve URL and maps the updated row', () async {
      adapter.onPost(
        '/api/v1/moderation/queue/7/approve/',
        (server) => server.reply(200, rowJson(id: 7, status: 'approved')),
      );

      final item = await repository.approve(7);

      expect(item.id, 7);
      expect(item.status, QueueItemStatus.approved);
    });

    test(
      'a 409 (already decided) surfaces as UnknownFailure with the '
      'status code still readable from the response',
      () async {
        adapter.onPost(
          '/api/v1/moderation/queue/7/approve/',
          (server) => server.reply(409, {
            'error': {
              'code': 'CONFLICT',
              'message': 'This item has already been decided.',
            },
          }),
        );

        try {
          await repository.approve(7);
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.response?.statusCode, 409);
          expect(e.error, isA<UnknownFailure>());
          expect(
            (e.error as UnknownFailure).message,
            'This item has already been decided.',
          );
        }
      },
    );

    test('a 404 (row no longer exists) keeps its status code readable', () async {
      adapter.onPost(
        '/api/v1/moderation/queue/99/approve/',
        (server) => server.reply(404, {
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Moderation queue item not found.',
          },
        }),
      );

      try {
        await repository.approve(99);
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
        expect(e.error, isA<UnknownFailure>());
      }
    });
  });

  group('reject', () {
    test(
      'POSTs {"reason": ...} to the item\'s reject URL and maps the '
      'updated row',
      () async {
        adapter.onPost(
          '/api/v1/moderation/queue/8/reject/',
          (server) => server.reply(200, rowJson(id: 8, status: 'rejected')),
          data: {'reason': 'Contains prohibited content'},
        );

        final item = await repository.reject(
          queueItemId: 8,
          reason: 'Contains prohibited content',
        );

        expect(item.id, 8);
        expect(item.status, QueueItemStatus.rejected);
      },
    );

    test(
      'a blank-reason 400 surfaces as ValidationFailure with the '
      '"reason" field error',
      () async {
        adapter.onPost(
          '/api/v1/moderation/queue/8/reject/',
          (server) => server.reply(400, {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Invalid input',
              'fields': {
                'reason': ['This field may not be blank.'],
              },
            },
          }),
          data: {'reason': ''},
        );

        try {
          await repository.reject(queueItemId: 8, reason: '');
          fail('Expected a DioException to be thrown');
        } on DioException catch (e) {
          expect(e.error, isA<ValidationFailure>());
          expect((e.error as ValidationFailure).fields['reason'], [
            'This field may not be blank.',
          ]);
        }
      },
    );
  });
}