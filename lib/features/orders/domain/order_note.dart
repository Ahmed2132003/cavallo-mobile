/// Part BI-03 — a note added to an order (`note_added` event).
///
/// [isInternal] notes are merchant-only. A customer-side parse never produces
/// one (see `mapOrderEvents(customerView: true)`).
class OrderNote {
  const OrderNote({
    required this.id,
    required this.note,
    required this.isInternal,
    required this.createdAt,
  });

  final int id;
  final String note;
  final bool isInternal;
  final DateTime createdAt;
}