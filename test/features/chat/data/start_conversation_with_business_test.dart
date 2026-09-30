import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';

import 'fake_http_client_adapter.dart';

/// Part P-077 STEP 5B — `startConversationWithBusiness`: the request
/// shape (`business_id`, not `recipient_id`), resolving the real
/// [Conversation] from the conversation list, and the failure paths.

Map<String, dynamic> _startResponse(int id) => {
  'id': id,
  'created_at': '2026-09-29T09:00:00Z',
  'updated_at': '2026-09-29T09:00:00Z',
  'participant_ids': [1, 42],
};

Map<String, dynamic> _listRow(int id, int otherId, String name) => {
  'id': id,
  'other_participant': {
    'id': otherId,
    'account_type': 'business',
    'display_name': name,
  },
  'last_message': null,
  'unread_count': 0,
  'created_at': '2026-09-29T09:00:00Z',
};

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

  test('POSTs business_id, then returns the matching real Conversation', () async {
    adapter.enqueue(statusCode: 201, data: _startResponse(9));
    adapter.enqueue(
      statusCode: 200,
      data: [_listRow(3, 50, 'Other Shop'), _listRow(9, 42, 'Al Anaqa Store')],
    );

    final conversation = await repository.startConversationWithBusiness(
      businessId: 7,
    );

    final start = adapter.requestedOptions[0];
    expect(start.method, 'POST');
    expect(start.path, '/api/v1/conversations/start/');
    expect(start.data, {'business_id': 7});

    final list = adapter.requestedOptions[1];
    expect(list.method, 'GET');
    expect(list.path, '/api/v1/conversations/');

    expect(conversation, isNotNull);
    expect(conversation!.id, 9);
    expect(conversation.otherParticipant!.id, 42);
    expect(conversation.otherParticipant!.displayName, 'Al Anaqa Store');
  });

  test('returns null when the started conversation is not in the list', () async {
    adapter.enqueue(statusCode: 200, data: _startResponse(9));
    adapter.enqueue(statusCode: 200, data: [_listRow(3, 50, 'Other Shop')]);

    final conversation = await repository.startConversationWithBusiness(
      businessId: 7,
    );

    expect(conversation, isNull);
  });

  test('a 400 surfaces as ValidationFailure and the list is never fetched', () async {
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
      repository.startConversationWithBusiness(businessId: 7),
      throwsA(isA<ValidationFailure>()),
    );
    expect(adapter.requestedOptions, hasLength(1));
  });
}