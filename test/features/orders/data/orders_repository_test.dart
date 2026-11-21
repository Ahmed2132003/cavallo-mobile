import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/orders/data/orders_repository.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/presentation/order_error_text.dart';

import '../../chat/data/fake_http_client_adapter.dart';
import '../orders_test_helpers.dart';
import 'order_dtos_test.dart' show merchantJson, customerJson, eventJson;

void main() {
  late FakeHttpClientAdapter adapter;
  late OrdersRepository repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();
    final dio =
        Dio(BaseOptions(baseUrl: 'http://test.local'))
          ..httpClientAdapter = adapter
          ..interceptors.add(ErrorInterceptor());
    repository = OrdersRepository(dio);
  });

  group('createFromChat', () {
    test('POSTs exactly the six allowed fields; 201 means created', () async {
      adapter.enqueue(statusCode: 201, data: merchantJson());

      final result = await repository.createFromChat(
        conversationId: 42,
        sourceMessageId: 77,
        quantity: 3,
        agreedUnitPrice: '199.50',
        customerNote: 'Thanks',
        internalNote: 'VIP',
      );

      expect(result.created, isTrue);
      expect(result.order.orderNumber, 'ORD-5');

      final sent = adapter.requestedOptions.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/orders/from-chat/');
      expect(sent.data, <String, dynamic>{
        'conversation_id': 42,
        'source_message_id': 77,
        'quantity': 3,
        'agreed_unit_price': '199.50',
        'customer_note': 'Thanks',
        'internal_note': 'VIP',
      });
    });

    test('notes default to empty strings', () async {
      adapter.enqueue(statusCode: 201, data: merchantJson());
      await repository.createFromChat(
        conversationId: 1,
        sourceMessageId: 2,
        quantity: 1,
        agreedUnitPrice: '1.00',
      );
      final data = adapter.requestedOptions.single.data as Map;
      expect(data['customer_note'], '');
      expect(data['internal_note'], '');
    });

    test('a repeat answered with 200 returns the SAME order, created=false '
        '(retry never duplicates)', () async {
      adapter.enqueue(statusCode: 201, data: merchantJson());
      adapter.enqueue(statusCode: 200, data: merchantJson());

      Future<CreatedOrderResult> send() => repository.createFromChat(
        conversationId: 42,
        sourceMessageId: 77,
        quantity: 3,
        agreedUnitPrice: '199.50',
      );

      final first = await send();
      final second = await send();

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.order.id, first.order.id);
      expect(
        adapter.requestedOptions[1].data,
        adapter.requestedOptions[0].data,
      );
    });

    test(
      'a 400 surfaces as ValidationFailure with the server field message',
      () async {
        adapter.enqueue(
          statusCode: 400,
          data: <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'VALIDATION_ERROR',
              'message': 'Invalid.',
              'fields': <String, dynamic>{
                'agreed_unit_price': <String>['Not your product.'],
              },
            },
          },
        );

        await expectLater(
          repository.createFromChat(
            conversationId: 42,
            sourceMessageId: 77,
            quantity: 1,
            agreedUnitPrice: '1.00',
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (f) => f.fields['agreed_unit_price'],
              'fields',
              <String>['Not your product.'],
            ),
          ),
        );
      },
    );

    test('a 403 surfaces as AuthFailure', () async {
      adapter.enqueue(
        statusCode: 403,
        data: <String, dynamic>{
          'error': <String, dynamic>{'code': 'FORBIDDEN', 'message': 'No.'},
        },
      );
      await expectLater(
        repository.createFromChat(
          conversationId: 1,
          sourceMessageId: 2,
          quantity: 1,
          agreedUnitPrice: '1.00',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('listOrders', () {
    test('sends status and trimmed search as query parameters', () async {
      adapter.enqueue(statusCode: 200, data: <Map<String, dynamic>>[]);
      await repository.listOrders(
        status: OrderStatus.pending,
        search: '  ORD-42 ',
      );
      final sent = adapter.requestedOptions.single;
      expect(sent.path, '/api/v1/orders/');
      expect(sent.queryParameters, <String, dynamic>{
        'status': 'pending',
        'search': 'ORD-42',
      });
    });

    test('unknown status and blank search send nothing', () async {
      adapter.enqueue(statusCode: 200, data: <Map<String, dynamic>>[]);
      await repository.listOrders(status: OrderStatus.unknown, search: '  ');
      expect(adapter.requestedOptions.single.queryParameters, isEmpty);
    });

    test('a plain array is wrapped as a single page', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <Map<String, dynamic>>[merchantJson()],
      );
      final page = await repository.listOrders();
      expect(page.results.single.orderNumber, 'ORD-5');
      expect(page.next, isNull);
    });

    test('a {results,next,previous} envelope is parsed and the cursor is used '
        'verbatim with no filters re-sent', () async {
      const cursor =
          'http://test.local/api/v1/orders/?cursor=abc&status=pending';
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'results': <Map<String, dynamic>>[merchantJson()],
          'next': cursor,
          'previous': null,
        },
      );
      final first = await repository.listOrders(status: OrderStatus.pending);
      expect(first.next, cursor);

      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'results': <Map<String, dynamic>>[],
          'next': null,
          'previous': null,
        },
      );
      await repository.listOrders(
        status: OrderStatus.delivered,
        search: 'x',
        cursor: cursor,
      );
      final second = adapter.requestedOptions[1];
      expect(second.path, cursor);
      expect(second.queryParameters, isEmpty);
    });
  });

  group('merchant order endpoints', () {
    test('fetchOrder GETs /orders/<id>/', () async {
      adapter.enqueue(statusCode: 200, data: merchantJson());
      final order = await repository.fetchOrder(5);
      expect(order.internalNote, 'VIP buyer');
      expect(adapter.requestedOptions.single.path, '/api/v1/orders/5/');
    });

    test('a 404 on fetchOrder surfaces as UnknownFailure', () async {
      adapter.enqueue(
        statusCode: 404,
        data: <String, dynamic>{
          'error': <String, dynamic>{'code': 'NOT_FOUND', 'message': 'Nope.'},
        },
      );
      await expectLater(
        repository.fetchOrder(999),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('fetchOrderEvents keeps internal events for the merchant', () async {
      adapter.enqueue(
        statusCode: 200,
        data: <Map<String, dynamic>>[
          eventJson(1, 'created', to: 'pending'),
          eventJson(2, 'note_added', note: 'secret', internal: true),
        ],
      );
      final events = await repository.fetchOrderEvents(5);
      expect(adapter.requestedOptions.single.path, '/api/v1/orders/5/events/');
      expect(events.timeline, hasLength(1));
      expect(events.notes.single.isInternal, isTrue);
    });

    test(
      'changeStatus sends {status, trimmed note}; a blank note is omitted',
      () async {
        adapter.enqueue(
          statusCode: 200,
          data: merchantJson(status: 'confirmed'),
        );
        final order = await repository.changeStatus(
          orderId: 5,
          status: OrderStatus.confirmed,
          note: '  Ships Sunday ',
        );
        expect(order.status, OrderStatus.confirmed);
        var sent = adapter.requestedOptions.single;
        expect(sent.path, '/api/v1/orders/5/status/');
        expect(sent.data, <String, dynamic>{
          'status': 'confirmed',
          'note': 'Ships Sunday',
        });

        adapter.enqueue(
          statusCode: 200,
          data: merchantJson(status: 'cancelled'),
        );
        await repository.changeStatus(
          orderId: 5,
          status: OrderStatus.cancelled,
          note: '   ',
        );
        sent = adapter.requestedOptions[1];
        expect(sent.data, <String, dynamic>{'status': 'cancelled'});
      },
    );

    test('addNote sends {note, is_internal} and parses the event', () async {
      adapter.enqueue(
        statusCode: 201,
        data: eventJson(3, 'note_added', note: 'Call me', internal: true),
      );
      final note = await repository.addNote(
        orderId: 5,
        note: ' Call me ',
        isInternal: true,
      );
      expect(note.note, 'Call me');
      expect(note.isInternal, isTrue);
      final sent = adapter.requestedOptions.single;
      expect(sent.path, '/api/v1/orders/5/notes/');
      expect(sent.data, <String, dynamic>{
        'note': 'Call me',
        'is_internal': true,
      });
    });
  });

  group('customer order endpoint', () {
    test('fetchMyOrder never exposes internal data', () async {
      final json =
          customerJson()
            ..['events'] = <Map<String, dynamic>>[
              eventJson(1, 'created', to: 'pending'),
              eventJson(2, 'note_added', note: 'SECRET', internal: true),
              eventJson(3, 'note_added', note: 'Visible', internal: false),
            ];
      adapter.enqueue(statusCode: 200, data: json);

      final detail = await repository.fetchMyOrder(5);

      expect(adapter.requestedOptions.single.path, '/api/v1/orders/my/5/');
      expect(detail.order.internalNote, isNull);
      expect(detail.order.businessName, 'Al Anaqa');
      expect(detail.events.notes.map((n) => n.note), <String>['Visible']);
    });

    test('a response without events parses to empty events', () async {
      adapter.enqueue(statusCode: 200, data: customerJson());
      final detail = await repository.fetchMyOrder(5);
      expect(detail.events.timeline, isEmpty);
      expect(detail.events.notes, isEmpty);
    });
  });

  group('orderErrorText', () {
    final en = l10nFor('en');
    final ar = l10nFor('ar');

    test('network failure is localized', () {
      const e = NetworkFailure(message: 'x');
      expect(orderErrorText(en, e), en.ordersErrorNetwork);
      expect(orderErrorText(ar, e), ar.ordersErrorNetwork);
      expect(ar.ordersErrorNetwork, isNot(en.ordersErrorNetwork));
    });

    test('validation failure shows the first server field message', () {
      const e = ValidationFailure(
        message: 'Invalid.',
        fields: <String, List<String>>{
          'quantity': <String>['Too big.'],
        },
      );
      expect(orderErrorText(en, e), 'Too big.');
    });

    test('validation failure without fields shows its message', () {
      const e = ValidationFailure(
        message: 'Not your product.',
        fields: <String, List<String>>{},
      );
      expect(orderErrorText(en, e), 'Not your product.');
    });

    test('anything else is the generic localized message', () {
      expect(
        orderErrorText(en, const ServerFailure(message: 'boom')),
        en.ordersErrorGeneric,
      );
      expect(orderErrorText(en, StateError('x')), en.ordersErrorGeneric);
    });
  });
}
