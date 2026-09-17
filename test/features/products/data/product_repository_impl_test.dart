import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/products/data/product_repository_impl.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';

/// Part P-033 scope. Exercises [ProductRepositoryImpl] against a mocked
/// Dio adapter shaped like the confirmed real `/api/v1/products/`
/// contract (P-032 + P-032B, confirmed via `PROJECT_PROGRESS.md` — not
/// guessed). Mirrors `business_profile_repository_impl_test.dart`'s
/// exact setup: a real `ErrorInterceptor` attached to a mocked adapter.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProductRepositoryImpl repository;
  List<dynamic>? capturedRequestData;

  const fullJson = {
    'id': 10,
    'business': 1,
    'category': 3,
    'name': 'Cotton T-Shirt',
    'description': 'Plain white cotton t-shirt',
    'price': '199.99',
    'currency': 'EGP',
    'image': 'https://cdn.example.com/products/10.png',
    'is_active': true,
    'variants': [
      {'id': 1, 'name': 'Size', 'value': 'Large'},
    ],
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-02T12:30:00Z',
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());

    // Test-only interceptor: captures every outgoing request body
    // *before* the mocked adapter consumes it, so tests below can
    // assert on the real FormData/Map that was actually sent — the
    // adapter's own `data:` matcher only supports exact-Map equality,
    // which can't inspect a FormData's fields/files.
    capturedRequestData = [];
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedRequestData!.add(options.data);
          handler.next(options);
        },
      ),
    );

    repository = ProductRepositoryImpl(dio: dio);
  });

  group('fetchOwnProducts', () {
    test('parses a paginated {results, next, previous} response', () async {
      adapter.onGet(
        '/api/v1/products/',
        (server) => server.reply(200, {
          'results': [fullJson],
          'next': null,
          'previous': null,
        }),
      );

      final page = await repository.fetchOwnProducts();

      expect(page.results, hasLength(1));
      expect(page.results.first.id, 10);
      expect(page.results.first.currency, Currency.egp);
      expect(page.next, isNull);
    });
  });

  group('createProduct', () {
    test('sends a plain JSON body when no image is given', () async {
      adapter.onPost(
        '/api/v1/products/',
        (server) => server.reply(201, fullJson),
        data: {
          'category': 3,
          'name': 'Cotton T-Shirt',
          'description': 'Plain white cotton t-shirt',
          'price': '199.99',
          'currency': 'EGP',
          'is_active': true,
        },
      );

      final product = await repository.createProduct(
        categoryId: 3,
        name: 'Cotton T-Shirt',
        description: 'Plain white cotton t-shirt',
        price: '199.99',
        currency: Currency.egp,
      );

      expect(product.id, 10);
      expect(product.currency, Currency.egp);
      // Reaching here without an "unmocked route" error already proves
      // the body was the exact plain Map above, not a FormData.
      expect(capturedRequestData!.single, isA<Map<String, dynamic>>());
    });

    test('sends a FormData with every field + image when a file is given', () async {
      final tempFile = await _writeTempPng();

      adapter.onPost(
        '/api/v1/products/',
        (server) => server.reply(201, fullJson),
        // No `data:` matcher here — FormData can't be matched by exact
        // Map equality. The captured-request-data interceptor above
        // does the real verification instead, below.
      );

      await repository.createProduct(
        categoryId: 3,
        name: 'Cotton T-Shirt',
        description: 'Plain white cotton t-shirt',
        price: '199.99',
        currency: Currency.egp,
        imageFile: tempFile,
      );

      final sent = capturedRequestData!.single;
      expect(sent, isA<FormData>());
      final formData = sent as FormData;
      final fieldMap = Map.fromEntries(formData.fields);
      expect(fieldMap['category'], '3');
      expect(fieldMap['name'], 'Cotton T-Shirt');
      expect(fieldMap['is_active'], 'true');
      expect(formData.files, hasLength(1));
      expect(formData.files.single.key, 'image');

      await tempFile.delete();
    });
  });

  group('updateProduct', () {
    test('PATCHes only the fields actually passed (plain JSON, no image)', () async {
      adapter.onPatch(
        '/api/v1/products/10/',
        (server) => server.reply(200, fullJson),
        data: {'name': 'Updated Name'},
      );

      final product = await repository.updateProduct(
        productId: 10,
        name: 'Updated Name',
      );

      expect(product.id, 10);
      // Reaching here proves the body contained *only* `name` —
      // category/description/price/currency/is_active were all
      // correctly left out.
    });

    test('a cross-business 403 surfaces as AuthFailure, not silently ignored', () async {
      adapter.onPatch(
        '/api/v1/products/10/',
        (server) => server.reply(403, {
          'error': {
            'code': 'PERMISSION_DENIED',
            'message': 'You do not own this product.',
          },
        }),
        data: {'name': 'Hijacked Name'},
      );

      try {
        await repository.updateProduct(productId: 10, name: 'Hijacked Name');
        fail('Expected a DioException to be thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthFailure>());
      }
    });
  });

  group('deleteProduct', () {
    test('DELETEs the product by id', () async {
      adapter.onDelete(
        '/api/v1/products/10/',
        (server) => server.reply(204, null),
      );

      await repository.deleteProduct(10);
      // No exception thrown — success.
    });
  });
}

/// Writes a tiny, real PNG file to a temp path so [MultipartFile.fromFile]
/// has a genuine file to read — mirrors how a real image_picker result
/// would be a real file on disk, not an in-memory fake.
Future<File> _writeTempPng() async {
  const pngBytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  ];
  final file = File(
    '${Directory.systemTemp.path}/p033_test_image_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(pngBytes);
  return file;
}