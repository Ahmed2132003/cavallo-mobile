/// Part BI-04: wire parsing of the orders-summary response.
library;

import '../../../orders/domain/order_status.dart';
import '../../domain/analytics_orders_summary.dart';
import 'analytics_common_dto.dart';
import 'dto_parsing.dart';

abstract final class OrdersSummaryDto {
  static OrdersSummary parse(Map<String, dynamic> json) {
    const String path = 'orders summary response';
    final List<Map<String, dynamic>> statuses = DtoParsing.objects(
      json,
      'by_status',
      path,
    );
    final List<Map<String, dynamic>> trend = DtoParsing.objects(
      json,
      'trend',
      path,
    );
    final List<Map<String, dynamic>> top = DtoParsing.objects(
      json,
      'top_products',
      path,
    );
    return OrdersSummary(
      businessId: DtoParsing.reqInt(json, 'business_id', path),
      period: AnalyticsCommonDto.period(
        DtoParsing.reqMap(json, 'period', path),
        '$path.period',
      ),
      orders: DtoParsing.reqInt(json, 'orders', path),
      units: DtoParsing.reqInt(json, 'units', path),
      byStatus: <OrderStatusCount>[
        for (int i = 0; i < statuses.length; i++)
          OrderStatusCount(
            status: OrderStatus.fromRaw(
              DtoParsing.reqString(
                statuses[i],
                'status',
                '$path.by_status[$i]',
              ),
            ),
            orders: DtoParsing.reqInt(
              statuses[i],
              'orders',
              '$path.by_status[$i]',
            ),
          ),
      ],
      sales: AnalyticsCommonDto.salesList(json, 'sales', path),
      salesDefinition: DtoParsing.optString(json, 'sales_definition', path),
      trend: <OrdersTrendPoint>[
        for (int i = 0; i < trend.length; i++)
          OrdersTrendPoint(
            date: DtoParsing.reqDate(trend[i], 'date', '$path.trend[$i]'),
            orders: DtoParsing.reqInt(trend[i], 'orders', '$path.trend[$i]'),
            soldOrders: DtoParsing.reqInt(
              trend[i],
              'sold_orders',
              '$path.trend[$i]',
            ),
            sales: DtoParsing.moneyMap(trend[i], 'sales', '$path.trend[$i]'),
          ),
      ],
      topProducts: <TopProduct>[
        for (int i = 0; i < top.length; i++)
          TopProduct(
            productId: DtoParsing.reqInt(
              top[i],
              'product_id',
              '$path.top_products[$i]',
            ),
            name: DtoParsing.reqString(
              top[i],
              'name',
              '$path.top_products[$i]',
            ),
            currency: DtoParsing.reqString(
              top[i],
              'currency',
              '$path.top_products[$i]',
            ),
            salesValue: DtoParsing.reqMoney(
              top[i],
              'sales_value',
              '$path.top_products[$i]',
            ),
            soldOrders: DtoParsing.reqInt(
              top[i],
              'sold_orders',
              '$path.top_products[$i]',
            ),
            units: DtoParsing.reqInt(top[i], 'units', '$path.top_products[$i]'),
          ),
      ],
      dataUpdatedAt: DtoParsing.optDateTime(json, 'data_updated_at', path),
    );
  }
}
