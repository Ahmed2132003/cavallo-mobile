import 'package:dio/dio.dart';

/// Part P-112: attaches `Accept-Language: <ar|en>` to every outgoing request,
/// so the backend (LocaleMiddleware, category names, validation texts) answers
/// in the language the user is actually reading.
///
/// Takes the language as an injected function (see
/// `activeLanguageCodeGetterProvider` in `core/l10n/locale_provider.dart`)
/// instead of a Ref, mirroring [AuthInterceptor]. A header the caller already
/// set explicitly is left alone. A failing getter never blocks a request: the
/// header is simply omitted and the backend falls back to its own default.
class LocaleInterceptor extends Interceptor {
  LocaleInterceptor({required String Function() getLanguageCode})
    : _getLanguageCode = getLanguageCode;

  static const String headerName = 'Accept-Language';

  final String Function() _getLanguageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.headers.containsKey(headerName)) {
      try {
        final String code = _getLanguageCode();
        if (code.isNotEmpty) {
          options.headers[headerName] = code;
        }
      } catch (_) {
        // Never fail a request because of a language lookup.
      }
    }
    handler.next(options);
  }
}
