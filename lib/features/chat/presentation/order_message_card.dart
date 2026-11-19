import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_formatters.dart';
import '../../orders/domain/order_summary.dart';
import '../../orders/presentation/order_action_sheets.dart';
import '../../orders/presentation/order_status_chip.dart';
import '../../orders/presentation/orders_providers.dart';

/// Part BI-03 — the order recorded from a chat message, rendered under the
/// Product card.
///
/// Starts from the message's own [OrderSummary] (so it never renders blank)
/// and refines itself from the live order (`chatOrderLiveProvider`), so a
/// status change made later shows up without reloading the thread.
///
/// ### Who sees what
/// - Merchant ([isMerchant]): status / note / details actions. A business
///   account can only ever be the merchant of an order (the backend requires
///   the customer to be a `customer` account).
/// - Customer: status, dates and the customer-visible notes only. The card
///   never reads an internal note: the summary has none, the customer
///   endpoint omits it, and the merchant endpoint is not used for customers.
class OrderMessageCard extends ConsumerWidget {
  const OrderMessageCard({
    super.key,
    required this.summary,
    required this.isMerchant,
  });

  final OrderSummary summary;
  final bool isMerchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;

    final ChatOrderLive? live =
        ref
            .watch(
              chatOrderLiveProvider(
                ChatOrderKey(orderId: summary.id, asMerchant: isMerchant),
              ),
            )
            .value;
    final Order? order = live?.order;

    final status = order?.status ?? summary.status;
    final String productName =
        order?.productName ??
        (summary.productId != null
            ? l10n.ordersProductFallback(summary.productId!)
            : l10n.ordersProductLabel);
    final DateTime? createdAt = summary.createdAt ?? order?.createdAt;
    final String customerNote = (order?.customerNote ?? '').trim();
    final List<String> notes = live?.visibleNotes ?? const <String>[];
    final bool canChangeStatus =
        isMerchant && order != null && order.allowedNextStatuses.isNotEmpty;

    Widget small(String text) =>
        Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12));

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: Container(
        key: ValueKey<String>('orderCard_${summary.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: colors.brandText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary.orderNumber,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OrderStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.ordersQuantityTimesPrice(
                summary.quantity,
                OrderMoney.withCurrency(
                  summary.agreedUnitPrice,
                  summary.currency,
                ),
              ),
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${l10n.ordersTotalLabel}: ',
                  style: TextStyle(color: colors.textSecondary),
                ),
                Flexible(
                  child: Text(
                    OrderMoney.withCurrency(
                      summary.totalAmount,
                      summary.currency,
                    ),
                    key: const ValueKey<String>('orderCardTotal'),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (createdAt != null)
              small(l10n.ordersCreatedAt(formatOrderDateTime(createdAt))),
            if (order?.confirmedAt != null)
              small(
                l10n.ordersConfirmedAt(
                  formatOrderDateTime(order!.confirmedAt!),
                ),
              ),
            if (order?.completedAt != null)
              small(
                l10n.ordersCompletedAt(
                  formatOrderDateTime(order!.completedAt!),
                ),
              ),
            if (order?.cancelledAt != null)
              small(
                l10n.ordersCancelledAt(
                  formatOrderDateTime(order!.cancelledAt!),
                ),
              ),
            if (customerNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              small(l10n.ordersCustomerNote),
              Text(
                customerNote,
                key: const ValueKey<String>('orderCardCustomerNote'),
                style: TextStyle(color: colors.textPrimary),
              ),
            ],
            if (!isMerchant)
              for (final String note in notes)
                if (note != customerNote)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
            if (isMerchant) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  if (canChangeStatus)
                    TextButton(
                      key: const ValueKey<String>('orderCardUpdateStatus'),
                      onPressed:
                          () => showChangeStatusSheet(context, order: order),
                      child: Text(l10n.ordersUpdateStatus),
                    ),
                  if (order != null)
                    TextButton(
                      key: const ValueKey<String>('orderCardAddNote'),
                      onPressed: () => showAddNoteSheet(context, order: order),
                      child: Text(l10n.ordersAddNote),
                    ),
                  TextButton(
                    key: const ValueKey<String>('orderCardOpenDetails'),
                    onPressed:
                        () => context.pushNamed(
                          RouteNames.orderDetail,
                          pathParameters: <String, String>{
                            RouteNames.idParam: '${summary.id}',
                          },
                        ),
                    child: Text(l10n.ordersOpenDetails),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
