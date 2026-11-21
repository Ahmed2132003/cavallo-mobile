/// Part BI-04: the shared period selector shown above the five sections.
///
/// One provider (`analyticsPeriodProvider`) feeds every section, so a change
/// here re-requests all visible sections against the same window.
/// Presets: last 7 / 14 / 30 / 90 days, this month, previous month, custom
/// range. Days are UTC calendar days; rolling presets end yesterday.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../domain/analytics_period.dart';
import '../analytics_provider.dart' show analyticsNowProvider;
import '../providers/analytics_period_provider.dart';

class AnalyticsPeriodBar extends ConsumerWidget {
  const AnalyticsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AnalyticsPeriod period = ref.watch(analyticsPeriodProvider);
    final AnalyticsPeriodNotifier notifier = ref.read(
      analyticsPeriodProvider.notifier,
    );

    final List<(AnalyticsPreset, String, String)> chips =
        <(AnalyticsPreset, String, String)>[
          (AnalyticsPreset.last7, 'last7', l10n.biPresetLast7),
          (AnalyticsPreset.last14, 'last14', l10n.biPresetLast14),
          (AnalyticsPreset.last30, 'last30', l10n.biPresetLast30),
          (AnalyticsPreset.last90, 'last90', l10n.biPresetLast90),
          (AnalyticsPreset.thisMonth, 'this-month', l10n.biPresetThisMonth),
          (
            AnalyticsPreset.previousMonth,
            'previous-month',
            l10n.biPresetPreviousMonth,
          ),
          (AnalyticsPreset.custom, 'custom', l10n.biPresetCustom),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              for (final (AnalyticsPreset, String, String) chip in chips)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    key: ValueKey<String>('bi-preset-${chip.$2}'),
                    label: Text(chip.$3),
                    selected: period.preset == chip.$1,
                    onSelected: (_) {
                      if (chip.$1 == AnalyticsPreset.custom) {
                        _pickCustom(context, ref, period);
                      } else {
                        notifier.selectPreset(chip.$1);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.biPeriodRange(
              AnalyticsPeriod.formatDate(period.from),
              AnalyticsPeriod.formatDate(period.to),
            ),
            key: const ValueKey<String>('bi-period-range'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Text(
            l10n.biPeriodNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    AnalyticsPeriod current,
  ) async {
    final l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // The picker works with local dates; only the picked year/month/day are
    // used and they are read as UTC calendar dates (no hour shifting).
    final DateTime nowUtc = ref.read(analyticsNowProvider)().toUtc();
    final DateTime last = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
    final DateTime first = DateTime(last.year - 2, last.month, last.day);

    DateTime clamp(DateTime date) {
      if (date.isBefore(first)) return first;
      if (date.isAfter(last)) return last;
      return date;
    }

    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: DateTimeRange(
        start: clamp(
          DateTime(current.from.year, current.from.month, current.from.day),
        ),
        end: clamp(DateTime(current.to.year, current.to.month, current.to.day)),
      ),
    );
    if (range == null || !context.mounted) return;

    final DateTime start = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final DateTime end = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    final int days = end.difference(start).inDays + 1;
    if (days > AnalyticsPeriod.maxDays) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.biRangeTooLong(AnalyticsPeriod.maxDays))),
      );
      return;
    }
    ref.read(analyticsPeriodProvider.notifier).selectCustom(start, end);
  }
}
