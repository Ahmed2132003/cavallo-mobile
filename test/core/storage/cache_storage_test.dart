import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_commerce_app/core/storage/cache_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The mock mechanism the part spec calls for — an empty in-memory
    // backing store for every SharedPreferences.getInstance() call made
    // after this.
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesCacheStorage', () {
    test('set then get round-trips a JSON object (Map) value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);

      await storage.set('categories', {'id': 1, 'name': 'Fashion'});
      final result = await storage.get<Map<String, dynamic>>('categories');

      expect(result, {'id': 1, 'name': 'Fashion'});
    });

    test('set then get round-trips a JSON array (List) value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);

      await storage.set('recent_ids', [1, 2, 3]);
      final result = await storage.get<List<dynamic>>('recent_ids');

      expect(result, [1, 2, 3]);
    });

    test('set then get round-trips a primitive value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);

      await storage.set('page_size', 20);

      expect(await storage.get<int>('page_size'), 20);
    });

    test('get returns null for a key that was never set', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);

      expect(await storage.get<Map<String, dynamic>>('missing'), isNull);
    });

    test('remove deletes only the given key', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);
      await storage.set('a', 1);
      await storage.set('b', 2);

      await storage.remove('a');

      expect(await storage.get<int>('a'), isNull);
      expect(await storage.get<int>('b'), 2);
    });

    test('clear wipes every key', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);
      await storage.set('a', 1);
      await storage.set('b', 2);

      await storage.clear();

      expect(await storage.get<int>('a'), isNull);
      expect(await storage.get<int>('b'), isNull);
    });

    test('set overwrites a previously stored value at the same key', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesCacheStorage(prefs);
      await storage.set('page_size', 20);

      await storage.set('page_size', 50);

      expect(await storage.get<int>('page_size'), 50);
    });
  });

  group('cacheStorageProvider', () {
    test('resolves to a CacheStorage backed by SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = await container.read(cacheStorageProvider.future);

      expect(storage, isA<CacheStorage>());
      expect(storage, isA<SharedPreferencesCacheStorage>());
    });
  });
}