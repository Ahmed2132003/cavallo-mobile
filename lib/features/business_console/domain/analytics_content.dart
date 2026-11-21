/// Part BI-04: content analytics (posts / reels), the content detail and the
/// external-metrics endpoint.
///
/// Gaps of the list row, by contract: NO thumbnail, NO external metrics, NO
/// last-updated per row. The thumbnail comes from the content feature by
/// `contentId`; external numbers come only from the detail or the
/// external-metrics endpoint. "Reach" does not exist anywhere. There is NO
/// "engagement" external metric type (only views, likes, shares, saves).
///
/// External numbers are MANUAL today (`providers_registered` is []). They
/// must never be labelled "live": [ExternalMetric.isManual] is true for
/// anything that is not explicitly `synced`.
library;

import 'analytics_common.dart';

enum ContentTypeFilter {
  all('all'),
  post('post'),
  reel('reel');

  const ContentTypeFilter(this.wire);

  /// The `type=` query value.
  final String wire;
}

/// Ordering keys of the content list (contract fields only).
enum ContentSort {
  mostViewed('-views'),
  mostLiked('-likes'),
  mostSaved('-saves'),
  mostShared('-in_app_shares'),
  highestEngagement('-engagement_rate'),
  newest('-created_at');

  const ContentSort(this.ordering);

  final String ordering;
}

const List<String> kExternalPlatforms = <String>[
  'instagram',
  'facebook',
  'tiktok',
];

const List<String> kExternalMetricTypes = <String>[
  'views',
  'likes',
  'shares',
  'saves',
];

class ContentAnalyticsRow {
  const ContentAnalyticsRow({
    required this.contentType,
    required this.contentId,
    required this.captionPreview,
    required this.status,
    required this.createdAt,
    required this.views,
    required this.uniqueViews,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.inAppShares,
    required this.engagementRate,
  });

  /// "post" | "reel".
  final String contentType;
  final int contentId;

  /// At most 80 characters (server-side).
  final String captionPreview;
  final String status;
  final DateTime? createdAt;
  final int? views;
  final int? uniqueViews;
  final int? likes;
  final int? comments;
  final int? saves;
  final int? inAppShares;

  /// (likes+comments+saves+in_app_shares)/unique_views, null when unknown.
  final double? engagementRate;
}

class ContentPage {
  const ContentPage({
    required this.businessId,
    required this.type,
    required this.period,
    required this.meta,
    required this.results,
    required this.coverage,
    required this.dataUpdatedAt,
  });

  final int businessId;
  final String type;
  final AnalyticsPeriodInfo period;
  final PageMeta meta;
  final List<ContentAnalyticsRow> results;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;
}

class ContentHeader {
  const ContentHeader({
    required this.contentType,
    required this.contentId,
    required this.captionPreview,
    required this.status,
    required this.createdAt,
  });

  final String contentType;
  final int contentId;
  final String captionPreview;
  final String status;
  final DateTime? createdAt;
}

/// Internal (in-app) numbers of one content item, as a total or one day.
class ContentMetrics {
  const ContentMetrics({
    required this.views,
    required this.uniqueViews,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.inAppShares,
    required this.engagementRate,
  });

  final int? views;
  final int? uniqueViews;
  final int? likes;
  final int? comments;
  final int? saves;
  final int? inAppShares;
  final double? engagementRate;
}

class ContentTrendPoint {
  const ContentTrendPoint({required this.date, required this.metrics});

  final DateTime date;
  final ContentMetrics metrics;

  int? get views => metrics.views;
  int? get uniqueViews => metrics.uniqueViews;
  int? get likes => metrics.likes;
  int? get comments => metrics.comments;
  int? get saves => metrics.saves;
  int? get inAppShares => metrics.inAppShares;
  double? get engagementRate => metrics.engagementRate;
}

class ContentInternalBlock {
  const ContentInternalBlock({
    required this.source,
    required this.totals,
    required this.trend,
    required this.notes,
  });

  /// "internal_events".
  final String source;
  final ContentMetrics totals;
  final List<ContentTrendPoint> trend;

  /// Server notes by key ("in_app_shares", "reach").
  final Map<String, String> notes;
}

class ExternalMetric {
  const ExternalMetric({
    required this.platform,
    required this.metricType,
    required this.value,
    required this.source,
    required this.lastUpdated,
    required this.externalReference,
  });

  /// instagram | facebook | tiktok
  final String platform;

  /// views | likes | shares | saves
  final String metricType;
  final int value;

  /// "manual" | "synced".
  final String source;
  final DateTime? lastUpdated;
  final String externalReference;

  /// Anything not explicitly "synced" is treated as manual: never "live".
  bool get isManual => source != 'synced';
}

class ContentExternalBlock {
  const ContentExternalBlock({required this.metrics, required this.note});

  final List<ExternalMetric> metrics;
  final String? note;
}

class ContentDetail {
  const ContentDetail({
    required this.businessId,
    required this.content,
    required this.period,
    required this.internal,
    required this.external,
    required this.coverage,
    required this.dataUpdatedAt,
  });

  final int businessId;
  final ContentHeader content;
  final AnalyticsPeriodInfo period;

  /// Internal and external stay separate: never merge them in the UI.
  final ContentInternalBlock internal;
  final ContentExternalBlock external;
  final AnalyticsCoverage coverage;
  final DateTime? dataUpdatedAt;

  String get contentType => content.contentType;
  int get contentId => content.contentId;
  String get captionPreview => content.captionPreview;
  String get status => content.status;
  DateTime? get createdAt => content.createdAt;
}

typedef ContentAnalyticsDetail = ContentDetail;

extension ContentAnalyticsDetailPresentation on ContentDetail {
  String get contentType => content.contentType;
  int get contentId => content.contentId;
  String get captionPreview => content.captionPreview;
  String get status => content.status;
  DateTime? get createdAt => content.createdAt;
}

class ExternalMetricsResponse {
  const ExternalMetricsResponse({
    required this.businessId,
    required this.contentType,
    required this.contentId,
    required this.metrics,
    required this.providersRegistered,
  });

  final int businessId;
  final String contentType;
  final int contentId;

  /// Only the LATEST snapshot per (platform, metric_type); only metrics that
  /// were entered appear.
  final List<ExternalMetric> metrics;

  /// [] today: nothing is synced.
  final List<String> providersRegistered;
}

/// Body of `POST .../external-metrics/`. `source` cannot be sent (always
/// manual on the server).
class ExternalMetricInput {
  ExternalMetricInput({
    required this.platform,
    required this.metricType,
    required this.metricValue,
    this.capturedAt,
    this.externalReference,
  }) {
    if (!kExternalPlatforms.contains(platform)) {
      throw ArgumentError.value(platform, 'platform', 'unknown platform.');
    }
    if (!kExternalMetricTypes.contains(metricType)) {
      throw ArgumentError.value(metricType, 'metricType', 'unknown type.');
    }
    if (metricValue < 0) {
      throw ArgumentError.value(metricValue, 'metricValue', 'must be >= 0.');
    }
  }

  final String platform;
  final String metricType;
  final int metricValue;

  /// Must not be in the future (the server rejects it with a 400).
  final DateTime? capturedAt;
  final String? externalReference;
}
