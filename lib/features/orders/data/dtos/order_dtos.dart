import '../../domain/order.dart';
import '../../domain/order_note.dart';
import '../../domain/order_status.dart';
import '../../domain/order_status_event.dart';

DateTime? _dateOrNull(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

/// Wire shape of an order. Two factories because the backend has two
/// serializers: `MerchantOrderSerializer` and `CustomerOrderSerializer`.
class OrderDto {
  const OrderDto({
    required this.id,
    required this.orderNumber,
    required this.conversationId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.agreedUnitPrice,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.customerName,
    this.businessId,
    this.businessName,
    this.sourceMessageId,
    this.allowedNextStatuses = const <String>[],
    this.customerNote = '',
    this.internalNote,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final String orderNumber;
  final int conversationId;
  final int productId;
  final String productName;
  final int quantity;
  final String agreedUnitPrice;
  final String totalAmount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? customerId;
  final String? customerName;
  final int? businessId;
  final String? businessName;
  final int? sourceMessageId;
  final List<String> allowedNextStatuses;
  final String customerNote;
  final String? internalNote;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// `MerchantOrderSerializer`:
  /// `{id, order_number, customer{id,display_name}, conversation,
  /// source_message, product{id,name}, quantity, agreed_unit_price,
  /// total_amount, currency, status, allowed_next_statuses, customer_note,
  /// internal_note, created_at, updated_at, confirmed_at, completed_at,
  /// cancelled_at}`.
  factory OrderDto.fromMerchantJson(Map<String, dynamic> json) {
    final Map<String, dynamic> product =
        json['product'] as Map<String, dynamic>;
    final Object? customerRaw = json['customer'];
    final Map<String, dynamic>? customer =
        customerRaw is Map<String, dynamic> ? customerRaw : null;
    final Object? next = json['allowed_next_statuses'];
    return OrderDto(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      conversationId: json['conversation'] as int,
      sourceMessageId: json['source_message'] as int?,
      productId: product['id'] as int,
      productName: product['name'] as String,
      customerId: customer?['id'] as int?,
      customerName: customer?['display_name'] as String?,
      quantity: json['quantity'] as int,
      agreedUnitPrice: '${json['agreed_unit_price']}',
      totalAmount: '${json['total_amount']}',
      currency: json['currency'] as String,
      status: json['status'] as String,
      allowedNextStatuses:
          next is List ? next.whereType<String>().toList() : const <String>[],
      customerNote: json['customer_note'] as String? ?? '',
      internalNote: json['internal_note'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      confirmedAt: _dateOrNull(json['confirmed_at']),
      completedAt: _dateOrNull(json['completed_at']),
      cancelledAt: _dateOrNull(json['cancelled_at']),
    );
  }

  /// `CustomerOrderSerializer`: same money / date fields, `business` instead
  /// of `customer`, and NO internal note. `internal_note` is deliberately
  /// never read here, so it cannot leak even if a server returned it.
  factory OrderDto.fromCustomerJson(Map<String, dynamic> json) {
    final Map<String, dynamic> product =
        json['product'] as Map<String, dynamic>;
    final Object? businessRaw = json['business'];
    final Map<String, dynamic>? business =
        businessRaw is Map<String, dynamic> ? businessRaw : null;
    return OrderDto(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      conversationId: json['conversation'] as int,
      productId: product['id'] as int,
      productName: product['name'] as String,
      businessId: business?['id'] as int?,
      businessName: business?['business_name'] as String?,
      quantity: json['quantity'] as int,
      agreedUnitPrice: '${json['agreed_unit_price']}',
      totalAmount: '${json['total_amount']}',
      currency: json['currency'] as String,
      status: json['status'] as String,
      customerNote: json['customer_note'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      confirmedAt: _dateOrNull(json['confirmed_at']),
      completedAt: _dateOrNull(json['completed_at']),
      cancelledAt: _dateOrNull(json['cancelled_at']),
    );
  }

  Order toEntity() {
    return Order(
      id: id,
      orderNumber: orderNumber,
      conversationId: conversationId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      agreedUnitPrice: agreedUnitPrice,
      totalAmount: totalAmount,
      currency: currency,
      status: OrderStatus.fromRaw(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      customerId: customerId,
      customerName: customerName,
      businessId: businessId,
      businessName: businessName,
      sourceMessageId: sourceMessageId,
      allowedNextStatuses: allowedNextStatuses
          .map(OrderStatus.fromRaw)
          .where((OrderStatus s) => s != OrderStatus.unknown)
          .toList(growable: false),
      customerNote: customerNote,
      internalNote: internalNote,
      confirmedAt: confirmedAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
    );
  }
}

/// Wire shape of an order event (`MerchantOrderEventSerializer` /
/// `CustomerOrderEventSerializer`). The customer serializer has no
/// `is_internal` key, which parses as `false`.
class OrderEventDto {
  const OrderEventDto({
    required this.id,
    required this.eventType,
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.isInternal,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final String fromStatus;
  final String toStatus;
  final String note;
  final bool isInternal;
  final DateTime createdAt;

  factory OrderEventDto.fromJson(Map<String, dynamic> json) {
    return OrderEventDto(
      id: json['id'] as int,
      eventType: json['event_type'] as String,
      fromStatus: json['from_status'] as String? ?? '',
      toStatus: json['to_status'] as String? ?? '',
      note: json['note'] as String? ?? '',
      isInternal: json['is_internal'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  OrderNote toNote() => OrderNote(
    id: id,
    note: note,
    isInternal: isInternal,
    createdAt: createdAt,
  );

  OrderStatusEvent toStatusEvent() => OrderStatusEvent(
    id: id,
    type: OrderEventType.fromRaw(eventType),
    fromStatus: fromStatus.isEmpty ? null : OrderStatus.fromRaw(fromStatus),
    toStatus: toStatus.isEmpty ? null : OrderStatus.fromRaw(toStatus),
    note: note,
    createdAt: createdAt,
  );
}

/// Splits events into timeline + notes. With [customerView] every internal
/// event is dropped, so an internal note never reaches a customer-side UI
/// even if the API returned it.
OrderEvents mapOrderEvents(
  Iterable<OrderEventDto> dtos, {
  bool customerView = false,
}) {
  final List<OrderStatusEvent> timeline = <OrderStatusEvent>[];
  final List<OrderNote> notes = <OrderNote>[];
  for (final OrderEventDto dto in dtos) {
    if (customerView && dto.isInternal) continue;
    if (OrderEventType.fromRaw(dto.eventType) == OrderEventType.noteAdded) {
      notes.add(dto.toNote());
    } else {
      timeline.add(dto.toStatusEvent());
    }
  }
  return OrderEvents(timeline: timeline, notes: notes);
}
