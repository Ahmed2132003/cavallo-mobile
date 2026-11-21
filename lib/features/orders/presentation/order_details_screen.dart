import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/conversation.dart';
import '../domain/order.dart';
import '../domain/order_formatters.dart';
import '../domain/order_note.dart';
import '../domain/order_status_event.dart';
import 'order_action_sheets.dart';
import 'order_error_text.dart';
import 'order_status_chip.dart';
import 'orders_providers.dart';

/// Part BI-03 — one order, merchant side: product, customer, price and
/// quantity, status, timeline, notes (internal ones flagged), and the
/// actions (change status, add note, open the original conversation).
///
/// Takes the id from the route path, so it keeps working after an app
/// restart (no `extra` needed).
class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final int? id = int.tryParse(orderId);

    if (id == null) {
      return Scaffold(
        appBar: CavalloAppBar(title: Text(l10n.ordersDetailsTitle)),
        body: Center(
          child: Text(
            l10n.ordersNotFound,
            key: const ValueKey<String>('orderNotFound'),
          ),
        ),
      );
    }

    final AsyncValue<Order> orderAsync = ref.watch(orderDetailProvider(id));
    final AsyncValue<OrderEvents> eventsAsync = ref.watch(
      orderEventsProvider(id),
    );
    final Order? order = orderAsync.value;

    return Scaffold(
      appBar: CavalloAppBar(
        title: Text(order?.orderNumber ?? l10n.ordersDetailsTitle),
      ),
      body:
          order != null
              ? _Content(order: order, eventsAsync: eventsAsync)
              : (orderAsync.hasError
                  ? _ErrorView(
                    message: orderErrorText(l10n, orderAsync.error!),
                    onRetry: () => ref.invalidate(orderDetailProvider(id)),
                  )
                  : const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey<String>('orderLoading'),
                    ),
                  )),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    return Center(
      child: Padding(
        key: const ValueKey<String>('orderError'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.dangerText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey<String>('orderRetryButton'),
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.order, required this.eventsAsync});

  final Order order;
  final AsyncValue<OrderEvents> eventsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;

    Widget row(String label, String value, {bool bold = false, Key? key}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: TextStyle(color: colors.textSecondary)),
            ),
            Expanded(
              child: Text(
                value,
                key: key,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String customerNote = order.customerNote.trim();
    final String internalNote = (order.internalNote ?? '').trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.orderNumber,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OrderStatusChip(status: order.status),
          ],
        ),
        const SizedBox(height: 12),
        row(l10n.ordersProductLabel, order.productName),
        row(
          l10n.ordersCustomerLabel,
          (order.customerName ?? '').isNotEmpty ? order.customerName! : '—',
        ),
        row(l10n.ordersQuantityLabel, '${order.quantity}'),
        row(
          l10n.ordersUnitPriceLabel,
          OrderMoney.withCurrency(order.agreedUnitPrice, order.currency),
        ),
        row(
          l10n.ordersTotalLabel,
          OrderMoney.withCurrency(order.totalAmount, order.currency),
          bold: true,
          key: const ValueKey<String>('orderDetailsTotal'),
        ),
        row(
          l10n.ordersCurrencyLabel,
          order.currency.isEmpty ? '—' : order.currency,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.ordersCreatedAt(formatOrderDateTime(order.createdAt)),
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        if (order.confirmedAt != null)
          Text(
            l10n.ordersConfirmedAt(formatOrderDateTime(order.confirmedAt!)),
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        if (order.completedAt != null)
          Text(
            l10n.ordersCompletedAt(formatOrderDateTime(order.completedAt!)),
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        if (order.cancelledAt != null)
          Text(
            l10n.ordersCancelledAt(formatOrderDateTime(order.cancelledAt!)),
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        if (customerNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.ordersCustomerNote,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(customerNote, key: const ValueKey<String>('orderCustomerNote')),
        ],
        if (internalNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                l10n.ordersInternalNote,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              _InternalBadge(),
            ],
          ),
          Text(internalNote, key: const ValueKey<String>('orderInternalNote')),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (order.allowedNextStatuses.isNotEmpty)
              FilledButton(
                key: const ValueKey<String>('orderUpdateStatusButton'),
                onPressed: () => showChangeStatusSheet(context, order: order),
                child: Text(l10n.ordersUpdateStatus),
              ),
            OutlinedButton(
              key: const ValueKey<String>('orderAddNoteButton'),
              onPressed: () => showAddNoteSheet(context, order: order),
              child: Text(l10n.ordersAddNote),
            ),
            TextButton(
              key: const ValueKey<String>('orderOpenConversationButton'),
              onPressed: () => _openConversation(context, ref, order),
              child: Text(l10n.ordersOpenConversation),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._events(context, l10n, ref),
      ],
    );
  }

  List<Widget> _events(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final AppColors colors = context.appColors;
    final OrderEvents? events = eventsAsync.value;

    if (events == null) {
      if (eventsAsync.hasError) {
        return [
          Text(
            orderErrorText(l10n, eventsAsync.error!),
            style: TextStyle(color: colors.dangerText),
          ),
          TextButton(
            onPressed: () => ref.invalidate(orderEventsProvider(order.id)),
            child: Text(l10n.commonRetry),
          ),
        ];
      }
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      Text(
        l10n.ordersTimelineTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      for (final OrderStatusEvent event in events.timeline)
        _TimelineEntry(event: event),
      const SizedBox(height: 16),
      Text(
        l10n.ordersNotesTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (events.notes.isEmpty)
        Text(
          l10n.ordersNotesEmpty,
          key: const ValueKey<String>('orderNotesEmpty'),
          style: TextStyle(color: colors.textSecondary),
        )
      else
        for (final OrderNote note in events.notes) _NoteTile(note: note),
    ];
  }
}

class _InternalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.l10n.ordersInternalBadge,
          style: TextStyle(color: colors.warningText, fontSize: 11),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event});

  final OrderStatusEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;

    final String title;
    switch (event.type) {
      case OrderEventType.created:
        title = l10n.ordersTimelineCreated;
      case OrderEventType.statusChanged:
        title = l10n.ordersTimelineStatusChanged(
          event.fromStatus == null
              ? '—'
              : orderStatusLabel(l10n, event.fromStatus!),
          event.toStatus == null
              ? '—'
              : orderStatusLabel(l10n, event.toStatus!),
        );
      case OrderEventType.noteAdded:
      case OrderEventType.unknown:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 10, color: colors.brandText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.textPrimary)),
                if (event.note.trim().isNotEmpty)
                  Text(
                    event.note.trim(),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                Text(
                  formatOrderDateTime(event.createdAt),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final OrderNote note;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      key: ValueKey<String>('orderNote_${note.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isInternal) ...[_InternalBadge(), const SizedBox(height: 4)],
          Text(note.note, style: TextStyle(color: colors.textPrimary)),
          const SizedBox(height: 2),
          Text(
            formatOrderDateTime(note.createdAt),
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// There is no "get one conversation" endpoint, so the conversation is found
/// by id in the paginated conversation list (same approach as
/// `ConversationRepository.startConversationWithBusiness`) and opened with
/// the same `extra: Conversation` the chat list uses.
Future<void> _openConversation(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final GoRouter router = GoRouter.of(context);
  final ConversationRepository repository = ref.read(
    conversationRepositoryProvider,
  );

  try {
    Conversation? found;
    String? cursor;
    for (int page = 0; page < 10 && found == null; page++) {
      final result = await repository.listConversations(cursor: cursor);
      for (final Conversation conversation in result.results) {
        if (conversation.id == order.conversationId) {
          found = conversation;
          break;
        }
      }
      cursor = result.next;
      if (cursor == null) break;
    }
    if (found == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ordersConversationUnavailable)),
      );
      return;
    }
    router.pushNamed(
      RouteNames.chatThread,
      pathParameters: <String, String>{RouteNames.idParam: '${found.id}'},
      extra: found,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(orderErrorText(l10n, e))));
  }
}
