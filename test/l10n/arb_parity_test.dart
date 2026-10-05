import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Part P-112: guards the two ARB files.
///
/// * every message key exists in BOTH files (and nothing extra in either),
/// * every plural message in Arabic defines all six CLDR categories,
/// * every placeholder declared in the template is used by the Arabic text,
/// * keys are semantic camelCase (no button1 / text2 style names).
///
/// `flutter test` runs from the project root, so the paths are relative.
const List<String> _arabicPluralCategories = <String>[
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
];

Map<String, dynamic> _readArb(String fileName) {
  final File file = File('lib/l10n/$fileName');
  expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((String k) => !k.startsWith('@')).toSet();

bool _isPlural(String message) =>
    RegExp(r',\s*plural\s*,').hasMatch(message);

bool _hasCategory(String message, String category) =>
    RegExp('[\\s,]$category\\{').hasMatch(message);

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() {
    en = _readArb('app_en.arb');
    ar = _readArb('app_ar.arb');
  });

  test('each file declares its own @@locale', () {
    expect(en['@@locale'], 'en');
    expect(ar['@@locale'], 'ar');
  });

  test('both files contain exactly the same message keys', () {
    final Set<String> enKeys = _messageKeys(en);
    final Set<String> arKeys = _messageKeys(ar);
    expect(
      enKeys.difference(arKeys),
      isEmpty,
      reason: 'keys in app_en.arb but missing in app_ar.arb',
    );
    expect(
      arKeys.difference(enKeys),
      isEmpty,
      reason: 'keys in app_ar.arb but missing in app_en.arb',
    );
  });

  test('no message is empty', () {
    for (final Map<String, dynamic> arb in <Map<String, dynamic>>[en, ar]) {
      for (final String key in _messageKeys(arb)) {
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: 'empty message: $key (${arb['@@locale']})',
        );
      }
    }
  });

  test('keys are semantic camelCase, not button1 / text2', () {
    final RegExp camel = RegExp(r'^[a-z][A-Za-z0-9]*$');
    final RegExp numbered =
        RegExp(r'^(text|button|label|string|msg|str)\d+$', caseSensitive: false);
    for (final String key in _messageKeys(en)) {
      expect(camel.hasMatch(key), isTrue, reason: 'not camelCase: $key');
      expect(numbered.hasMatch(key), isFalse, reason: 'not semantic: $key');
    }
  });

  test('every Arabic plural message defines zero/one/two/few/many/other', () {
    for (final String key in _messageKeys(ar)) {
      final String message = ar[key] as String;
      if (!_isPlural(message)) continue;
      for (final String category in _arabicPluralCategories) {
        expect(
          _hasCategory(message, category),
          isTrue,
          reason: 'app_ar.arb: "$key" is missing the "$category" form',
        );
      }
    }
  });

  test('every English plural message defines at least "other"', () {
    for (final String key in _messageKeys(en)) {
      final String message = en[key] as String;
      if (!_isPlural(message)) continue;
      expect(
        _hasCategory(message, 'other'),
        isTrue,
        reason: 'app_en.arb: "$key" is missing the "other" form',
      );
    }
  });

  test('a key that is plural in English is plural in Arabic (and back)', () {
    for (final String key in _messageKeys(en)) {
      expect(
        _isPlural(en[key] as String),
        _isPlural(ar[key] as String),
        reason: '"$key" is plural in only one of the two files',
      );
    }
  });

  test('placeholders declared in the template are used in both languages', () {
    for (final String key in _messageKeys(en)) {
      final Object? meta = en['@$key'];
      if (meta is! Map<String, dynamic>) continue;
      final Object? placeholders = meta['placeholders'];
      if (placeholders is! Map<String, dynamic>) continue;
      for (final String name in placeholders.keys) {
        expect(
          (en[key] as String).contains('{$name'),
          isTrue,
          reason: 'app_en.arb: "$key" does not use {$name}',
        );
        expect(
          (ar[key] as String).contains('{$name'),
          isTrue,
          reason: 'app_ar.arb: "$key" does not use {$name}',
        );
      }
    }
  });
}