/// Part BI-04: strict JSON readers shared by the analytics DTOs.
///
/// Every failure is a [FormatException] with the JSON path, which the
/// repository turns into an `UnknownFailure`. Nothing is defaulted to 0:
///
/// * `req*` readers: the key must be present with the right type.
/// * `opt*` readers: a missing key or an explicit null is `null` ("not
///   available"); a present value of the wrong type still throws.
///
/// Money is a decimal STRING (never a double).
library;

abstract final class DtoParsing {
  static Map<String, dynamic> asMap(Object? value, String path) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('$path must be an object, got ${value.runtimeType}.');
  }

  static List<dynamic> asList(Object? value, String path) {
    if (value is List) return List<dynamic>.from(value);
    throw FormatException('$path must be a list, got ${value.runtimeType}.');
  }

  static Map<String, dynamic> reqMap(
    Map<String, dynamic> json,
    String key,
    String path,
  ) => asMap(json[key], '$path.$key');

  /// A required list of objects.
  static List<Map<String, dynamic>> objects(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final List<dynamic> raw = asList(json[key], '$path.$key');
    return <Map<String, dynamic>>[
      for (int i = 0; i < raw.length; i++) asMap(raw[i], '$path.$key[$i]'),
    ];
  }

  static List<String> strings(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final List<dynamic> raw = asList(json[key], '$path.$key');
    return <String>[
      for (int i = 0; i < raw.length; i++)
        if (raw[i] is String)
          raw[i] as String
        else
          throw FormatException('$path.$key[$i] must be a string.'),
    ];
  }

  static int reqInt(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value is int) return value;
    throw FormatException(
      '$path.$key must be an integer, got ${value.runtimeType}.',
    );
  }

  static int? optInt(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    throw FormatException(
      '$path.$key must be an integer or null, got ${value.runtimeType}.',
    );
  }

  static num? optNum(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value == null) return null;
    if (value is num) return value;
    throw FormatException(
      '$path.$key must be a number or null, got ${value.runtimeType}.',
    );
  }

  static double? optDouble(
    Map<String, dynamic> json,
    String key,
    String path,
  ) => optNum(json, key, path)?.toDouble();

  static bool reqBool(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value is bool) return value;
    throw FormatException(
      '$path.$key must be a boolean, got ${value.runtimeType}.',
    );
  }

  static String reqString(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value is String) return value;
    throw FormatException(
      '$path.$key must be a string, got ${value.runtimeType}.',
    );
  }

  static String? optString(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException(
      '$path.$key must be a string or null, got ${value.runtimeType}.',
    );
  }

  static final RegExp _money = RegExp(r'^-?\d+(\.\d+)?$');

  /// A money amount: a decimal string ("1234.50"); a JSON number is accepted
  /// too and rendered with 2 decimals.
  static String reqMoney(Map<String, dynamic> json, String key, String path) {
    final Object? value = json[key];
    if (value is String && _money.hasMatch(value)) return value;
    if (value is num) return value.toStringAsFixed(2);
    throw FormatException('$path.$key must be a decimal amount, got $value.');
  }

  static String? optMoney(Map<String, dynamic> json, String key, String path) {
    if (json[key] == null) return null;
    return reqMoney(json, key, path);
  }

  /// `{"EGP": "300.00"}` -> map; missing or null -> empty map.
  static Map<String, String> moneyMap(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final Object? raw = json[key];
    if (raw == null) return const <String, String>{};
    final Map<String, dynamic> map = asMap(raw, '$path.$key');
    return <String, String>{
      for (final MapEntry<String, dynamic> e in map.entries)
        e.key: reqMoney(map, e.key, '$path.$key'),
    };
  }

  /// `{"reach": "text"}` -> map of strings; missing or null -> empty map.
  static Map<String, String> stringMap(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final Object? raw = json[key];
    if (raw == null) return const <String, String>{};
    final Map<String, dynamic> map = asMap(raw, '$path.$key');
    return <String, String>{
      for (final MapEntry<String, dynamic> e in map.entries)
        if (e.value is String) e.key: e.value as String,
    };
  }

  static final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Strict `YYYY-MM-DD` -> UTC midnight. Rejects impossible dates.
  static DateTime reqDate(Map<String, dynamic> json, String key, String path) {
    final String raw = reqString(json, key, path);
    final RegExpMatch? match = _datePattern.firstMatch(raw);
    if (match == null) {
      throw FormatException('$path.$key must be YYYY-MM-DD, got "$raw".');
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('$path.$key is not a real date: "$raw".');
    }
    return parsed;
  }

  /// ISO-8601 timestamp (trailing Z) -> UTC; missing or null -> null.
  static DateTime? optDateTime(
    Map<String, dynamic> json,
    String key,
    String path,
  ) {
    final String? raw = optString(json, key, path);
    if (raw == null) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('$path.$key is not an ISO timestamp: "$raw".');
    }
    return parsed.toUtc();
  }
}
