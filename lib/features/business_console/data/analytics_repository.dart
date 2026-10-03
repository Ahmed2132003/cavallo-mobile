/// Part P-085 scope: the data-layer contract and implementation for the
/// Business Console's daily analytics.
///
/// ### Real backend contract (P-084, read from `cavallo-app/analytics/`)
///
/// `GET /api/v1/analytics/business/{id}/daily/`
///
/// * authenticated, OWNER-ONLY (401 / 404 / 403 / 400 in that order);
/// * optional inclusive filters `date_from` and `date_to`, ISO
///   `YYYY-MM-DD` (NOT `from`/`to`); `date_from > date_to` is a 400;
/// * cursor-paginated envelope `{"next", "previous", "results"}` — an
///   envelope, not a bare array — ordered NEWEST day first
///   (`DailyStatsCursorPagination`: `page_size` 30 by default, up to 100
///   via `?page_size=`);
/// * `date` is a UTC calendar date;
/// * one row per business per day that the rollup job has run for. A day
///   with no row means the rollup has not produced one (e.g. today before
///   the next run) — it is NOT the same as "zero activity", so this layer
///   never fills such gaps with zeros.
///
/// ### Behaviour
///
/// [fetchDailyStats] sends the range as `date_from`/`date_to` and asks for
/// a page as large as the range (capped at the server maximum of 100), so
/// one request normally returns everything. If the server still reports a
/// `next` page, it is followed using only the opaque `cursor` query value
/// against the app's own base URL — never the absolute `next` URL, whose
/// host may differ from the one the app talks to. The result is returned
/// ordered OLDEST first.
///
/// Failures follow the project convention (see
/// `NotificationRepositoryImpl`): the shared `ErrorInterceptor` has already
/// mapped transport/HTTP errors to a typed `ApiFailure`, which is rethrown
/// as-is. A response that does not match the contract becomes an
/// [UnknownFailure] rather than a partial or empty chart.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/daily_stats_entity.dart';
import 'dtos/daily_stats_response_dto.dart';

abstract class AnalyticsRepository {
  /// Daily stats rows for [businessId] between [from] and [to] inclusive
  /// (only their year/month/day are used), oldest first, exactly as the
  /// backend returned them — days without a row are absent.
  Future<List<DailyStats>> fetchDailyStats({
    required int businessId,
    required DateTime from,
    required DateTime to,
  });
}

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// The server's `max_page_size` for this endpoint.
  static const maxPageSize = 100;

  /// Upper bound on followed `next` links; a sane range needs exactly one
  /// request, so hitting this means something is wrong, not "load more".
  static const _maxPages = 10;

  static String dailyPath(int businessId) =>
      '/api/v1/analytics/business/$businessId/daily/';

  @override
  Future<List<DailyStats>> fetchDailyStats({
    required int businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final spanDays = _dayNumber(to) - _dayNumber(from) + 1;
    if (spanDays < 1) {
      throw ArgumentError.value(
        from,
        'from',
        'must be on or before `to` ($to).',
      );
    }
    final pageSize = spanDays > maxPageSize ? maxPageSize : spanDays;

    final rows = <DailyStats>[];
    String? cursor;
    try {
      for (var page = 0; page < _maxPages; page++) {
        final response = await _dio.get<dynamic>(
          dailyPath(businessId),
          queryParameters: {
            'date_from': _formatDate(from),
            'date_to': _formatDate(to),
            'page_size': pageSize,
            if (cursor != null) 'cursor': cursor,
          },
        );
        final body = response.data;
        if (body is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected a paginated object with "results", got '
            'something else (e.g. a bare array).',
          );
        }
        final envelope = PaginatedResponse.fromJson(
          body,
          (json) => DailyStatsResponseDto.fromJson(json).toEntity(),
        );
        rows.addAll(envelope.results);

        final next = envelope.next;
        if (next == null) {
          rows.sort((a, b) => a.date.compareTo(b.date));
          return rows;
        }
        cursor = Uri.parse(next).queryParameters['cursor'];
        if (cursor == null || cursor.isEmpty) {
          throw const FormatException(
            'Pagination "next" link carries no cursor.',
          );
        }
      }
      throw const FormatException('Daily stats pagination did not terminate.');
    } on DioException catch (e) {
      final error = e.error;
      if (error is ApiFailure) throw error;
      rethrow;
    } on FormatException catch (e) {
      throw UnknownFailure(
        message: 'Unexpected analytics response: ${e.message}',
      );
    } on TypeError {
      throw const UnknownFailure(
        message: 'Unexpected analytics response shape.',
      );
    }
  }

  /// Whole days since the epoch for the date's own y/m/d, immune to the
  /// time-of-day and time-zone of the [DateTime] passed in.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepositoryImpl(dio: ref.watch(dioClientProvider)),
);
