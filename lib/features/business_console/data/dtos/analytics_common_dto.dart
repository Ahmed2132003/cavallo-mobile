/// Part BI-04: wire parsing of the shapes shared by several endpoints
/// (api_contract_BI02.md): period, coverage, sales per currency, funnel and
/// page metadata.
library;

import '../../domain/analytics_common.dart';
import 'dto_parsing.dart';

abstract final class AnalyticsCommonDto {
  static AnalyticsPeriodInfo period(Map<String, dynamic> json, String path) {
    return AnalyticsPeriodInfo(
      dateFrom: DtoParsing.reqDate(json, 'date_from', path),
      dateTo: DtoParsing.reqDate(json, 'date_to', path),
      days: DtoParsing.reqInt(json, 'days', path),
      label: DtoParsing.optString(json, 'period', path),
    );
  }

  static AnalyticsCoverage coverage(Map<String, dynamic> json, String path) {
    return AnalyticsCoverage(
      daysInRange: DtoParsing.reqInt(json, 'days_in_range', path),
      rollupDays: DtoParsing.reqInt(json, 'rollup_days', path),
      viewsAvailable: DtoParsing.reqBool(json, 'views_available', path),
      viewsComplete: DtoParsing.reqBool(json, 'views_complete', path),
    );
  }

  static SalesEntry salesEntry(Map<String, dynamic> json, String path) {
    return SalesEntry(
      currency: DtoParsing.reqString(json, 'currency', path),
      salesValue: DtoParsing.reqMoney(json, 'sales_value', path),
      soldOrders: DtoParsing.optInt(json, 'sold_orders', path),
      units: DtoParsing.optInt(json, 'units', path),
      aov: DtoParsing.optMoney(json, 'aov', path),
    );
  }

  static List<SalesEntry> salesList(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final List<Map<String, dynamic>> items = DtoParsing.objects(
      json,
      key,
      path,
    );
    return <SalesEntry>[
      for (int i = 0; i < items.length; i++)
        salesEntry(items[i], '$path.$key[$i]'),
    ];
  }

  static Funnel funnel(Map<String, dynamic> json, String path) {
    final List<Map<String, dynamic>> stages = DtoParsing.objects(
      json,
      'stages',
      path,
    );
    final List<Map<String, dynamic>> conversions = DtoParsing.objects(
      json,
      'conversions',
      path,
    );
    return Funnel(
      stages: <FunnelStage>[
        for (int i = 0; i < stages.length; i++)
          FunnelStage(
            key: DtoParsing.reqString(stages[i], 'key', '$path.stages[$i]'),
            count: DtoParsing.optInt(stages[i], 'count', '$path.stages[$i]'),
          ),
      ],
      conversions: <FunnelConversion>[
        for (int i = 0; i < conversions.length; i++)
          FunnelConversion(
            from: DtoParsing.reqString(
              conversions[i],
              'from',
              '$path.conversions[$i]',
            ),
            to: DtoParsing.reqString(
              conversions[i],
              'to',
              '$path.conversions[$i]',
            ),
            rate: DtoParsing.optDouble(
              conversions[i],
              'rate',
              '$path.conversions[$i]',
            ),
          ),
      ],
      overallRate: DtoParsing.optDouble(json, 'overall_rate', path),
      unitNote: DtoParsing.optString(json, 'unit_note', path),
    );
  }

  static PageMeta pageMeta(Map<String, dynamic> json, String path) {
    return PageMeta(
      count: DtoParsing.reqInt(json, 'count', path),
      page: DtoParsing.reqInt(json, 'page', path),
      pageSize: DtoParsing.reqInt(json, 'page_size', path),
      totalPages: DtoParsing.reqInt(json, 'total_pages', path),
    );
  }
}
