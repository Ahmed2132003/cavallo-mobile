import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/domain/message.dart';
import '../../chat/domain/shared_content.dart';
import '../../products/domain/product_entity.dart';
import '../../products/presentation/product_public_providers.dart';
import '../data/orders_repository.dart';
import '../domain/order_formatters.dart';
import 'order_error_text.dart';
import 'orders_providers.dart';

/// Part BI-03 — the merchant's "Record Sale" bottom sheet, opened from a
/// Product card in chat. [message] is the chat message that shares the
/// product (the order's source message) and [customerName] the other
/// participant's display name.
///
/// ### Double tap / retry
/// While a request is in flight the button is disabled and the sheet cannot
/// be dismissed. After a failure the button turns into "Try again" and sends
/// the SAME source message id: the backend allows one order per message and
/// answers a repeat with the existing order (HTTP 200), so retrying after a
/// lost response never creates a duplicate.
Future<void> showRecordSaleSheet(
  BuildContext context, {
  required Message message,
  required SharedContent shared,
  String? customerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder:
        (BuildContext _) => RecordSaleSheet(
          message: message,
          shared: shared,
          customerName: customerName,
        ),
  );
}

class RecordSaleSheet extends ConsumerStatefulWidget {
  const RecordSaleSheet({
    super.key,
    required this.message,
    required this.shared,
    this.customerName,
  });

  final Message message;
  final SharedContent shared;
  final String? customerName;

  @override
  ConsumerState<RecordSaleSheet> createState() => _RecordSaleSheetState();
}

class _RecordSaleSheetState extends ConsumerState<RecordSaleSheet> {
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _customerNote = TextEditingController();
  final TextEditingController _internalNote = TextEditingController();

  bool _submitting = false;
  bool _attempted = false;
  bool _failedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantity.addListener(_refresh);
    _price.addListener(_refresh);
    _prefillPrice(
      ref.read(productPublicDetailProvider(widget.shared.objectId)).value,
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _customerNote.dispose();
    _internalNote.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// The agreed price starts at the product's current price; the merchant can
  /// change it. Never overwrites something the merchant already typed.
  void _prefillPrice(Product? product) {
    if (product == null || _price.text.isNotEmpty) return;
    if (OrderMoney.parseUnitPriceMinor(product.price) != null) {
      _price.text = product.price;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final int? quantity = OrderMoney.parseQuantity(_quantity.text);
    final int? unitMinor = OrderMoney.parseUnitPriceMinor(_price.text);
    if (quantity == null || unitMinor == null) {
      setState(() {
        _attempted = true;
        _error = null;
      });
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final OrdersRepository repository = ref.read(ordersRepositoryProvider);
    final RecordedOrdersNotifier recorded = ref.read(
      recordedOrdersProvider.notifier,
    );
    setState(() {
      _attempted = true;
      _submitting = true;
      _error = null;
    });

    try {
      final CreatedOrderResult result = await repository.createFromChat(
        conversationId: widget.message.conversationId,
        sourceMessageId: widget.message.id,
        quantity: quantity,
        agreedUnitPrice: OrderMoney.formatMinor(unitMinor),
        customerNote: _customerNote.text.trim(),
        internalNote: _internalNote.text.trim(),
      );
      recorded.record(widget.message.id, result.order.toSummary());
      if (!mounted) return;
      ref.invalidate(ordersListProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.created
                ? l10n.ordersRecordedSuccess(result.order.orderNumber)
                : l10n.ordersAlreadyRecorded(result.order.orderNumber),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failedOnce = true;
        _error = orderErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final SharedContent shared = widget.shared;

    ref.listen<AsyncValue<Product?>>(
      productPublicDetailProvider(shared.objectId),
      (AsyncValue<Product?>? _, AsyncValue<Product?> next) {
        _prefillPrice(next.value);
      },
    );
    final Product? product =
        ref.watch(productPublicDetailProvider(shared.objectId)).value;

    final String productName =
        product?.name ??
        ((shared.previewText ?? '').isNotEmpty
            ? shared.previewText!
            : l10n.ordersProductFallback(shared.objectId));
    final String? imageUrl = product?.imageUrl ?? shared.previewImageUrl;
    final String? currency = product?.currency.toWire();

    final int? quantity = OrderMoney.parseQuantity(_quantity.text);
    final int? unitMinor = OrderMoney.parseUnitPriceMinor(_price.text);
    final int? totalMinor =
        (quantity != null && unitMinor != null)
            ? OrderMoney.totalMinor(quantity, unitMinor)
            : null;
    final String totalText =
        totalMinor == null
            ? '—'
            : OrderMoney.withCurrency(
              OrderMoney.formatMinor(totalMinor),
              currency ?? '',
            );

    final String? name = widget.customerName;

    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ordersRecordSaleTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child:
                            (imageUrl == null || imageUrl.isEmpty)
                                ? ColoredBox(
                                  color: colors.surfaceVariant,
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: colors.textSecondary,
                                  ),
                                )
                                : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (
                                        BuildContext _,
                                        Object error,
                                        StackTrace? stackTrace,
                                      ) => ColoredBox(
                                        color: colors.surfaceVariant,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (name != null && name.isNotEmpty)
                            Text(
                              '${l10n.ordersCustomerLabel}: $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey<String>('recordSaleQuantity'),
                  controller: _quantity,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.ordersQuantityLabel,
                    errorText:
                        (_attempted && quantity == null)
                            ? l10n.ordersValidationQuantity
                            : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('recordSalePrice'),
                  controller: _price,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.ordersUnitPriceLabel,
                    suffixText: currency,
                    errorText:
                        (_attempted && unitMinor == null)
                            ? l10n.ordersValidationPrice
                            : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${l10n.ordersCurrencyLabel}: ',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        currency ?? l10n.ordersCurrencyAutoNote,
                        key: const ValueKey<String>('recordSaleCurrency'),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('recordSaleCustomerNote'),
                  controller: _customerNote,
                  enabled: !_submitting,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.ordersFieldCustomerNote,
                  ),
                ),
                TextField(
                  key: const ValueKey<String>('recordSaleInternalNote'),
                  controller: _internalNote,
                  enabled: !_submitting,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.ordersFieldInternalNote,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.ordersSummaryTitle,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(productName),
                        if (totalMinor != null)
                          Text(
                            l10n.ordersSummaryLine(
                              quantity!,
                              OrderMoney.display(
                                OrderMoney.formatMinor(unitMinor!),
                              ),
                              totalText,
                            ),
                            key: const ValueKey<String>('recordSaleSummary'),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${l10n.ordersTotalLabel}: '),
                            Text(
                              totalText,
                              key: const ValueKey<String>('recordSaleTotal'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    key: const ValueKey<String>('recordSaleError'),
                    style: TextStyle(color: colors.dangerText),
                  ),
                  Text(
                    l10n.ordersErrorSafeRetry,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: Text(l10n.ordersActionCancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const ValueKey<String>('recordSaleConfirmButton'),
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting
                              ? l10n.ordersSubmitting
                              : (_failedOnce
                                  ? l10n.ordersRetryRecord
                                  : l10n.ordersConfirmRecord),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
