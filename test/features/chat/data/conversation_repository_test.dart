import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';

import 'fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late Dio dio;
  late ConversationRepository repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    repository = ConversationRepository(dio);
  });

  group('listConversations', () {
    test(
      'parses a page of conversations, including a null last_message',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: {
            'results': [
              {
                'id': 1,
                'other_participant': {
                  'id': 42,
                  'account_type': 'business',
                  'display_name': 'Acme Traders',
                },
                'last_message': {
                  'id': 501,
                  'text': 'Is this available?',
                  'sender_id': 7,
                  'status': 'delivered',
                  'created_at': '2026-09-20T10:00:00Z',
                },
                'unread_count': 2,
                'created_at': '2026-09-01T09:00:00Z',
              },
              {
                'id': 2,
                'other_participant': {
                  'id': 43,
                  'account_type': 'customer',
                  'display_name': 'jane@example.com',
                },
                'last_message': null,
                'unread_count': 0,
                'created_at': '2026-09-21T09:00:00Z',
              },
            ],
            'next': 'http://test.local/api/v1/conversations/?cursor=abc',
            'previous': null,
          },
        );

        final page = await repository.listConversations();

        expect(page.results, hasLength(2));
        expect(
          page.next,
          'http://test.local/api/v1/conversations/?cursor=abc',
        );

        final first = page.results[0];
        expect(first.id, 1);
        expect(first.otherParticipant?.displayName, 'Acme Traders');
        expect(first.lastMessage?.status, MessageStatus.delivered);
        expect(first.unreadCount, 2);

        final second = page.results[1];
        expect(second.lastMessage, isNull);

        expect(
          adapter.requestedOptions.single.path,
          '/api/v1/conversations/',
        );
      },
    );

    test('falls back to MessageStatus.unknown for an unrecognized status '
        'string rather than throwing', () async {
      adapter.enqueue(
        statusCode: 200,
        data: {
          'results': [
            {
              'id': 1,
              'other_participant': {
                'id': 42,
                'account_type': 'business',
                'display_name': 'Acme Traders',
              },
              'last_message': {
                'id': 501,
                'text': 'hi',
                'sender_id': 7,
                'status': 'archived', // not a real backend status
                'created_at': '2026-09-20T10:00:00Z',
              },
              'unread_count': 0,
              'created_at': '2026-09-01T09:00:00Z',
            },
          ],
          'next': null,
          'previous': null,
        },
      );

      final page = await repository.listConversations();

      expect(page.results.single.lastMessage?.status, MessageStatus.unknown);
    });

    test(
      'defensive fallback: a null other_participant does not crash the parse',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: {
            'results': [
              {
                'id': 1,
                'other_participant': null,
                'last_message': null,
                'unread_count': 0,
                'created_at': '2026-09-01T09:00:00Z',
              },
            ],
            'next': null,
            'previous': null,
          },
        );

        final page = await repository.listConversations();

        expect(page.results.single.otherParticipant, isNull);
      },
    );

    test('fetches the next page via the opaque cursor URL verbatim', () async {
      const cursorUrl = 'http://test.local/api/v1/conversations/?cursor=abc';
      adapter.enqueue(
        statusCode: 200,
        data: {
          'results': <Map<String, dynamic>>[],
          'next': null,
          'previous': cursorUrl,
        },
      );

      await repository.listConversations(cursor: cursorUrl);

      expect(adapter.requestedOptions.single.path, cursorUrl);
    });

    test('a 403 surfaces as AuthFailure, not a raw DioException', () async {
      adapter.enqueue(
        statusCode: 403,
        data: {
          'error': {'code': 'FORBIDDEN', 'message': 'Nope.'},
        },
      );

      await expectLater(
        repository.listConversations(),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('a 500 surfaces as ServerFailure', () async {
      adapter.enqueue(
        statusCode: 500,
        data: {
          'error': {'code': 'SERVER_ERROR', 'message': 'boom'},
        },
      );

      await expectLater(
        repository.listConversations(),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('startConversation', () {
    test(
      'returns only the id from the plain ConversationSerializer shape',
      () async {
        adapter.enqueue(
          statusCode: 201,
          data: {
            'id': 9,
            'created_at': '2026-09-27T09:00:00Z',
            'updated_at': '2026-09-27T09:00:00Z',
            'participant_ids': [1, 2],
          },
        );

        final id = await repository.startConversation(recipientId: 2);

        expect(id, 9);
        final sent = adapter.requestedOptions.single;
        expect(sent.method, 'POST');
        expect(sent.path, '/api/v1/conversations/start/');
        expect(sent.data, {'recipient_id': 2});
      },
    );

    test(
      'returns the id of an existing conversation too (200, not just 201)',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: {
            'id': 4,
            'created_at': '2026-09-01T09:00:00Z',
            'updated_at': '2026-09-27T09:00:00Z',
            'participant_ids': [1, 2],
          },
        );

        final id = await repository.startConversation(recipientId: 2);

        expect(id, 4);
      },
    );

    test('a 400 (e.g. self-conversation) surfaces as ValidationFailure', () async {
      adapter.enqueue(
        statusCode: 400,
        data: {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Cannot start a conversation with yourself.',
          },
        },
      );

      await expectLater(
        repository.startConversation(recipientId: 1),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('fetchMessageHistory', () {
    test(
      'parses a paginated page of messages without reversing it',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: {
            'results': [
              {
                'id': 10,
                'conversation': 5,
                'sender': 1,
                'text': 'newest',
                'status': 'read',
                'created_at': '2026-09-27T10:00:00Z',
              },
              {
                'id': 9,
                'conversation': 5,
                'sender': 2,
                'text': 'older',
                'status': 'read',
                'created_at': '2026-09-27T09:00:00Z',
              },
            ],
            'next': null,
            'previous': null,
          },
        );

        final page = await repository.fetchMessageHistory(5);

        expect(page.results.map((m) => m.id), [10, 9]);
        expect(
          adapter.requestedOptions.single.path,
          '/api/v1/conversations/5/messages/',
        );
      },
    );

    test('fetches the next page via the opaque cursor URL verbatim', () async {
      const cursorUrl =
          'http://test.local/api/v1/conversations/5/messages/?cursor=xyz';
      adapter.enqueue(
        statusCode: 200,
        data: {
          'results': <Map<String, dynamic>>[],
          'next': null,
          'previous': cursorUrl,
        },
      );

      await repository.fetchMessageHistory(5, cursor: cursorUrl);

      expect(adapter.requestedOptions.single.path, cursorUrl);
    });

    test(
      'a 404 for an unknown conversation surfaces as UnknownFailure',
      () async {
        adapter.enqueue(
          statusCode: 404,
          data: {
            'error': {
              'code': 'NOT_FOUND',
              'message': 'Conversation not found.',
            },
          },
        );

        await expectLater(
          repository.fetchMessageHistory(999),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );

    test(
      'a 403 for a non-participant surfaces as AuthFailure',
      () async {
        adapter.enqueue(
          statusCode: 403,
          data: {
            'error': {
              'code': 'FORBIDDEN',
              'message': 'You are not a participant of this conversation.',
            },
          },
        );

        await expectLater(
          repository.fetchMessageHistory(5),
          throwsA(isA<AuthFailure>()),
        );
      },
    );
  });
}