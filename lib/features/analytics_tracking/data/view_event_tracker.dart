/// Part BI-04: records a view of a product, post or reel.
///
/// Contract (api_contract_BI02.md, section 8):
/// * call it when the DETAIL screen opens, never from a list;
/// * `event_id` is a client UUID (dedupe key); `anon_id` identifies an
///   anonymous visitor (16-128 chars of [A-Za-z0-9._:-]) and is ignored by
///   the server for a logged-in user, so it is always sent;
/// * reels send `watch_ms` and only count at >= 3000 ms: a shorter watch is
///   not sent at all;
/// * 403 (the owner viewing their own item) is ignored SILENTLY, and so is
///   every other failure: tracking must never break or slow a screen.
///
/// `occurred_at` is deliberately omitted: it may not be in the future, and a
/// device clock ahead of the server would turn a good event into a 400.
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';

enum ViewTargetType { product, post, reel }

enum ViewRecordResult { recorded, duplicate, ignored, skipped }

class ViewEventTracker {
  ViewEventTracker({
    required Dio dio,
    Future<SharedPreferences> Function()? preferences,
    Random? random,
  }) : _dio = dio,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _random = random ?? Random.secure();

  final Dio _dio;
  final Future<SharedPreferences> Function() _preferences;
  final Random _random;

  static const String path = '/api/v1/analytics/events/views/';
  static const int minReelWatchMs = 3000;
  static const String anonIdStorageKey = 'analytics_anon_id';

  String? _anonId;

  /// Records one view. Never throws.
  Future<ViewRecordResult> record({
    required ViewTargetType type,
    required int targetId,
    int? watchMs,
  }) async {
    if (targetId <= 0) {
      return ViewRecordResult.skipped;
    }
    if (type == ViewTargetType.reel &&
        (watchMs == null || watchMs < minReelWatchMs)) {
      return ViewRecordResult.skipped;
    }
    try {
      final String anonId = await _loadAnonId();
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: <String, Object?>{
          'event_id': newEventId(),
          'target_type': type.name,
          'target_id': targetId,
          if (type == ViewTargetType.reel) 'watch_ms': watchMs,
          'anon_id': anonId,
        },
      );
      if (response.statusCode == 201) {
        return ViewRecordResult.recorded;
      }
      final Object? body = response.data;
      final Object? status =
          body is Map<String, dynamic> ? body['status'] : null;
      return status == 'duplicate'
          ? ViewRecordResult.duplicate
          : ViewRecordResult.ignored;
    } on DioException {
      // 403 (owner), 404, 429 and network errors: nothing to show or retry.
      return ViewRecordResult.skipped;
    } on Object {
      return ViewRecordResult.skipped;
    }
  }

  /// Convenience for the reel player: call once when the playback position
  /// first reaches [minReelWatchMs].
  Future<ViewRecordResult> recordReelWatch({
    required int reelId,
    required int watchMs,
  }) {
    return record(
      type: ViewTargetType.reel,
      targetId: reelId,
      watchMs: watchMs,
    );
  }

  Future<String> _loadAnonId() async {
    final String? cached = _anonId;
    if (cached != null) {
      return cached;
    }
    final SharedPreferences prefs = await _preferences();
    final String? stored = prefs.getString(anonIdStorageKey);
    if (stored != null && isValidAnonId(stored)) {
      return _anonId = stored;
    }
    final String created = newAnonId();
    await prefs.setString(anonIdStorageKey, created);
    return _anonId = created;
  }

  static final RegExp _anonPattern = RegExp(r'^[A-Za-z0-9._:-]{16,128}$');

  static bool isValidAnonId(String value) => _anonPattern.hasMatch(value);

  /// 32 random hex characters.
  String newAnonId() =>
      List<String>.generate(
        16,
        (int _) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  /// UUID version 4.
  String newEventId() {
    final List<int> b = List<int>.generate(16, (int _) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int from, int to) =>
        <String>[
          for (int i = from; i < to; i++)
            b[i].toRadixString(16).padLeft(2, '0'),
        ].join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

final viewEventTrackerProvider = Provider<ViewEventTracker>(
  (ref) => ViewEventTracker(dio: ref.watch(dioClientProvider)),
);
