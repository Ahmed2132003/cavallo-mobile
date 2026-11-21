import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/order.dart';
import '../domain/order_note.dart';
import '../domain/order_status.dart';
import '../domain/order_status_event.dart';
import 'dtos/order_dtos.dart';

/// Result of `POST /orders/from-chat/`: [created] is `true` for HTTP 201 and
/// `false` for HTTP 200 (the message already had an order; the SAME order is
/// returned and the request body was ignored by the server).
class CreatedOrderResult {
  const CreatedOrderResult({required this.order, required this.created});

  final Order order;
  final bool created;
}

/// A customer-side order with its customer-visible events.
class CustomerOrderDetail {
  const CustomerOrderDetail({required this.order, required this.events});

  final Order order;
  final OrderEvents events;
}

/// Part BI-03 — REST data layer for Merchant-Recorded Orders (`orders/urls.py`
/// mounted at `/api/v1/orders/`). Same convention as `ConversationRepository`:
/// every method catches [DioException] and rethrows the typed [ApiFailure].
///
/// Idempotency: `createFromChat` is safe to repeat. The backend allows ONE
/// order per source message and answers a repeat with HTTP 200 and the same
/// order, so a retry after a lost response never creates a duplicate.
class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  static const String _basePath = '/api/v1/orders/';

  /// POST /api/v1/orders/from-chat/. The server derives business, customer,
  /// product and currency itself; only these six fields are sent.
  Future<CreatedOrderResult> createFromChat({
    required int conversationId,
    required int sourceMessageId,
    required int quantity,
    required String agreedUnitPrice,
    String customerNote = '',
    String internalNote = '',
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>(
            '${_basePath}from-chat/',
            data: <String, dynamic>{
              'conversation_id': conversationId,
              'source_message_id': sourceMessageId,
              'quantity': quantity,
              'agreed_unit_price': agreedUnitPrice,
              'customer_note': customerNote,
              'internal_note': internalNote,
            },
          );
      return CreatedOrderResult(
        order: OrderDto.fromMerchantJson(response.data!).toEntity(),
        created: response.statusCode == 201,
      );
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET /api/v1/orders/ — the business's own orders (cursor-paginated,
  /// newest first). Filters: `status`, `search` (order number: 42, #42 or
  /// ORD-42). [cursor] is the opaque full `next` URL of a previous page; it
  /// already carries the filters, so none are re-sent with it.
  Future<PaginatedResponse<Order>> listOrders({
    OrderStatus? status,
    String? search,
    String? cursor,
  }) async {
    try {
      final String trimmed = (search ?? '').trim();
      final Response<dynamic> response = await _dio.get<dynamic>(
        cursor ?? _basePath,
        queryParameters:
            cursor != null
                ? null
                : <String, dynamic>{
                  if (status != null && status != OrderStatus.unknown)
                    'status': status.raw,
                  if (trimmed.isNotEmpty) 'search': trimmed,
                },
      );
      final dynamic data = response.data;
      Order parse(Map<String, dynamic> json) =>
          OrderDto.fromMerchantJson(json).toEntity();
      if (data is List) {
        return PaginatedResponse<Order>(
          results:
              data
                  .map((dynamic e) => parse(e as Map<String, dynamic>))
                  .toList(),
          next: null,
          previous: null,
        );
      }
      return PaginatedResponse.fromJson(data as Map<String, dynamic>, parse);
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET `/api/v1/orders/<id>/` (merchant).
  Future<Order> fetchOrder(int id) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>('$_basePath$id/');
      return OrderDto.fromMerchantJson(response.data!).toEntity();
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET `/api/v1/orders/<id>/events/` (merchant): every event, internal ones
  /// included, oldest first, not paginated.
  Future<OrderEvents> fetchOrderEvents(int id) async {
    try {
      final Response<List<dynamic>> response = await _dio.get<List<dynamic>>(
        '$_basePath$id/events/',
      );
      return mapOrderEvents(
        (response.data ?? const <dynamic>[]).map(
          (dynamic e) => OrderEventDto.fromJson(e as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// POST `/api/v1/orders/<id>/status/` `{status, note}`. The [note] is shown
  /// to the customer. Returns the updated order.
  Future<Order> changeStatus({
    required int orderId,
    required OrderStatus status,
    String note = '',
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>(
            '$_basePath$orderId/status/',
            data: <String, dynamic>{
              'status': status.raw,
              if (note.trim().isNotEmpty) 'note': note.trim(),
            },
          );
      return OrderDto.fromMerchantJson(response.data!).toEntity();
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// POST `/api/v1/orders/<id>/notes/` `{note, is_internal}` -> 201 event.
  Future<OrderNote> addNote({
    required int orderId,
    required String note,
    required bool isInternal,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>(
            '$_basePath$orderId/notes/',
            data: <String, dynamic>{
              'note': note.trim(),
              'is_internal': isInternal,
            },
          );
      return OrderEventDto.fromJson(response.data!).toNote();
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }

  /// GET `/api/v1/orders/my/<id>/` (customer): visible note + visible events
  /// only. Internal events are filtered again client-side.
  Future<CustomerOrderDetail> fetchMyOrder(int id) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>('${_basePath}my/$id/');
      final Map<String, dynamic> json = response.data!;
      final Object? rawEvents = json['events'];
      return CustomerOrderDetail(
        order: OrderDto.fromCustomerJson(json).toEntity(),
        events: mapOrderEvents(
          (rawEvents is List ? rawEvents : const <dynamic>[]).map(
            (dynamic e) => OrderEventDto.fromJson(e as Map<String, dynamic>),
          ),
          customerView: true,
        ),
      );
    } on DioException catch (e) {
      throw e.error as ApiFailure;
    }
  }
}

final Provider<OrdersRepository> ordersRepositoryProvider =
    Provider<OrdersRepository>((Ref ref) {
      return OrdersRepository(ref.watch(dioClientProvider));
    });
