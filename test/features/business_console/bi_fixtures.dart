// Part BI-04 (tests): wire-shaped JSON builders that follow
// api_contract_BI02.md literally, plus entity helpers that build the entities
// through the REAL DTOs. Nullable parameters default to a value; pass null
// explicitly to get the contract's "not available" null.
import 'package:social_commerce_app/features/business_console/data/dtos/content_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/orders_summary_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/overview_dto.dart';
import 'package:social_commerce_app/features/business_console/data/dtos/products_dto.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_orders_summary.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_overview.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';

Map<String, dynamic> biPeriodJson({
  String dateFrom = '2026-10-01',
  String dateTo = '2026-10-07',
  int days = 7,
  String? label = '7d',
}) => <String, dynamic>{
  'date_from': dateFrom,
  'date_to': dateTo,
  'days': days,
  if (label != null) 'period': label,
};

Map<String, dynamic> biCoverageJson({
  int daysInRange = 7,
  int rollupDays = 7,
  bool viewsAvailable = true,
  bool viewsComplete = true,
}) => <String, dynamic>{
  'days_in_range': daysInRange,
  'rollup_days': rollupDays,
  'views_available': viewsAvailable,
  'views_complete': viewsComplete,
};

Map<String, dynamic> biSalesJson({
  String currency = 'EGP',
  String value = '300.00',
  int? soldOrders = 2,
  int? units = 4,
  String? aov = '150.00',
}) => <String, dynamic>{
  'currency': currency,
  'sales_value': value,
  if (soldOrders != null) 'sold_orders': soldOrders,
  if (units != null) 'units': units,
  if (aov != null) 'aov': aov,
};

Map<String, dynamic> biOverviewMetricsJson({
  int? productViews = 100,
  int? productUniqueViews = 80,
  int interests = 20,
  int interestedCustomers = 15,
  int orders = 10,
  int pendingOrders = 2,
  int confirmedOrders = 5,
  int completedOrders = 3,
  int cancelledOrders = 0,
  int units = 12,
  List<Map<String, dynamic>>? sales,
  int? contentViews = 500,
  int? contentUniqueViews = 400,
  int? likes = 40,
  int? comments = 8,
  int? saves = 6,
  int? inAppShares = 4,
}) => <String, dynamic>{
  'product_views': productViews,
  'product_unique_views': productUniqueViews,
  'interests': interests,
  'interested_customers': interestedCustomers,
  'orders': orders,
  'pending_orders': pendingOrders,
  'confirmed_orders': confirmedOrders,
  'completed_orders': completedOrders,
  'cancelled_orders': cancelledOrders,
  'units': units,
  'sales': sales ?? <Map<String, dynamic>>[biSalesJson()],
  'content_views': contentViews,
  'content_unique_views': contentUniqueViews,
  'likes': likes,
  'comments': comments,
  'saves': saves,
  'in_app_shares': inAppShares,
};

const List<String> _funnelKeys = <String>[
  'views',
  'interests',
  'orders',
  'confirmed',
  'completed',
];

Map<String, dynamic> biFunnelJson({
  List<int?> counts = const <int?>[80, 20, 10, 8, 3],
  List<double?> rates = const <double?>[0.25, 0.5, 0.8, 0.375],
  double? overallRate = 0.0375,
  String unitNote = 'Views are unique views; the rest are distinct customers.',
}) => <String, dynamic>{
  'unit_note': unitNote,
  'stages': <Map<String, dynamic>>[
    for (int i = 0; i < _funnelKeys.length; i++)
      <String, dynamic>{'key': _funnelKeys[i], 'count': counts[i]},
  ],
  'conversions': <Map<String, dynamic>>[
    for (int i = 0; i < _funnelKeys.length - 1; i++)
      <String, dynamic>{
        'from': _funnelKeys[i],
        'to': _funnelKeys[i + 1],
        'rate': rates[i],
      },
  ],
  'overall_rate': overallRate,
};

