import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Part P-005 scope: the one place in the app allowed to persist auth
/// tokens on-device.
///
/// Backed by [FlutterSecureStorage] (Keychain on iOS/macOS, Android
/// KeyStore-backed AES-GCM encryption on Android) — never plain
/// `SharedPreferences`, per architecture Section 14/15. [CacheStorage]
/// (cache_storage.dart, same directory) is explicitly forbidden from ever
/// touching a token; this class is the only sanctioned path for reading or
/// writing one.
///
/// Deliberately does not implement any refresh-timing/expiry logic or
/// theft-detection business rules — that's Part P-022. This class only
/// knows how to save, read, and clear the two token strings.
///
/// ### Android configuration note (real resolved-version finding)
/// The part spec calls for `AndroidOptions(encryptedSharedPreferences:
/// true)`. The version actually pinned in this project's pubspec.yaml
/// (`flutter_secure_storage: ^10.3.1`, resolved to `10.3.2` per P-001's
/// real-machine validation) has **deprecated and made a no-op** that exact
/// parameter: "EncryptedSharedPreferences is deprecated and will be
/// removed in v11 ... Remove this parameter - it will be ignored." Passing
/// it anyway would compile fine but throw a `deprecated_member_use`
/// warning during `flutter analyze`, breaking this part's "clean analyze"
/// validation bar for zero actual effect. As of 10.x, the plugin already
/// always encrypts Android storage via KeyStore-backed AES/GCM data
/// encryption + RSA-OAEP key wrapping by default (see
/// `AndroidOptions.defaultOptions`) — which is a stronger, currently
/// non-deprecated equivalent of what `encryptedSharedPreferences: true`
/// used to request on older plugin versions. So the parameter is
/// deliberately omitted here; `AndroidOptions.defaultOptions` is used
/// instead, and this still satisfies the architecture rule (Keystore, not
/// plaintext SharedPreferences).
///
/// ### Wiring note for Part P-020
/// [getAccessToken] already matches the `AuthTokenGetter` typedef declared
/// in `lib/core/network/dio_client.dart` (`Future<String?> Function()`)
/// exactly — no adapter/wrapper method needed. P-020's composition root is
/// expected to do:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     authTokenGetterProvider.overrideWithValue(
///       ref.read(secureTokenStorageProvider).getAccessToken,
///     ),
///   ],
///   child: const SocialCommerceApp(),
/// )
/// ```
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions.defaultOptions,
          );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  /// Persists both tokens after a successful login/register/refresh.
  ///
  /// Always writes both together — this class has no concept of a partial
  /// token pair, since the backend issues (and rotates, per Section 14)
  /// access and refresh tokens as a matched set.
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  /// Matches the `AuthTokenGetter` typedef (`Future<String?> Function()`)
  /// from `lib/core/network/dio_client.dart` exactly — see the P-020
  /// wiring note on this class.
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Wipes both tokens — e.g. on logout, or on refresh-token-reuse-detected
  /// (the theft signal Section 14 calls out). No-op if nothing was ever
  /// saved.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

/// The shared [SecureTokenStorage] instance for the whole app.
///
/// A `Provider` (not a singleton/global) so it's overridable in tests —
/// same pattern P-004 established for `dioClientProvider`.
final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});