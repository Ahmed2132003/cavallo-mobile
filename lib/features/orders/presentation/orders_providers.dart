import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/orders_repository.dart';
import '../domain/order.dart';
import '../domain/order_note.dart';
import '../domain/order_status.dart';
import '../domain/order_status_event.dart';
import '../domain/order_summary.dart';

/// The list screen loads at most this many pages (the backend has no count
/// endpoint, so the Overview counters are computed from what was loaded).
const int kOrdersMaxPages = 10;

/// What the list screen shows: the loaded orders, and whether the page cap
/// stopped loading (counters are then partial and the UI says so).
class OrdersSnapshot {
  const OrdersSnapshot({required this.orders, required this.truncated});

  final List<Order> orders;
  final bool truncated;
}

/// Counters per status over [orders] (every lifecycle status is present).
Map<OrderStatus, int> ordersCountByStatus(List<Order> orders) {
  final Map<OrderStatus, int> counts = <OrderStatus, int>{
    for (final OrderStatus s in OrderStatus.lifecycle) s: 0,
  };
  for (final Order order in orders) {
    if (counts.containsKey(order.status)) {
      counts[order.status] = counts[order.status]! + 1;
    }
  }
  return counts;
}

/// `null` status = All.
List<Order> filterOrdersByStatus(List<Order> orders, OrderStatus? status) {
  if (status == null) return orders;
  return orders.where((Order o) => o.status == status).toList(growable: false);
}

/// The merchant's orders. The argument is the search text ('' = no search).
/// Status filtering is done client-side so the chips are instant and the
/// counters stay complete; search is server-side (`?search=`).
final ordersListProvider = FutureProvider.autoDispose
    .family<OrdersSnapshot, String>((Ref ref, String search) async {
      final OrdersRepository repository = ref.watch(ordersRepositoryProvider);
      final List<Order> all = <Order>[];
      String? cursor;
      bool truncated = false;
      for (int page = 0; page < kOrdersMaxPages; page++) {
        final result = await repository.listOrders(
          search: search,
          cursor: cursor,
        );
        all.addAll(result.results);
        cursor = result.next;
        if (cursor == null) break;
        if (page == kOrdersMaxPages - 1) truncated = true;
      }
      return OrdersSnapshot(orders: all, truncated: truncated);
    }, retry: (int retryCount, Object error) => null);

final orderDetailProvider = FutureProvider.autoDispose.family<Order, int>((
  Ref ref,
  int id,
) {
  return ref.watch(ordersRepositoryProvider).fetchOrder(id);
}, retry: (int retryCount, Object error) => null);

final orderEventsProvider = FutureProvider.autoDispose.family<OrderEvents, int>(
  (Ref ref, int id) {
    return ref.watch(ordersRepositoryProvider).fetchOrderEvents(id);
  },
  retry: (int retryCount, Object error) => null,
);

/// Key of [chatOrderLiveProvider].
@immutable
class ChatOrderKey {
  const ChatOrderKey({required this.orderId, required this.asMerchant});

  final int orderId;
  final bool asMerchant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatOrderKey &&
          other.orderId == orderId &&
          other.asMerchant == asMerchant);

  @override
  int get hashCode => Object.hash(orderId, asMerchant);
}

/// Live data for the chat order card: the order plus the notes the customer
/// may see. The merchant gets the merchant endpoint (and no notes here: the
/// card never shows an internal note, the details screen does).
class ChatOrderLive {
  const ChatOrderLive({
    required this.order,
    this.visibleNotes = const <String>[],
  });

  final Order order;
  final List<String> visibleNotes;
}

final chatOrderLiveProvider = FutureProvider.autoDispose
    .family<ChatOrderLive, ChatOrderKey>((Ref ref, ChatOrderKey key) async {
      final OrdersRepository repository = ref.watch(ordersRepositoryProvider);
      if (key.asMerchant) {
        return ChatOrderLive(order: await repository.fetchOrder(key.orderId));
      }
      final CustomerOrderDetail detail = await repository.fetchMyOrder(
        key.orderId,
      );
      final List<String> notes = <String>[
        for (final OrderStatusEvent e in detail.events.timeline)
          if (e.note.trim().isNotEmpty) e.note.trim(),
        for (final OrderNote n in detail.events.notes)
          if (!n.isInternal && n.note.trim().isNotEmpty) n.note.trim(),
      ];
      return ChatOrderLive(order: detail.order, visibleNotes: notes);
    }, retry: (int retryCount, Object error) => null);

/// Orders recorded in this session, keyed by SOURCE MESSAGE id, so the chat
/// bubble shows the order card immediately without re-fetching the thread.
class RecordedOrdersNotifier extends Notifier<Map<int, OrderSummary>> {
  @override
  Map<int, OrderSummary> build() => const <int, OrderSummary>{};

  void record(int messageId, OrderSummary summary) {
    state = <int, OrderSummary>{...state, messageId: summary};
  }
}

final NotifierProvider<RecordedOrdersNotifier, Map<int, OrderSummary>>
recordedOrdersProvider = NotifierProvider.autoDispose<
  RecordedOrdersNotifier,
  Map<int, OrderSummary>
>(RecordedOrdersNotifier.new);

/// Merchant write actions. Each one refreshes every provider that shows the
/// order (list, details, events, chat card) after the server confirmed it.
class OrderActions {
  OrderActions(this._ref);

  final Ref _ref;

  OrdersRepository get _repository => _ref.read(ordersRepositoryProvider);

  void _refresh(int orderId) {
    _ref.invalidate(orderDetailProvider(orderId));
    _ref.invalidate(orderEventsProvider(orderId));
    _ref.invalidate(ordersListProvider);
    _ref.invalidate(
      chatOrderLiveProvider(ChatOrderKey(orderId: orderId, asMerchant: true)),
    );
  }

  Future<Order> changeStatus({
    required int orderId,
    required OrderStatus status,
    String note = '',
  }) async {
    final Order order = await _repository.changeStatus(
      orderId: orderId,
      status: status,
      note: note,
    );
    _refresh(orderId);
    return order;
  }

  Future<OrderNote> addNote({
    required int orderId,
    required String note,
    required bool isInternal,
  }) async {
    final OrderNote created = await _repository.addNote(
      orderId: orderId,
      note: note,
      isInternal: isInternal,
    );
    _refresh(orderId);
    return created;
  }
}

final Provider<OrderActions> orderActionsProvider = Provider<OrderActions>(
  (Ref ref) => OrderActions(ref),
);
