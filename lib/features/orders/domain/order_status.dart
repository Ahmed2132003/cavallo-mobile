/// Part BI-03 — lifecycle status of a merchant-recorded order.
///
/// Mirrors the backend's `orders.constants.OrderStatus`. [unknown] exists so
/// one unexpected value from the server never breaks parsing of a whole list.
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  processing('processing'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled'),
  unknown('');

  const OrderStatus(this.raw);

  /// The exact wire string (`status` field / `?status=` filter).
  final String raw;

  static OrderStatus fromRaw(String? raw) {
    for (final OrderStatus status in OrderStatus.values) {
      if (status != OrderStatus.unknown && status.raw == raw) return status;
    }
    return OrderStatus.unknown;
  }

  /// `delivered` and `cancelled` have no way out (backend ALLOWED_TRANSITIONS).
  bool get isTerminal =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// The six real statuses in lifecycle order (filter chips, counters).
  static const List<OrderStatus> lifecycle = <OrderStatus>[
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  ];
}
