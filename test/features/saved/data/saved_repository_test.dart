import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';

/// Part P-113 (STEP 3B): the one read the Saved screen makes,
/// `GET /api/v1/saves/me/`.

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return dio;
}

const String _page = '''
{
  "next": "http://localhost/api/v1/saves/me/?cursor=abc",
  "previous": null,
  "results": [
    {"id": 3, "content_type": "post", "object_id": 30,
     "preview": {"preview_text": "A post", "preview_image_url": null},
     "created_at": "2026-10-05T10:00:00Z"},
    {"id": 2, "content_type": "story", "object_id": 20,
     "preview": null, "created_at": "2026-10-05T09:00:00Z"},
    {"id": 1, "content_type": "product", "object_id": 10,
     "preview": null, "created_at": "2026-10-05T08:00:00Z"}
  ]
}
''';

void main() {
  test('first page: GET /api/v1/saves/me/ and rows are parsed', () async {
    final _Adapter adapter = _Adapter(_page);
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(adapter),
    );

    final PaginatedResponse<SavedItem> page = await repository.listSaved();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, SavedRepositoryImpl.listPath);
    expect(SavedRepositoryImpl.listPath, '/api/v1/saves/me/');

    // The unknown "story" row is dropped; the others keep the server order.
    expect(page.results.map((SavedItem i) => i.id), <int>[3, 1]);
    expect(page.results.first.contentType, SavedContentType.post);
    expect(page.results.first.previewText, 'A post');
    expect(page.results.last.isUnavailable, isTrue);
    expect(page.next, 'http://localhost/api/v1/saves/me/?cursor=abc');
    expect(page.previous, isNull);
  });

  test('next page: the cursor URL is passed to Dio verbatim', () async {
    final _Adapter adapter = _Adapter(_page);
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(adapter),
    );

    await repository.listSaved(
      cursor: 'http://localhost/api/v1/saves/me/?cursor=abc',
    );

    expect(
      adapter.requests.single.uri.toString(),
      'http://localhost/api/v1/saves/me/?cursor=abc',
    );
  });

  test('an error status surfaces as an exception, not as an empty list', () {
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(_Adapter('{}', statusCode: 500)),
    );

    expect(repository.listSaved(), throwsA(isA<DioException>()));
  });
}
