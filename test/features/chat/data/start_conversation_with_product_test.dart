import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';

import 'fake_http_client_adapter.dart';

/// Part BI-03: `startConversationWithBusiness(productId:)` sends
/// `business_id` + `product_id`, the old call without a product is
/// byte-for-byte unchanged, and an already-existing conversation (HTTP 200)
/// is opened instead of a new one.

Map<String, dynamic> _start(int id) => {
  'id': id,
  'created_at': '2026-11-18T09:00:00Z',
  'updated_at': '2026-11-18T09:00:00Z',
  'participant_ids': [1, 42],
};

Map<String, dynamic> _row(int id) => {
  'id': id,
  'other_participant': {
    'id': 42,
    'account_type': 'business',
    'display_name': 'Al Anaqa Store',
  },
  'last_message': null,
  'unread_count': 0,
  'created_at': '2026-11-18T09:00:00Z',
};

void main() {
  late FakeHttpClientAdapter adapter;
  late ConversationRepository repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    final dio =
        Dio(BaseOptions(baseUrl: 'http://test.local'))
          ..httpClientAdapter = adapter
          ..interceptors.add(ErrorInterceptor());
    repository = ConversationRepository(dio);
  });

  test(
    'sends business_id AND product_id, and resolves the conversation',
    () async {
      adapter.enqueue(statusCode: 201, data: _start(9));
      adapter.enqueue(statusCode: 200, data: [_row(9)]);

      final conversation = await repository.startConversationWithBusiness(
        businessId: 7,
        productId: 10,
      );

      expect(adapter.requestedOptions[0].data, {
        'business_id': 7,
        'product_id': 10,
      });
      expect(conversation!.id, 9);
    },
  );

  test('without a product the body is exactly {business_id}', () async {
    adapter.enqueue(statusCode: 201, data: _start(9));
    adapter.enqueue(statusCode: 200, data: [_row(9)]);

    await repository.startConversationWithBusiness(businessId: 7);

    expect(adapter.requestedOptions[0].data, {'business_id': 7});
  });

  test('an existing conversation (200) is opened, not duplicated', () async {
    adapter.enqueue(statusCode: 201, data: _start(9));
    adapter.enqueue(statusCode: 200, data: [_row(9)]);
    adapter.enqueue(statusCode: 200, data: _start(9));
    adapter.enqueue(statusCode: 200, data: [_row(9)]);

    final first = await repository.startConversationWithBusiness(
      businessId: 7,
      productId: 10,
    );
    final second = await repository.startConversationWithBusiness(
      businessId: 7,
      productId: 11,
    );

    expect(second!.id, first!.id);
  });
}