Map<String, dynamic> biDeltaJson({
  num? current,
  num? previous,
  num? change,
  double? changePct,
}) => <String, dynamic>{
  'current': current,
  'previous': previous,
  'change': change,
  'change_pct': changePct,
};

Map<String, dynamic> biPreviousPeriodJson({Map<String, dynamic>? deltas}) =>
    <String, dynamic>{
      'period': biPeriodJson(
        dateFrom: '2026-09-24',
        dateTo: '2026-09-30',
        label: null,
      ),
      'overview': biOverviewMetricsJson(orders: 8),
      'funnel': biFunnelJson(),
      'coverage': biCoverageJson(),
      'data_updated_at': '2026-10-01T02:00:00Z',
      'deltas':
          deltas ??
          <String, dynamic>{
            'orders': biDeltaJson(
              current: 10,
              previous: 8,
              change: 2,
              changePct: 0.25,
            ),
            'likes': biDeltaJson(
              current: 40,
              previous: 0,
              change: 40,
              changePct: null,
            ),
          },
    };

Map<String, dynamic> biOverviewJson({
  Map<String, dynamic>? overview,
  Map<String, dynamic>? funnel,
  Map<String, dynamic>? previousPeriod,
  Map<String, dynamic>? coverage,
  String? dataUpdatedAt = '2026-10-08T02:00:00Z',
  String? ordersDataUpdatedAt = '2026-10-08T09:30:00Z',
}) => <String, dynamic>{
  'business_id': 42,
  'period': biPeriodJson(),
  'overview': overview ?? biOverviewMetricsJson(),
  'funnel': funnel ?? biFunnelJson(),
  'previous_period': previousPeriod,
  'coverage': coverage ?? biCoverageJson(),
  'data_updated_at': dataUpdatedAt,
  'orders_data_updated_at': ordersDataUpdatedAt,
};

Map<String, dynamic> biProductRowJson({
  int productId = 1,
  String name = 'Leather belt',
  bool isActive = true,
  String currency = 'EGP',
  int? views = 100,
  int? uniqueViews = 80,
  int interests = 10,
  int? saves = 5,
  int orders = 4,
  int soldOrders = 3,
  int units = 6,
  List<Map<String, dynamic>>? sales,
  double? conversion = 0.0375,
}) => <String, dynamic>{
  'product_id': productId,
  'name': name,
  'is_active': isActive,
  'currency': currency,
  'views': views,
  'unique_views': uniqueViews,
  'interests': interests,
  'saves': saves,
  'orders': orders,
  'sold_orders': soldOrders,
  'units': units,
  'sales':
      sales ??
      <Map<String, dynamic>>[
        biSalesJson(value: '450.00', soldOrders: null, units: null, aov: null),
      ],
  'conversion': conversion,
};

Map<String, dynamic> biProductsPageJson({
  List<Map<String, dynamic>>? results,
  int? count,
  int page = 1,
  int pageSize = 20,
  int totalPages = 1,
  Map<String, dynamic>? coverage,
}) {
  final List<Map<String, dynamic>> rows =
      results ?? <Map<String, dynamic>>[biProductRowJson()];
  return <String, dynamic>{
    'business_id': 42,
    'period': biPeriodJson(),
    'count': count ?? rows.length,
    'page': page,
    'page_size': pageSize,
    'total_pages': totalPages,
    'results': rows,
    'coverage': coverage ?? biCoverageJson(),
    'data_updated_at': '2026-10-08T02:00:00Z',
  };
}

