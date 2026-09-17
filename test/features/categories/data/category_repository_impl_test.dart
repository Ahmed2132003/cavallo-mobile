import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/storage/cache_storage.dart';
import 'package:social_commerce_app/features/categories/data/category_repository_impl.dart';

/// A minimal in-memory [CacheStorage] fake — avoids needing a real
/// `shared_preferences` platform-channel binding in a plain
/// `flutter_test` unit test (unlike `SharedPreferencesCacheStorage`,
/// the real implementation). Honors the exact same typed get/set/
/// remove/clear contract the interface declares.
class _FakeCacheStorage implements CacheStorage {
  final Map<String, dynamic> _store = {};

  @override
  Future<T?> get<T>(String key) async => _store[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async => _store[key] = value;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeCacheStorage cache;
  late CategoryRepositoryImpl repository;
  var requestCount = 0;

  const treeJson = [
    {
      'id': 1,
      'name': 'Fashion',
      'slug': 'fashion',
      'children': [
        {'id': 2, 'name': 'Men', 'slug': 'men', 'children': []},
        {'id': 3, 'name': 'Women', 'slug': 'women', 'children': []},
      ],
    },
    {'id': 4, 'name': 'Electronics', 'slug': 'electronics', 'children': []},
  ];

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    // Counts real outgoing requests — the whole point of the tests
    // below is proving WHEN the network is (or isn't) actually hit,
    // which a mocked route being merely *registered* can't show on its
    // own (it stays matchable across multiple calls either way).
    requestCount = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.next(options);
        },
      ),
    );

    cache = _FakeCacheStorage();
    repository = CategoryRepositoryImpl(dio: dio, cacheStorage: cache);
  });

  test(
    'parses a nested {id, name, slug, children} tree on a cold cache',
    () async {
      adapter.onGet(
        '/api/v1/categories/tree/',
        (server) => server.reply(200, treeJson),
      );

      final tree = await repository.fetchCategoryTree();

      expect(tree, hasLength(2));
      expect(tree.first.name, 'Fashion');
      expect(tree.first.children, hasLength(2));
      expect(tree.first.children.first.name, 'Men');
      expect(tree.last.children, isEmpty);
      expect(requestCount, 1);
    },
  );

  test(
    'a second call within the TTL is served from cache — no second request',
    () async {
      adapter.onGet(
        '/api/v1/categories/tree/',
        (server) => server.reply(200, treeJson),
      );

      await repository.fetchCategoryTree();
      final second = await repository.fetchCategoryTree();

      expect(second, hasLength(2));
      expect(requestCount, 1);
    },
  );

  test(
    'forceRefresh: true bypasses a fresh cache and hits the network again',
    () async {
      adapter.onGet(
        '/api/v1/categories/tree/',
        (server) => server.reply(200, treeJson),
      );

      await repository.fetchCategoryTree();
      await repository.fetchCategoryTree(forceRefresh: true);

      expect(requestCount, 2);
    },
  );

  test('a stale cache entry (older than the TTL) is not served — refetches', () async {
    adapter.onGet(
      '/api/v1/categories/tree/',
      (server) => server.reply(200, treeJson),
    );

    await repository.fetchCategoryTree();
    expect(requestCount, 1);

    // Back-dates the cache entry past the 1-hour TTL, bypassing the
    // repository's own clock — the one piece of internal knowledge
    // (the exact cache key/shape) this test needs, since there is no
    // public API to simulate the passage of time otherwise.
    final cached = await cache.get<Map<String, dynamic>>('categories_tree');
    await cache.set<Map<String, dynamic>>('categories_tree', {
      ...cached!,
      'cachedAt': DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    });

    await repository.fetchCategoryTree();

    expect(requestCount, 2);
  });
}