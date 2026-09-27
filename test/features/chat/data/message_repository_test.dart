import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/message_repository.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';

import 'fake_http_client_adapter.dart';

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

  group('sendMessage', () {
    test(
      'POSTs {text} and parses the persisted Message, status "sent"',
      () async {
        adapter.enqueue(
          statusCode: 201,
          data: {
            'id': 55,
            'conversation': 5,
            'sender': 1,
            'text': 'hello there',
            'status': 'sent',
            'created_at': '2026-09-27T11:00:00Z',
          },
        );

        final message = await repository.sendMessage(
          conversationId: 5,
          text: 'hello there',
        );

        expect(message.id, 55);
        expect(message.conversationId, 5);
        expect(message.senderId, 1);
        expect(message.status, MessageStatus.sent);

        final sent = adapter.requestedOptions.single;
        expect(sent.method, 'POST');
        expect(sent.path, '/api/v1/conversations/5/messages/');
        expect(sent.data, {'text': 'hello there'});
      },
    );

    test(
      'a 403 (not a participant) surfaces as AuthFailure',
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
          repository.sendMessage(conversationId: 5, text: 'hi'),
          throwsA(isA<AuthFailure>()),
        );
      },
    );

    test('a 404 for an unknown conversation surfaces as UnknownFailure', () async {
      adapter.enqueue(
        statusCode: 404,
        data: {
          'error': {'code': 'NOT_FOUND', 'message': 'Conversation not found.'},
        },
      );

      await expectLater(
        repository.sendMessage(conversationId: 999, text: 'hi'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('fetchMessagesSince', () {
    test(
      'parses a plain JSON array (not a paginated envelope)',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: [
            {
              'id': 20,
              'conversation': 5,
              'sender': 2,
              'text': 'missed while away',
              'status': 'sent',
              'created_at': '2026-09-27T12:00:00Z',
            },
            {
              'id': 21,
              'conversation': 5,
              'sender': 2,
              'text': 'second missed message',
              'status': 'sent',
              'created_at': '2026-09-27T12:01:00Z',
            },
          ],
        );

        final messages = await repository.fetchMessagesSince(
          conversationId: 5,
          sinceMessageId: 19,
        );

        expect(messages.map((m) => m.id), [20, 21]);

        final sent = adapter.requestedOptions.single;
        expect(sent.method, 'GET');
        expect(sent.path, '/api/v1/conversations/5/messages/');
        expect(sent.queryParameters, {'since': 19});
      },
    );

    test('an empty result set parses to an empty list, not an error', () async {
      adapter.enqueue(statusCode: 200, data: <Map<String, dynamic>>[]);

      final messages = await repository.fetchMessagesSince(
        conversationId: 5,
        sinceMessageId: 999,
      );

      expect(messages, isEmpty);
    });

    test(
      'a 400 (missing/non-integer since, surfaced by the backend) '
      'maps to ValidationFailure',
      () async {
        adapter.enqueue(
          statusCode: 400,
          data: {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Must be an integer message id.',
              'fields': {
                'since': ['Must be an integer message id.'],
              },
            },
          },
        );

        await expectLater(
          repository.fetchMessagesSince(conversationId: 5, sinceMessageId: 1),
          throwsA(
            isA<ValidationFailure>().having(
              (f) => f.fields['since'],
              'fields[since]',
              ['Must be an integer message id.'],
            ),
          ),
        );
      },
    );
  });
}