Map<String, dynamic> biProductDetailJson({
  Map<String, dynamic>? totals,
  List<Map<String, dynamic>>? trend,
  Map<String, dynamic>? funnel,
}) => <String, dynamic>{
  'business_id': 42,
  'product': <String, dynamic>{
    'product_id': 1,
    'name': 'Leather belt',
    'currency': 'EGP',
    'is_active': true,
  },
  'period': biPeriodJson(),
  'totals':
      totals ??
      <String, dynamic>{
        'views': 100,
        'unique_views': 80,
        'saves': 5,
        'interests': 10,
        'orders': 4,
        'sold_orders': 3,
        'units': 6,
        'sales': <Map<String, dynamic>>[biSalesJson()],
        'conversion': 0.0375,
      },
  'interested_customers': 9,
  'funnel': funnel ?? biFunnelJson(),
  'trend':
      trend ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-10-01',
          'views': 10,
          'unique_views': 8,
          'interests': 1,
          'orders': 1,
          'sold_orders': 1,
          'sales': <String, dynamic>{'EGP': '150.00'},
        },
        <String, dynamic>{
          'date': '2026-10-02',
          'views': null,
          'unique_views': null,
          'interests': null,
          'orders': 0,
          'sold_orders': 0,
          'sales': <String, dynamic>{},
        },
      ],
  'coverage': biCoverageJson(),
  'data_updated_at': '2026-10-08T02:00:00Z',
  'orders_data_updated_at': '2026-10-08T09:30:00Z',
};

Map<String, dynamic> biContentRowJson({
  String contentType = 'post',
  int contentId = 5,
  String caption = 'Summer sale',
  String status = 'published',
  String? createdAt = '2026-09-30T10:00:00Z',
  int? views = 200,
  int? uniqueViews = 150,
  int? likes = 30,
  int? comments = 6,
  int? saves = 4,
  int? inAppShares = 2,
  double? engagementRate = 0.28,
}) => <String, dynamic>{
  'content_type': contentType,
  'content_id': contentId,
  'caption_preview': caption,
  'status': status,
  'created_at': createdAt,
  'views': views,
  'unique_views': uniqueViews,
  'likes': likes,
  'comments': comments,
  'saves': saves,
  'in_app_shares': inAppShares,
  'engagement_rate': engagementRate,
};

Map<String, dynamic> biContentPageJson({
  List<Map<String, dynamic>>? results,
  int? count,
  String type = 'all',
  int page = 1,
  int pageSize = 20,
  int totalPages = 1,
  Map<String, dynamic>? coverage,
}) {
  final List<Map<String, dynamic>> rows =
      results ?? <Map<String, dynamic>>[biContentRowJson()];
  return <String, dynamic>{
    'business_id': 42,
    'type': type,
    'period': biPeriodJson(),
    'count': count ?? rows.length,
    'page': page,
    'page_size': pageSize,
    'total_pages': totalPages,
    'results': rows,
    'coverage': coverage ?? biCoverageJson(),
    'data_updated_at': '2026-10-08T02:00:00Z',
  };
}

Map<String, dynamic> biContentMetricsJson({
  int? views = 200,
  int? uniqueViews = 150,
  int? likes = 30,
  int? comments = 6,
  int? saves = 4,
  int? inAppShares = 2,
  double? engagementRate = 0.28,
}) => <String, dynamic>{
  'views': views,
  'unique_views': uniqueViews,
  'likes': likes,
  'comments': comments,
  'saves': saves,
  'in_app_shares': inAppShares,
  'engagement_rate': engagementRate,
};

Map<String, dynamic> biExternalMetricJson({
  String platform = 'instagram',
  String metricType = 'views',
  int value = 1200,
  String source = 'manual',
  String? lastUpdated = '2026-10-05T12:00:00Z',
  String externalReference = '',
}) => <String, dynamic>{
  'platform': platform,
  'metric_type': metricType,
  'value': value,
  'source': source,
  'last_updated': lastUpdated,
  'external_reference': externalReference,
};

