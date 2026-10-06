import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/saved_item.dart';
import '../domain/saved_repository.dart';

/// Part P-113 (STEP 3B): [SavedRepository] over the shared Dio client (so the
/// Authorization header and the silent token refresh come for free).
///
/// Error convention: same as `NotificationRepositoryImpl` - catch
/// [DioException] and rethrow the typed [ApiFailure] that `ErrorInterceptor`
/// stored on `.error`, so callers only ever catch [ApiFailure].
class SavedRepositoryImpl implements SavedRepository {
  SavedRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String listPath = '/api/v1/saves/me/';

  @override
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor}) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(cursor ?? listPath);
      final Map<String, dynamic> json = response.data!;
      final List<dynamic> rawResults = json['results'] as List<dynamic>;

      final List<SavedItem> items = <SavedItem>[];
      for (final dynamic raw in rawResults) {
        final SavedItem? item = SavedItem.tryFromJson(
          raw as Map<String, dynamic>,
        );
        if (item != null) {
          items.add(item);
        }
      }

      return PaginatedResponse<SavedItem>(
        results: items,
        next: json['next'] as String?,
        previous: json['previous'] as String?,
      );
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  Never _rethrowTyped(DioException e) {
    final Object? error = e.error;
    if (error is ApiFailure) {
      throw error;
    }
    throw e;
  }
}

final Provider<SavedRepository> savedRepositoryProvider =
    Provider<SavedRepository>((Ref ref) {
      return SavedRepositoryImpl(dio: ref.watch(dioClientProvider));
    });
