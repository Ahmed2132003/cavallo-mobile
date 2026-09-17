import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/cache_storage.dart';
import '../domain/category_entity.dart';
import '../domain/category_repository.dart';
import 'dtos/category_node_dto.dart';

/// New feature scope (Part P-033, STEP 6): [CategoryRepository]
/// implementation. Depends on `dioClientProvider` for the network call,
/// same convention as every other repository in this project — but is
/// the FIRST repository to also depend on `cacheStorageProvider`
/// (Part P-005), closing the exact gap P-025's and P-028A's own
/// handoff notes flagged ("CacheStorage ... already namespace-ready
/// for e.g. 'categories_tree'").
///
/// ### Why a local cache on top of the backend's own 1h cache
///
/// The backend already caches the built tree server-side for ~1h
/// (`categories/views.py`, `CATEGORY_TREE_CACHE_TTL_SECONDS = 3600`)
/// and self-invalidates on any Admin write (`categories/signals.py`).
/// That protects the DATABASE from repeated tree-building queries —
/// it does NOT save a network round-trip. A category picker opened
/// every time a business creates/edits a product would otherwise hit
/// the network on every single open, for data that is genuinely
/// static for up to an hour. Caching client-side too (same 1h TTL, so
/// this app is never more stale than the backend's own cache could
/// already be) turns every open after the first into a synchronous,
/// no-network read for the whole session's cache lifetime.
///
/// ### Cache shape
///
/// One [CacheStorage] key (`_cacheKey`) holds BOTH the timestamp and
/// the raw tree JSON together, as a single `Map` — not two separate
/// keys — so a read/write is always one [CacheStorage] call, and there
/// is no way for a timestamp and a tree to ever get out of sync with
/// each other.
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({required Dio dio, required CacheStorage cacheStorage})
    : _dio = dio,
      _cache = cacheStorage;

  final Dio _dio;
  final CacheStorage _cache;

  static const _treePath = '/api/v1/categories/tree/';
  static const _cacheKey = 'categories_tree';

  /// Matches the backend's own server-side TTL exactly (see this
  /// class's docstring) — this app is never staler than the backend's
  /// own cache could already independently be.
  static const _cacheTtl = Duration(hours: 1);

  @override
  Future<List<CategoryNode>> fetchCategoryTree({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readFreshCache();
      if (cached != null) return cached;
    }

    final response = await _dio.get<List<dynamic>>(_treePath);
    final rawTree = response.data ?? const <dynamic>[];
    await _writeCache(rawTree);
    return _parseTree(rawTree);
  }

  /// Returns the cached tree if a cache entry exists AND is still
  /// within [_cacheTtl] of when it was written; `null` in every other
  /// case (no entry yet, or an entry old enough to be considered
  /// stale) — either way, `null` tells [fetchCategoryTree] to hit the
  /// network.
  Future<List<CategoryNode>?> _readFreshCache() async {
    final cached = await _cache.get<Map<String, dynamic>>(_cacheKey);
    if (cached == null) return null;

    final cachedAtRaw = cached['cachedAt'] as String?;
    final cachedAt = cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw);
    if (cachedAt == null) return null;

    if (DateTime.now().difference(cachedAt) >= _cacheTtl) {
      return null;
    }

    final rawTree = cached['tree'] as List<dynamic>? ?? const [];
    return _parseTree(rawTree);
  }

  Future<void> _writeCache(List<dynamic> rawTree) async {
    await _cache.set<Map<String, dynamic>>(_cacheKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'tree': rawTree,
    });
  }

  List<CategoryNode> _parseTree(List<dynamic> rawTree) {
    return rawTree
        .map((e) => CategoryNodeDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }
}

/// Exposes [CategoryRepository] via Riverpod. A `FutureProvider`, not a
/// plain `Provider` like every other repository provider in this
/// project (`productRepositoryProvider`, etc.) — building this specific
/// repository needs `cacheStorageProvider.future` (itself async,
/// per Part P-005's own docstring), so the repository instance itself
/// can only be produced asynchronously. Callers read it via
/// `ref.watch(categoryRepositoryProvider.future)`, exactly as
/// `cacheStorageProvider` itself is already consumed elsewhere.
final categoryRepositoryProvider = FutureProvider<CategoryRepository>((
  ref,
) async {
  final cache = await ref.watch(cacheStorageProvider.future);
  final dio = ref.watch(dioClientProvider);
  return CategoryRepositoryImpl(dio: dio, cacheStorage: cache);
});