Map<String, dynamic> biContentDetailJson({
  Map<String, dynamic>? totals,
  List<Map<String, dynamic>>? trend,
  List<Map<String, dynamic>>? externalMetrics,
  String? externalNote = 'Manual numbers entered by the merchant.',
}) => <String, dynamic>{
  'business_id': 42,
  'content': <String, dynamic>{
    'content_type': 'post',
    'content_id': 5,
    'caption_preview': 'Summer sale',
    'status': 'published',
    'created_at': '2026-09-30T10:00:00Z',
  },
  'period': biPeriodJson(),
  'internal': <String, dynamic>{
    'source': 'internal_events',
    'totals': totals ?? biContentMetricsJson(),
    'trend':
        trend ??
        <Map<String, dynamic>>[
          <String, dynamic>{'date': '2026-10-01', ...biContentMetricsJson()},
        ],
    'notes': <String, dynamic>{
      'in_app_shares':
          'In-app share events only; they do not prove any external view.',
      'reach': 'Not defined: there is no reliable source for it.',
    },
  },
  'external': <String, dynamic>{
    'metrics':
        externalMetrics ?? <Map<String, dynamic>>[biExternalMetricJson()],
    'note': externalNote,
  },
  'coverage': biCoverageJson(),
  'data_updated_at': '2026-10-08T02:00:00Z',
};

Map<String, dynamic> biExternalMetricsJson({
  List<Map<String, dynamic>>? metrics,
  List<String> providers = const <String>[],
}) => <String, dynamic>{
  'business_id': 42,
  'content_type': 'post',
  'content_id': 5,
  'metrics': metrics ?? <Map<String, dynamic>>[biExternalMetricJson()],
  'providers_registered': providers,
};

Map<String, dynamic> biOrdersSummaryJson({
  int orders = 10,
  int units = 12,
  List<Map<String, dynamic>>? byStatus,
  List<Map<String, dynamic>>? sales,
  List<Map<String, dynamic>>? trend,
  List<Map<String, dynamic>>? topProducts,
}) => <String, dynamic>{
  'business_id': 42,
  'period': biPeriodJson(),
  'orders': orders,
  'units': units,
  'by_status':
      byStatus ??
      <Map<String, dynamic>>[
        for (final MapEntry<String, int> e
            in <String, int>{
              'pending': 2,
              'confirmed': 3,
              'processing': 1,
              'shipped': 1,
              'delivered': 3,
              'cancelled': 0,
            }.entries)
          <String, dynamic>{'status': e.key, 'orders': e.value},
      ],
  'sales': sales ?? <Map<String, dynamic>>[biSalesJson()],
  'sales_definition':
      'Sales Value = confirmed + processing + shipped + delivered.',
  'trend':
      trend ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-10-01',
          'orders': 3,
          'sold_orders': 2,
          'sales': <String, dynamic>{'EGP': '300.00'},
        },
        <String, dynamic>{
          'date': '2026-10-02',
          'orders': 0,
          'sold_orders': 0,
          'sales': <String, dynamic>{},
        },
      ],
  'top_products':
      topProducts ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 1,
          'name': 'Leather belt',
          'currency': 'EGP',
          'sales_value': '450.00',
          'sold_orders': 3,
          'units': 6,
        },
      ],
  'data_updated_at': '2026-10-08T09:30:00Z',
};

AnalyticsOverview biOverview([Map<String, dynamic>? json]) =>
    OverviewDto.parse(json ?? biOverviewJson());

ProductsPage biProductsPage([Map<String, dynamic>? json]) =>
    ProductsDto.parsePage(json ?? biProductsPageJson());

ProductAnalyticsDetail biProductDetail([Map<String, dynamic>? json]) =>
    ProductsDto.parseDetail(json ?? biProductDetailJson());

ContentPage biContentPage([Map<String, dynamic>? json]) =>
    ContentDto.parsePage(json ?? biContentPageJson());

ContentDetail biContentDetail([Map<String, dynamic>? json]) =>
    ContentDto.parseDetail(json ?? biContentDetailJson());

ExternalMetricsResponse biExternalMetrics([Map<String, dynamic>? json]) =>
    ContentDto.parseExternalMetrics(json ?? biExternalMetricsJson());

OrdersSummary biOrdersSummary([Map<String, dynamic>? json]) =>
    OrdersSummaryDto.parse(json ?? biOrdersSummaryJson());
