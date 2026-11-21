import 'order_note.dart';
import 'order_status.dart';

/// Backend `OrderEventType`.
enum OrderEventType {
  created('created'),
  statusChanged('status_changed'),
  noteAdded('note_added'),
  unknown('');

  const OrderEventType(this.raw);

  final String raw;

  static OrderEventType fromRaw(String? raw) {
    for (final OrderEventType type in OrderEventType.values) {
      if (type != OrderEventType.unknown && type.raw == raw) return type;
    }
    return OrderEventType.unknown;
  }
}

/// Part BI-03 — one timeline entry (`created` or `status_changed`).
/// [note] is the customer-visible note that came with a status change.
class OrderStatusEvent {
  const OrderStatusEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    this.fromStatus,
    this.toStatus,
    this.note = '',
  });

  final int id;
  final OrderEventType type;
  final OrderStatus? fromStatus;
  final OrderStatus? toStatus;
  final String note;
  final DateTime createdAt;
}

/// The events of an order split into the two things the UI shows: the
/// [timeline] (oldest first, as the server sends it) and the [notes].
class OrderEvents {
  const OrderEvents({
    this.timeline = const <OrderStatusEvent>[],
    this.notes = const <OrderNote>[],
  });

  final List<OrderStatusEvent> timeline;
  final List<OrderNote> notes;
}
