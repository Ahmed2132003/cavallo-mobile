import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order_status.dart';

String orderStatusLabel(AppLocalizations l10n, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return l10n.ordersStatusPending;
    case OrderStatus.confirmed:
      return l10n.ordersStatusConfirmed;
    case OrderStatus.processing:
      return l10n.ordersStatusProcessing;
    case OrderStatus.shipped:
      return l10n.ordersStatusShipped;
    case OrderStatus.delivered:
      return l10n.ordersStatusDelivered;
    case OrderStatus.cancelled:
      return l10n.ordersStatusCancelled;
    case OrderStatus.unknown:
      return l10n.ordersStatusUnknown;
  }
}

/// Colours + icon of one status. Colours come from [AppColors] only; each
/// status is distinguishable by icon as well as colour.
class OrderStatusTone {
  const OrderStatusTone({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

OrderStatusTone orderStatusTone(AppColors c, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return OrderStatusTone(
        background: c.warningSubtle,
        foreground: c.warningText,
        icon: Icons.hourglass_top_rounded,
      );
    case OrderStatus.confirmed:
      return OrderStatusTone(
        background: c.brandSubtle,
        foreground: c.brandText,
        icon: Icons.check_circle_outline,
      );
    case OrderStatus.processing:
      return OrderStatusTone(
        background: c.surfaceVariant,
        foreground: c.textPrimary,
        icon: Icons.autorenew_rounded,
      );
    case OrderStatus.shipped:
      return OrderStatusTone(
        background: c.brand,
        foreground: c.onBrand,
        icon: Icons.local_shipping_outlined,
      );
    case OrderStatus.delivered:
      return OrderStatusTone(
        background: c.successSubtle,
        foreground: c.successText,
        icon: Icons.task_alt_rounded,
      );
    case OrderStatus.cancelled:
      return OrderStatusTone(
        background: c.dangerSubtle,
        foreground: c.dangerText,
        icon: Icons.cancel_outlined,
      );
    case OrderStatus.unknown:
      return OrderStatusTone(
        background: c.surfaceVariant,
        foreground: c.textSecondary,
        icon: Icons.help_outline,
      );
  }
}

/// A status pill. When [status] changes, the colour animates and the label
/// cross-fades (light animation, no layout jump).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final OrderStatusTone tone = orderStatusTone(colors, status);
    final String label = orderStatusLabel(context.l10n, status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Row(
          key: ValueKey<String>('orderStatusChip_${status.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tone.icon, size: 14, color: tone.foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: tone.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
