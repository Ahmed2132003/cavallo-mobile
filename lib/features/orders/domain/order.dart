import 'order_status.dart';
import 'order_summary.dart';

/// Part BI-03 — an order, as seen by either side.
///
/// Merchant payloads (`MerchantOrderSerializer`) fill [customerId],
/// [customerName], [sourceMessageId], [allowedNextStatuses] and
/// [internalNote]. Customer payloads (`CustomerOrderSerializer`) fill
/// [businessId] / [businessName] and NEVER an [internalNote]: it stays `null`
/// on the customer side even if a server ever sent one.
class Order {
  const Order({
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
    this.allowedNextStatuses = const <OrderStatus>[],
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

  /// Decimal strings exactly as the server sent them ("12.50").
  final String agreedUnitPrice;
  final String totalAmount;
  final String currency;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int? customerId;
  final String? customerName;
  final int? businessId;
  final String? businessName;
  final int? sourceMessageId;

  /// Server-authoritative legal next statuses (merchant payloads only).
  final List<OrderStatus> allowedNextStatuses;

  /// Shown to the customer.
  final String customerNote;

  /// Merchant-only. `null` on every customer-side order.
  final String? internalNote;

  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  OrderSummary toSummary() => OrderSummary(
    id: id,
    orderNumber: orderNumber,
    status: status,
    quantity: quantity,
    agreedUnitPrice: agreedUnitPrice,
    totalAmount: totalAmount,
    currency: currency,
    productId: productId,
    createdAt: createdAt,
  );
}