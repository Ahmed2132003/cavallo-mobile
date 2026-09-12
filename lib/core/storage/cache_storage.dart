import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Part P-005 scope: a minimal, generic cache abstraction for non-sensitive
/// local data only — e.g. a cached category tree, a last-seen feed cursor.
///
/// **This class, and every implementation of it, must never store an auth
/// token, refresh token, or any other credential.** Tokens are the
/// exclusive responsibility of [SecureTokenStorage]
/// (secure_token_storage.dart, same directory), per architecture Section
/// 14/15 — `shared_preferences` is plaintext on-device storage and is
/// explicitly disallowed for tokens.
///
/// There's no runtime check enforcing that here — a generic cache keyed by
/// arbitrary strings has no way to know "this value is a token" — so the
/// guard is architectural discipline instead: this file does not import
/// `flutter_secure_storage`, and `secure_token_storage.dart` does not
/// import `shared_preferences`. Anyone tempted to add a
/// `cacheStorage.set('access_token', ...)` call anywhere in the app should
/// read this comment and use [SecureTokenStorage] instead.
abstract class CacheStorage {
  /// Reads the JSON-decoded value stored at [key], or `null` if [key] was
  /// never set (or was removed/cleared).
  ///
  /// [T] must be a type `dart:convert`'s `jsonDecode` can hand back
  /// directly with no further conversion: `Map<String, dynamic>`,
  /// `List<dynamic>`, `String`, `num`/`int`/`double`, or `bool`. This class
  /// does not do model (de)serialization — callers own converting to/from
  /// their own domain types around these calls.
  Future<T?> get<T>(String key);

  /// JSON-encodes [value] and stores it under [key], overwriting whatever
  /// was there before.
  Future<void> set<T>(String key, T value);

  /// Removes the value at [key]. No-op if [key] doesn't exist.
  Future<void> remove(String key);

  /// Wipes every key this storage manages.
  Future<void> clear();
}

/// `shared_preferences`-backed [CacheStorage].
///
/// Intentionally not encrypted — that's exactly why tokens can never go
/// through this path (see the class-level warning on [CacheStorage]).
/// Fine for the non-sensitive MVP data this part scopes it to.
class SharedPreferencesCacheStorage implements CacheStorage {
  SharedPreferencesCacheStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<T?> get<T>(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as T;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }
}

/// The shared [CacheStorage] instance for the whole app.
///
/// A `FutureProvider` rather than a plain `Provider` — building a
/// [SharedPreferencesCacheStorage] needs `SharedPreferences.getInstance()`,
/// which is itself async (it reads from disk). Callers use
/// `ref.watch(cacheStorageProvider.future)` from a repository/notifier, or
/// `ref.watch(cacheStorageProvider)` from a widget via its `AsyncValue`.
final cacheStorageProvider = FutureProvider<CacheStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesCacheStorage(prefs);
});