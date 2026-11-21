/// Part BI-04: "data updated at" line + Refresh button + coverage warning.
///
/// The app never shows a "live" label: it shows the backend's real
/// `data_updated_at` (last rollup time) and, where the section has one,
/// `orders_data_updated_at`. When views are unavailable or incomplete for the
/// period, a one-line note explains why some numbers are a dash.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/formatters.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_common.dart';
import '../providers/analytics_refresh.dart';

class AnalyticsFreshness extends ConsumerWidget {
  const AnalyticsFreshness({
    super.key,
    required this.dataUpdatedAt,
    this.ordersDataUpdatedAt,
    this.coverage,
  });

  final DateTime? dataUpdatedAt;
  final DateTime? ordersDataUpdatedAt;

  /// Null for sections whose numbers do not depend on view rollups.
  final AnalyticsCoverage? coverage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters.of(context);
    final TextStyle? small = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);

    final DateTime? updated = dataUpdatedAt;
    final DateTime? ordersUpdated = ordersDataUpdatedAt;
    final AnalyticsCoverage? cov = coverage;

    String? coverageNote;
    if (cov != null) {
      if (!cov.viewsAvailable) {
        coverageNote = l10n.biViewsUnavailable;
      } else if (!cov.viewsComplete) {
        coverageNote = l10n.biViewsIncomplete;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                updated == null
                    ? l10n.biDataNeverUpdated
                    : l10n.biDataUpdatedAt(
                      formatters.absoluteDateTime(updated),
                    ),
                key: const ValueKey<String>('bi-data-updated-at'),
                style: small,
              ),
              if (ordersUpdated != null)
                Text(
                  l10n.biOrdersUpdatedAt(
                    formatters.absoluteDateTime(ordersUpdated),
                  ),
                  key: const ValueKey<String>('bi-orders-updated-at'),
                  style: small,
                ),
              if (coverageNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    coverageNote,
                    key: const ValueKey<String>('bi-coverage-note'),
                    style: small?.copyWith(color: colors.warningText),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey<String>('bi-refresh-button'),
          tooltip: l10n.biRefresh,
          icon: const Icon(Icons.refresh),
          onPressed: () => refreshAnalytics(ref),
        ),
      ],
    );
  }
}
