import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../domain/order.dart';
import '../domain/order_formatters.dart';
import '../domain/order_status.dart';
import 'order_error_text.dart';
import 'order_status_chip.dart';
import 'orders_providers.dart';

/// Part BI-03 — the merchant's orders (tab 5 of the Business Console).
///
/// Overview counters + status filter chips + search (server-side, by order
/// number) + pull-to-refresh. Status filtering is client-side over the loaded
/// orders, so the chips are instant and the counters always cover every
/// status (the backend has no count endpoint; see [kOrdersMaxPages]).
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  OrderStatus? _filter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _applySearch(value),
    );
    setState(() {}); // refreshes the clear button
  }

  void _applySearch(String value) {
    final String trimmed = value.trim();
    if (!mounted || trimmed == _search) return;
    setState(() => _search = trimmed);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _search = '');
  }

  Future<void> _refresh() async {
    ref.invalidate(ordersListProvider(_search));
    try {
      await ref.read(ordersListProvider(_search).future);
    } catch (_) {
      // The error state is rendered from the provider itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<OrdersSnapshot> async = ref.watch(
      ordersListProvider(_search),
    );
    final OrdersSnapshot? snapshot = async.value;

    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.ordersTitle)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              key: const ValueKey<String>('ordersSearchField'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _applySearch,
              decoration: InputDecoration(
                hintText: l10n.ordersSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          key: const ValueKey<String>('ordersSearchClear'),
                          tooltip: l10n.ordersSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearch,
                        ),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot != null) ...[
              _OverviewCard(
                orders: snapshot.orders,
                selected: _filter,
                onSelect:
                    (OrderStatus? status) => setState(() => _filter = status),
              ),
              if (snapshot.truncated)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.ordersTruncatedNote(snapshot.orders.length),
                    key: const ValueKey<String>('ordersTruncatedNote'),
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            _FilterChips(
              selected: _filter,
              onSelect:
                  (OrderStatus? status) => setState(() => _filter = status),
            ),
            const SizedBox(height: 12),
            ..._body(context, l10n, async, snapshot),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<OrdersSnapshot> async,
    OrdersSnapshot? snapshot,
  ) {
    final AppColors colors = context.appColors;

    if (snapshot != null) {
      final List<Order> visible = filterOrdersByStatus(
        snapshot.orders,
        _filter,
      );
      if (visible.isEmpty) {
        final bool searching = _search.isNotEmpty;
        final String title =
            searching
                ? l10n.ordersEmptySearchTitle
                : (_filter != null
                    ? l10n.ordersEmptyFilteredTitle
                    : l10n.ordersEmptyTitle);
        return [
          Padding(
            key: const ValueKey<String>('ordersEmpty'),
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!searching && _filter == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.ordersEmptyBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ];
      }
      return [for (final Order order in visible) _OrderTile(order: order)];
    }

    if (async.hasError) {
      return [
        Padding(
          key: const ValueKey<String>('ordersError'),
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.dangerText),
              const SizedBox(height: 12),
              Text(
                l10n.ordersErrorLoad,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                orderErrorText(l10n, async.error!),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const ValueKey<String>('ordersRetryButton'),
                onPressed: _refresh,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ];
    }

    return const [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey<String>('ordersLoading'),
          ),
        ),
      ),
    ];
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.orders,
    required this.selected,
    required this.onSelect,
  });

  final List<Order> orders;
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final Map<OrderStatus, int> counts = ordersCountByStatus(orders);

    return Container(
      key: const ValueKey<String>('ordersOverview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.ordersOverviewTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${l10n.ordersOverviewTotal}: ',
                style: TextStyle(color: colors.textSecondary),
              ),
              Text(
                '${orders.length}',
                key: const ValueKey<String>('ordersOverviewTotal'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final OrderStatus status in OrderStatus.lifecycle)
                _CounterTile(
                  status: status,
                  count: counts[status] ?? 0,
                  isSelected: selected == status,
                  onTap: () => onSelect(selected == status ? null : status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.status,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final OrderStatus status;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final OrderStatusTone tone = orderStatusTone(colors, status);

    return InkWell(
      key: ValueKey<String>('ordersCounter_${status.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? tone.foreground : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              key: ValueKey<String>('ordersCounterValue_${status.name}'),
              style: TextStyle(
                color: tone.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              orderStatusLabel(context.l10n, status),
              style: TextStyle(color: tone.foreground, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const ValueKey<String>('ordersFilter_all'),
          label: Text(l10n.ordersFilterAll),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final OrderStatus status in OrderStatus.lifecycle)
          ChoiceChip(
            key: ValueKey<String>('ordersFilter_${status.name}'),
            label: Text(orderStatusLabel(l10n, status)),
            selected: selected == status,
            onSelected: (_) => onSelect(status),
          ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>('orderTile_${order.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap:
              () => context.pushNamed(
                RouteNames.orderDetail,
                pathParameters: <String, String>{
                  RouteNames.idParam: '${order.id}',
                },
              ),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary),
                ),
                if ((order.customerName ?? '').isNotEmpty)
                  Text(
                    '${l10n.ordersCustomerLabel}: ${order.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.ordersQuantityTimesPrice(
                          order.quantity,
                          OrderMoney.withCurrency(
                            order.agreedUnitPrice,
                            order.currency,
                          ),
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    Text(
                      OrderMoney.withCurrency(
                        order.totalAmount,
                        order.currency,
                      ),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatOrderDateTime(order.createdAt),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
