import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Part P-112: encoding guard.
///
/// A previous script wrote UTF-8 Arabic through a legacy code page, so every
/// Arabic letter turned into two or three Latin look-alike characters. The
/// app then showed garbage while the old tests still passed (their expected
/// strings were garbled in the same way). This test fails if that ever
/// happens again, in the ARB files OR in any Dart source.
///
/// This file is deliberately ASCII only: every non-ASCII character below is
/// written as a \uXXXX escape.
void main() {
  final RegExp arabicLetter = RegExp('[\u0621-\u064A]');

  // A lead character of a broken sequence (U+00C3, U+00D8, U+00D9, U+00DA)
  // followed by a continuation or a Windows-1252 symbol.
  final RegExp garbled = RegExp(
    '[\u00c3\u00d8\u00d9\u00da]'
    '[\u0080-\u00bf\u0152\u0153\u0160\u0161\u0178\u017d\u017e\u0192\u02c6'
    '\u02dc\u2013\u2014\u2018-\u201a\u201c-\u201e\u2020-\u2022\u2026\u2030'
    '\u2039\u203a\u20ac\u2122]',
  );

  test('every Arabic ARB value contains real Arabic letters', () {
    final Map<String, dynamic> arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final List<String> broken = <String>[];
    for (final MapEntry<String, dynamic> entry in arb.entries) {
      if (entry.key.startsWith('@')) {
        continue;
      }
      final Object? value = entry.value;
      if (value is! String) {
        continue;
      }
      if (!arabicLetter.hasMatch(value) || garbled.hasMatch(value)) {
        broken.add(entry.key);
      }
    }
    expect(broken, isEmpty, reason: 'garbled or non-Arabic values: $broken');
  });

  test('no garbled text anywhere in lib/ or test/ sources', () {
    final List<String> offenders = <String>[];
    for (final String root in <String>['lib', 'test']) {
      for (final FileSystemEntity entity in Directory(root).listSync(
        recursive: true,
      )) {
        if (entity is! File) {
          continue;
        }
        final String path = entity.path;
        if (!path.endsWith('.dart') && !path.endsWith('.arb')) {
          continue;
        }
        final String text = utf8.decode(
          entity.readAsBytesSync(),
          allowMalformed: true,
        );
        if (garbled.hasMatch(text)) {
          offenders.add(path);
        }
      }
    }
    expect(offenders, isEmpty, reason: 'files with garbled text: $offenders');
  });
}
