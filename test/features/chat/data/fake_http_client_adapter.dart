import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal, hand-rolled fake [HttpClientAdapter] for repository tests —
/// no mocking-package dependency, in the same "test-friendly
/// abstraction, zero extra dependency" spirit as `ChatSocket`/
/// `FakeChatSocket` in `lib/core/chat/chat_connection_manager.dart`
/// (P-073 STEP 2).
///
/// Queue up expected responses with [enqueue] (FIFO, one per request in
/// the order they'll be made). Every request made once the queue is
/// empty throws [StateError], so a test can never silently pass on an
/// unexpected extra request.
class FakeHttpClientAdapter implements HttpClientAdapter {
  final _queue = <_FakeResponse>[];

  /// Every [RequestOptions] this adapter has seen, in call order — for
  /// asserting on the requested method/path/query/body afterward.
  final requestedOptions = <RequestOptions>[];

  void enqueue({
    required int statusCode,
    Object? data,
    Map<String, List<String>> headers = const {},
  }) {
    _queue.add(
      _FakeResponse(statusCode: statusCode, data: data, headers: headers),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedOptions.add(options);

    if (_queue.isEmpty) {
      throw StateError(
        'FakeHttpClientAdapter: no response enqueued for '
        '${options.method} ${options.path}',
      );
    }
    final fake = _queue.removeAt(0);

    final bodyBytes = utf8.encode(
      fake.data == null ? '' : jsonEncode(fake.data),
    );

    return ResponseBody.fromBytes(
      bodyBytes,
      fake.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...fake.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeResponse {
  _FakeResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  final int statusCode;
  final Object? data;
  final Map<String, List<String>> headers;
}