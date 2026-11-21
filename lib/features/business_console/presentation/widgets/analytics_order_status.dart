/// Part BI-04: label, icon and token colour of an order status for the
/// dashboard (counters and donut). Every status has an icon AND a label, so
/// meaning never rides on colour alone.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/domain/order_status.dart';

String analyticsStatusLabel(BuildContext context, OrderStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    OrderStatus.pending => l10n.biStatusPending,
    OrderStatus.confirmed => l10n.biStatusConfirmed,
    OrderStatus.processing => l10n.biStatusProcessing,
    OrderStatus.shipped => l10n.biStatusShipped,
    OrderStatus.delivered => l10n.biStatusDelivered,
    OrderStatus.cancelled => l10n.biStatusCancelled,
    OrderStatus.unknown => l10n.biStatusUnknown,
  };
}

IconData analyticsStatusIcon(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => Icons.hourglass_empty,
    OrderStatus.confirmed => Icons.check_circle_outline,
    OrderStatus.processing => Icons.autorenew,
    OrderStatus.shipped => Icons.local_shipping_outlined,
    OrderStatus.delivered => Icons.done_all,
    OrderStatus.cancelled => Icons.cancel_outlined,
    OrderStatus.unknown => Icons.help_outline,
  };
}

Color analyticsStatusColor(AppColors colors, OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => colors.warningText,
    OrderStatus.confirmed => colors.brand,
    OrderStatus.processing => colors.brandText,
    OrderStatus.shipped => colors.featured,
    OrderStatus.delivered => colors.successText,
    OrderStatus.cancelled => colors.dangerText,
    OrderStatus.unknown => colors.textSecondary,
  };
}
