import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/orders/data/dtos/order_dtos.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/domain/order_status_event.dart';
import 'package:social_commerce_app/features/orders/domain/order_summary.dart';

Map<String, dynamic> merchantJson({
  String status = 'pending',
  Object? unitPrice = '199.50',
  Object? customer = const <String, dynamic>{'id': 9, 'display_name': 'Sara'},
  Object? sourceMessage = 77,
  Object? nextStatuses = const <String>['confirmed', 'cancelled'],
}) => <String, dynamic>{
  'id': 5,
  'order_number': 'ORD-5',
  'customer': customer,
  'conversation': 42,
  'source_message': sourceMessage,
  'product': <String, dynamic>{'id': 10, 'name': 'Cotton T-Shirt'},
  'quantity': 3,
  'agreed_unit_price': unitPrice,
  'total_amount': '598.50',
  'currency': 'EGP',
  'status': status,
  'allowed_next_statuses': nextStatuses,
  'customer_note': 'Thanks',
  'internal_note': 'VIP buyer',
  'created_at': '2026-11-18T12:05:00Z',
  'updated_at': '2026-11-18T12:06:00Z',
  'confirmed_at': null,
  'completed_at': null,
  'cancelled_at': null,
};

Map<String, dynamic> customerJson() => <String, dynamic>{
  'id': 5,
  'order_number': 'ORD-5',
  'business': <String, dynamic>{'id': 7, 'business_name': 'Al Anaqa'},
  'conversation': 42,
  'product': <String, dynamic>{'id': 10, 'name': 'Cotton T-Shirt'},
  'quantity': 3,
  'agreed_unit_price': '199.50',
  'total_amount': '598.50',
  'currency': 'EGP',
  'status': 'confirmed',
  'customer_note': 'Thanks',
  // A misbehaving server: the app must never surface this.
  'internal_note': 'LEAK',
  'created_at': '2026-11-18T12:05:00Z',
  'updated_at': '2026-11-18T12:06:00Z',
  'confirmed_at': '2026-11-18T12:30:00Z',
};

Map<String, dynamic> eventJson(
  int id,
  String type, {
  String from = '',
  String to = '',
  String note = '',
  bool? internal,
}) => <String, dynamic>{
  'id': id,
  'event_type': type,
  'from_status': from,
  'to_status': to,
  'note': note,
  if (internal != null) 'is_internal': internal,
  'created_at': '2026-11-18T12:0$id:00Z',
};

