/// Part BI-04: wire parsing of the content list, content detail and the
/// external-metrics endpoint (plus the POST body).
library;

import '../../domain/analytics_content.dart';
import 'analytics_common_dto.dart';
import 'dto_parsing.dart';

abstract final class ContentDto {
  static ContentAnalyticsRow row(Map<String, dynamic> json, String path) {
    return ContentAnalyticsRow(
      contentType: DtoParsing.reqString(json, 'content_type', path),
      contentId: DtoParsing.reqInt(json, 'content_id', path),
      captionPreview: DtoParsing.optString(json, 'caption_preview', path) ?? '',
      status: DtoParsing.reqString(json, 'status', path),
      createdAt: DtoParsing.optDateTime(json, 'created_at', path),
      views: DtoParsing.optInt(json, 'views', path),
      uniqueViews: DtoParsing.optInt(json, 'unique_views', path),
      likes: DtoParsing.optInt(json, 'likes', path),
      comments: DtoParsing.optInt(json, 'comments', path),
      saves: DtoParsing.optInt(json, 'saves', path),
      inAppShares: DtoParsing.optInt(json, 'in_app_shares', path),
      engagementRate: DtoParsing.optDouble(json, 'engagement_rate', path),
    );
  }

  static ContentPage parsePage(Map<String, dynamic> json) {
    const String path = 'content response';
    final List<Map<String, dynamic>> items = DtoParsing.objects(
      json,
      'results',
      path,
    );
    return ContentPage(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      type: DtoParsing.reqString(json, 'type', path),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      meta: AnalyticsCommonDto.pageMeta(json, path),
      results: <ContentAnalyticsRow>[
        for (int i = 0; i < items.length; i++)
          row(items[i], '$path.results[$i]'),
      ],
      coverage: AnalyticsCommonDto.coverage(
        DtoParsing.reqMap(json, 'coverage', path),
        '$path.coverage',
      ),
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', path),
    );
  }

  static ContentMetrics metrics(Map<String, dynamic> json, String path) {
    return ContentMetrics(
      views: DtoParsing.optInt(json, 'views', path),
      uniqueViews: DtoParsing.optInt(json, 'unique_views', path),
      likes: DtoParsing.optInt(json, 'likes', path),
      comments: DtoParsing.optInt(json, 'comments', path),
      saves: DtoParsing.optInt(json, 'saves', path),
      inAppShares: DtoParsing.optInt(json, 'in_app_shares', path),
      engagementRate: DtoParsing.optDouble(json, 'engagement_rate', path),
    );
  }

  static ExternalMetric externalMetric(Map<String, dynamic> json, String path) {
    return ExternalMetric(
      platform: DtoParsing.reqString(json, 'platform', path),
      metricType: DtoParsing.reqString(json, 'metric_type', path),
      value: DtoParsing.reqInt(json, 'value', path),
      source: DtoParsing.reqString(json, 'source', path),
      lastUpdated: DtoParsing.optDateTime(json, 'last_updated', path),
      externalReference:
          DtoParsing.optString(json, 'external_reference', path) ?? '',
    );
  }

  static List<ExternalMetric> _externalList(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final List<Map<String, dynamic>> items = DtoParsing.objects(
      json,
      key,
      path,
    );
    return <ExternalMetric>[
      for (int i = 0; i < items.length; i++)
        externalMetric(items[i], '$path.$key[$i]'),
    ];
  }

  static ContentDetail parseDetail(Map<String, dynamic> json) {
    const String path = 'content detail response';
    final Map<String, dynamic> content = DtoParsing.reqMap(
      json,
      'content',
      path,
    );
    final Map<String, dynamic> internal = DtoParsing.reqMap(
      json,
      'internal',
      path,
    );
    final Map<String, dynamic> external = DtoParsing.reqMap(
      json,
      'external',
      path,
    );
    final List<Map<String, dynamic>> trend = DtoParsing.objects(
      internal,
      'trend',
      '$path.internal',
    );
    return ContentDetail(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      content: ContentHeader(
        contentType: DtoParsing.reqString(
          content,
          'content_type',
          '$path.content',
        ),
        contentId: DtoParsing.reqInt(content, 'content_id', '$path.content'),
        captionPreview:
            DtoParsing.optString(content, 'caption_preview', '$path.content') ??
            '',
        status: DtoParsing.reqString(content, 'status', '$path.content'),
        createdAt: DtoParsing.optDateTime(
          content,
          'created_at',
          '$path.content',
        ),
      ),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      internal: ContentInternalBlock(
        source: DtoParsing.reqString(internal, 'source', '$path.internal'),
        totals: metrics(
          DtoParsing.reqMap(internal, 'totals', '$path.internal'),
          '$path.internal.totals',
        ),
        trend: <ContentTrendPoint>[
          for (int i = 0; i < trend.length; i++)
            ContentTrendPoint(
              date: DtoParsing.reqDate(
                trend[i],
                'date',
                '$path.internal.trend[$i]',
              ),
              metrics: metrics(trend[i], '$path.internal.trend[$i]'),
            ),
        ],
        notes: DtoParsing.stringMap(internal, 'notes', '$path.internal'),
      ),
      external: ContentExternalBlock(
        metrics: _externalList(external, 'metrics', '$path.external'),
        note: DtoParsing.optString(external, 'note', '$path.external'),
      ),
      coverage: AnalyticsCommonDto.coverage(
        DtoParsing.reqMap(json, 'coverage', path),
        '$path.coverage',
      ),
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', path),
    );
  }

  static ExternalMetricsResponse parseExternalMetrics(
    Map<String, dynamic> json,
  ) {
    const String path = 'external metrics response';
    return ExternalMetricsResponse(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      contentType: DtoParsing.reqString(json, 'content_type', path),
      contentId: DtoParsing.reqInt(json, 'content_id', path),
      metrics: _externalList(json, 'metrics', path),
      providersRegistered: DtoParsing.strings(
        json,
        'providers_registered',
        path,
      ),
    );
  }

  /// Body of the manual-entry POST. `source` is never sent.
  static Map<String, Object> inputToJson(ExternalMetricInput input) {
    final DateTime? capturedAt = input.capturedAt;
    final String? reference = input.externalReference?.trim();
    return <String, Object>{
      'platform': input.platform,
      'metric_type': input.metricType,
      'metric_value': input.metricValue,
      if (capturedAt != null)
        'captured_at': capturedAt.toUtc().toIso8601String(),
      if (reference != null && reference.isNotEmpty)
        'external_reference': reference,
    };
  }
}
