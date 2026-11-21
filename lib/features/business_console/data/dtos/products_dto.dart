/// Part BI-04: wire parsing of the products list and product detail.
library;

import '../../domain/analytics_products.dart';
import 'analytics_common_dto.dart';
import 'dto_parsing.dart';

abstract final class ProductsDto {
  static ProductAnalyticsRow row(Map<String, dynamic> json, String path) {
    return ProductAnalyticsRow(
      productId: DtoParsing.reqInt(json, 'product_id', path),
      name: DtoParsing.reqString(json, 'name', path),
      isActive: DtoParsing.reqBool(json, 'is_active', path),
      currency: DtoParsing.reqString(json, 'currency', path),
      views: DtoParsing.optInt(json, 'views', path),
      uniqueViews: DtoParsing.optInt(json, 'unique_views', path),
      interests: DtoParsing.reqInt(json, 'interests', path),
      saves: DtoParsing.optInt(json, 'saves', path),
      orders: DtoParsing.reqInt(json, 'orders', path),
      soldOrders: DtoParsing.reqInt(json, 'sold_orders', path),
      units: DtoParsing.reqInt(json, 'units', path),
      sales: AnalyticsCommonDto.salesList(json, 'sales', path),
      conversion: DtoParsing.optDouble(json, 'conversion', path),
    );
  }

  static ProductsPage parsePage(Map<String, dynamic> json) {
    const String path = 'products response';
    final List<Map<String, dynamic>> items = DtoParsing.objects(
      json,
      'results',
      path,
    );
    return ProductsPage(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      meta: AnalyticsCommonDto.pageMeta(json, path),
      results: <ProductAnalyticsRow>[
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

  static ProductAnalyticsDetail parseDetail(Map<String, dynamic> json) {
    const String path = 'product detail response';
    final Map<String, dynamic> product = DtoParsing.reqMap(
      json,
      'product',
      path,
    );
    final Map<String, dynamic> totals = DtoParsing.reqMap(json, 'totals', path);
    final List<Map<String, dynamic>> trend = DtoParsing.objects(
      json,
      'trend',
      path,
    );
    return ProductAnalyticsDetail(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      product: ProductAnalyticsHeader(
        productId: DtoParsing.reqInt(product, 'product_id', '$path.product'),
        name: DtoParsing.reqString(product, 'name', '$path.product'),
        currency: DtoParsing.reqString(product, 'currency', '$path.product'),
        isActive: DtoParsing.reqBool(product, 'is_active', '$path.product'),
      ),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      totals: ProductTotals(
        views: DtoParsing.optInt(totals, 'views', '$path.totals'),
        uniqueViews: DtoParsing.optInt(totals, 'unique_views', '$path.totals'),
        saves: DtoParsing.optInt(totals, 'saves', '$path.totals'),
        interests: DtoParsing.reqInt(totals, 'interests', '$path.totals'),
        orders: DtoParsing.reqInt(totals, 'orders', '$path.totals'),
        soldOrders: DtoParsing.reqInt(totals, 'sold_orders', '$path.totals'),
        units: DtoParsing.reqInt(totals, 'units', '$path.totals'),
        sales: AnalyticsCommonDto.salesList(totals, 'sales', '$path.totals'),
        conversion: DtoParsing.optDouble(totals, 'conversion', '$path.totals'),
      ),
      interestedCustomers: DtoParsing.reqInt(
        json,
        'interested_customers',
        path,
      ),
      funnel: AnalyticsCommonDto.funnel(
        DtoParsing.reqMap(json, 'funnel', path),
        '$path.funnel',
      ),
      trend: <ProductTrendPoint>[
        for (int i = 0; i < trend.length; i++)
          ProductTrendPoint(
            date: DtoParsing.reqDate(trend[i], 'date', '$path.trend[$i]'),
            views: DtoParsing.optInt(trend[i], 'views', '$path.trend[$i]'),
            uniqueViews: DtoParsing.optInt(
              trend[i],
              'unique_views',
              '$path.trend[$i]',
            ),
            interests: DtoParsing.optInt(
              trend[i],
              'interests',
              '$path.trend[$i]',
            ),
            orders: DtoParsing.reqInt(trend[i], 'orders', '$path.trend[$i]'),
            soldOrders: DtoParsing.reqInt(
              trend[i],
              'sold_orders',
              '$path.trend[$i]',
            ),
            sales: DtoParsing.moneyMap(trend[i], 'sales', '$path.trend[$i]'),
          ),
      ],
      coverage: AnalyticsCommonDto.coverage(
        DtoParsing.reqMap(json, 'coverage', path),
        '$path.coverage',
      ),
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', path),
      ordersDataUpdatedAt: DtoParsing.optDateTime(
        json,
        'orders_data_updated_at',
        path,
      ),
    );
  }
}