void main() {
  group('OrderDto.fromMerchantJson', () {
    test('parses every merchant field into the entity', () {
      final order = OrderDto.fromMerchantJson(merchantJson()).toEntity();

      expect(order.id, 5);
      expect(order.orderNumber, 'ORD-5');
      expect(order.conversationId, 42);
      expect(order.sourceMessageId, 77);
      expect(order.productId, 10);
      expect(order.productName, 'Cotton T-Shirt');
      expect(order.customerId, 9);
      expect(order.customerName, 'Sara');
      expect(order.quantity, 3);
      expect(order.agreedUnitPrice, '199.50');
      expect(order.totalAmount, '598.50');
      expect(order.currency, 'EGP');
      expect(order.status, OrderStatus.pending);
      expect(order.allowedNextStatuses, <OrderStatus>[
        OrderStatus.confirmed,
        OrderStatus.cancelled,
      ]);
      expect(order.customerNote, 'Thanks');
      expect(order.internalNote, 'VIP buyer');
      expect(order.createdAt, DateTime.utc(2026, 11, 18, 12, 5));
      expect(order.confirmedAt, isNull);
      expect(order.businessId, isNull);
    });

    test('keeps money exactly as sent, even when it is a JSON number', () {
      final order =
          OrderDto.fromMerchantJson(merchantJson(unitPrice: 199.5)).toEntity();
      expect(order.agreedUnitPrice, '199.5');
    });

    test('null customer and null source_message do not break parsing', () {
      final order =
          OrderDto.fromMerchantJson(
            merchantJson(customer: null, sourceMessage: null),
          ).toEntity();
      expect(order.customerId, isNull);
      expect(order.customerName, isNull);
      expect(order.sourceMessageId, isNull);
    });

    test('an unknown status maps to unknown, and unknown next statuses are '
        'dropped', () {
      final order =
          OrderDto.fromMerchantJson(
            merchantJson(
              status: 'weird',
              nextStatuses: <String>['confirmed', 'weird'],
            ),
          ).toEntity();
      expect(order.status, OrderStatus.unknown);
      expect(order.allowedNextStatuses, <OrderStatus>[OrderStatus.confirmed]);
    });

    test('missing allowed_next_statuses parses to an empty list', () {
      final order =
          OrderDto.fromMerchantJson(
            merchantJson(nextStatuses: null),
          ).toEntity();
      expect(order.allowedNextStatuses, isEmpty);
    });
  });

  group('OrderDto.fromCustomerJson', () {
    test('reads the business and NEVER an internal note', () {
      final order = OrderDto.fromCustomerJson(customerJson()).toEntity();

      expect(order.businessId, 7);
      expect(order.businessName, 'Al Anaqa');
      expect(order.customerName, isNull);
      expect(order.status, OrderStatus.confirmed);
      expect(order.confirmedAt, DateTime.utc(2026, 11, 18, 12, 30));
      expect(order.allowedNextStatuses, isEmpty);
      expect(order.internalNote, isNull, reason: 'internal_note must not leak');
    });
  });

  group('order events', () {
    final List<OrderEventDto> dtos = <OrderEventDto>[
      OrderEventDto.fromJson(eventJson(1, 'created', to: 'pending')),
      OrderEventDto.fromJson(
        eventJson(
          2,
          'status_changed',
          from: 'pending',
          to: 'confirmed',
          note: 'Ships Sunday',
        ),
      ),
      OrderEventDto.fromJson(
        eventJson(3, 'note_added', note: 'SECRET', internal: true),
      ),
      OrderEventDto.fromJson(
        eventJson(4, 'note_added', note: 'Visible', internal: false),
      ),
    ];

    test('a payload without is_internal parses as not internal', () {
      expect(
        OrderEventDto.fromJson(
          eventJson(4, 'note_added', note: 'x'),
        ).isInternal,
        isFalse,
      );
    });

    test('merchant view: timeline and notes are split, internal kept', () {
      final events = mapOrderEvents(dtos);
      expect(events.timeline.map((e) => e.id), <int>[1, 2]);
      expect(events.notes.map((n) => n.id), <int>[3, 4]);
      expect(events.notes.first.isInternal, isTrue);
      expect(events.timeline[1].fromStatus, OrderStatus.pending);
      expect(events.timeline[1].toStatus, OrderStatus.confirmed);
      expect(events.timeline[1].note, 'Ships Sunday');
    });

    test('customer view: every internal event is dropped', () {
      final events = mapOrderEvents(dtos, customerView: true);
      expect(events.notes.map((n) => n.note), <String>['Visible']);
      expect(events.notes.any((n) => n.isInternal), isFalse);
      expect(events.timeline, hasLength(2));
    });

    test('empty from/to status parse to null; an unknown type stays in the '
        'timeline as unknown', () {
      final events = mapOrderEvents(<OrderEventDto>[
        OrderEventDto.fromJson(eventJson(1, 'created', to: 'pending')),
        OrderEventDto.fromJson(eventJson(2, 'brand_new_type')),
      ]);
      expect(events.timeline[0].fromStatus, isNull);
      expect(events.timeline[0].toStatus, OrderStatus.pending);
      expect(events.timeline[1].type, OrderEventType.unknown);
    });
  });

  group('OrderStatus', () {
    test('fromRaw maps the six wire values and falls back to unknown', () {
      for (final OrderStatus s in OrderStatus.lifecycle) {
        expect(OrderStatus.fromRaw(s.raw), s);
      }
      expect(OrderStatus.fromRaw(null), OrderStatus.unknown);
      expect(OrderStatus.fromRaw(''), OrderStatus.unknown);
      expect(OrderStatus.fromRaw('nope'), OrderStatus.unknown);
    });

    test('lifecycle has the six real statuses and terminal ones are right', () {
      expect(OrderStatus.lifecycle, hasLength(6));
      expect(OrderStatus.lifecycle, isNot(contains(OrderStatus.unknown)));
      expect(OrderStatus.delivered.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.pending.isTerminal, isFalse);
    });
  });

  group('OrderSummary.tryParse (chat message order key)', () {
    test('parses a valid payload', () {
      final s = OrderSummary.tryParse(<String, dynamic>{
        'id': 5,
        'order_number': 'ORD-5',
        'status': 'shipped',
        'quantity': 2,
        'agreed_unit_price': '10.00',
        'total_amount': '20.00',
        'currency': 'EGP',
        'product_id': 10,
        'created_at': '2026-11-18T12:05:00Z',
      });
      expect(s, isNotNull);
      expect(s!.orderNumber, 'ORD-5');
      expect(s.status, OrderStatus.shipped);
      expect(s.totalAmount, '20.00');
      expect(s.productId, 10);
      expect(s.createdAt, DateTime.utc(2026, 11, 18, 12, 5));
    });

    test('a missing order_number falls back to ORD-<id>', () {
      final s = OrderSummary.tryParse(<String, dynamic>{
        'id': 8,
        'status': 'pending',
        'quantity': 1,
      });
      expect(s!.orderNumber, 'ORD-8');
    });

    test('anything unrecognizable is null instead of throwing', () {
      expect(OrderSummary.tryParse(null), isNull);
      expect(OrderSummary.tryParse('x'), isNull);
      expect(OrderSummary.tryParse(<String, dynamic>{'id': '5'}), isNull);
      expect(
        OrderSummary.tryParse(<String, dynamic>{
          'id': 5,
          'quantity': 1,
          'status': 3,
        }),
        isNull,
      );
    });

    test('equal payloads are equal', () {
      Map<String, dynamic> raw() => <String, dynamic>{
        'id': 5,
        'status': 'pending',
        'quantity': 1,
      };
      expect(OrderSummary.tryParse(raw()), OrderSummary.tryParse(raw()));
      expect(
        OrderSummary.tryParse(raw())!.hashCode,
        OrderSummary.tryParse(raw())!.hashCode,
      );
    });
  });

  group('Message.fromJson backward compatibility (order key)', () {
    Map<String, dynamic> base() => <String, dynamic>{
      'id': 77,
      'conversation': 42,
      'sender': 1,
      'text': 'hi',
      'status': 'sent',
      'created_at': '2026-11-18T12:00:00Z',
    };

    test('an old payload without order parses with order == null', () {
      expect(Message.fromJson(base()).order, isNull);
    });

    test('a null or garbage order is null, never a crash', () {
      expect(Message.fromJson(base()..['order'] = null).order, isNull);
      expect(Message.fromJson(base()..['order'] = 'garbage').order, isNull);
    });

    test('a valid order is parsed, kept by copyWithStatus and by equality', () {
      final json =
          base()
            ..['order'] = <String, dynamic>{
              'id': 5,
              'status': 'pending',
              'quantity': 1,
            };
      final message = Message.fromJson(json);
      expect(message.order?.id, 5);
      expect(message.order?.status, OrderStatus.pending);
      expect(message, Message.fromJson(json));
      expect(message.hashCode, Message.fromJson(json).hashCode);
      expect(message.copyWithStatus(message.status).order, message.order);
      expect(message, isNot(Message.fromJson(base())));
    });
  });
}
