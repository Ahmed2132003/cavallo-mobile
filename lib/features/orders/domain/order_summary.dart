import 'order_status.dart';

/// Part BI-03 — the order summary embedded in a chat message (`order` key of
/// `MessageSerializer`, built by the backend's `build_order_summary_payload`).
///
/// Viewer-independent by design: it carries no note of any kind, so an
/// internal note can never reach the customer through a chat message.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.quantity,
    required this.agreedUnitPrice,
    required this.totalAmount,
    required this.currency,
    this.productId,
    this.createdAt,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final int quantity;
  final String agreedUnitPrice;
  final String totalAmount;
  final String currency;
  final int? productId;
  final DateTime? createdAt;

  /// Lenient: `null` for anything that is not a recognizable order summary,
  /// so one odd payload never breaks parsing of the whole message / thread.
  static OrderSummary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    final Object? quantity = raw['quantity'];
    final Object? status = raw['status'];
    if (id is! int || quantity is! int || status is! String) return null;

    final Object? number = raw['order_number'];
    final Object? productId = raw['product_id'];
    final Object? created = raw['created_at'];
    return OrderSummary(
      id: id,
      orderNumber: number is String && number.isNotEmpty ? number : 'ORD-$id',
      status: OrderStatus.fromRaw(status),
      quantity: quantity,
      agreedUnitPrice: '${raw['agreed_unit_price'] ?? ''}',
      totalAmount: '${raw['total_amount'] ?? ''}',
      currency: '${raw['currency'] ?? ''}',
      productId: productId is int ? productId : null,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderSummary &&
          other.id == id &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.quantity == quantity &&
          other.agreedUnitPrice == agreedUnitPrice &&
          other.totalAmount == totalAmount &&
          other.currency == currency &&
          other.productId == productId &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    orderNumber,
    status,
    quantity,
    agreedUnitPrice,
    totalAmount,
    currency,
    productId,
    createdAt,
  );
}
