/// Part BI-04: explains missing view numbers. Renders nothing when the views
/// are fully covered.
library;

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/analytics_common.dart';

class ProductCoverageNotice extends StatelessWidget {
  const ProductCoverageNotice({super.key, required this.coverage});

  final AnalyticsCoverage coverage;

  @override
  Widget build(BuildContext context) {
    if (coverage.viewsAvailable && coverage.viewsComplete) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final String message =
        coverage.viewsAvailable
            ? l10n.analyticsProdViewsIncomplete
            : l10n.analyticsProdViewsUnavailable;
    return Container(
      key: const Key('analytics-products-coverage-notice'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: colors.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.warningText),
            ),
          ),
        ],
      ),
    );
  }
}
