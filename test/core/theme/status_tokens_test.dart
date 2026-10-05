import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final Map<String, AppColors> themes = <String, AppColors>{
    'light': AppColors.light,
    'dark': AppColors.dark,
  };

  group('P-111 STEP 3: status tokens', () {
    for (final MapEntry<String, AppColors> entry in themes.entries) {
      final AppColors c = entry.value;

      test(
        '${entry.key}: success/warning/danger text is >= 4.5:1 on its subtle tint',
        () {
          expect(
            _contrast(c.successText, c.successSubtle),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(c.warningText, c.warningSubtle),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(c.dangerText, c.dangerSubtle),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      test(
        '${entry.key}: processing chip (textSecondary on surfaceVariant) is >= 4.5:1',
        () {
          expect(
            _contrast(c.textSecondary, c.surfaceVariant),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      test('${entry.key}: like icon (danger on surface) is >= 3:1', () {
        expect(_contrast(c.danger, c.surface), greaterThanOrEqualTo(3.0));
      });
    }

    test('copyWith, equality and lerp cover the new tokens', () {
      const Color probe = Color(0xFF000001);
      expect(AppColors.light.copyWith(), AppColors.light);
      expect(
        AppColors.light.copyWith(successText: probe) == AppColors.light,
        isFalse,
      );
      expect(
        AppColors.light.copyWith(warningText: probe) == AppColors.light,
        isFalse,
      );
      expect(
        AppColors.light.copyWith(dangerText: probe) == AppColors.light,
        isFalse,
      );
      final AppColors end = AppColors.light.lerp(AppColors.dark, 1);
      expect(end.successText, AppColors.dark.successText);
      expect(end.warningText, AppColors.dark.warningText);
      expect(end.dangerText, AppColors.dark.dangerText);
    });
  });

  group('P-111 STEP 3: hardcoded-colour guard', () {
    test('no palette colours or hex literals outside core/theme', () {
      // Allowed on purpose: black/white/white24/white54/transparent (story
      // viewer forced dark theme, play-overlay scrim, transparent).
      final RegExp palette = RegExp(
        r'(?<![A-Za-z0-9_])Colors\.(?!(?:black|white|white24|white54|transparent)\b)\w+',
      );
      final RegExp hex = RegExp(r'Color\(\s*0x');
      final List<String> hits = <String>[];

      for (final FileSystemEntity f in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) {
          continue;
        }
        final String p = f.path.replaceAll('\\', '/');
        if (p.contains('/core/theme/')) {
          continue;
        }
        final List<String> lines = const LineSplitter().convert(
          utf8.decode(f.readAsBytesSync(), allowMalformed: true),
        );
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trimLeft();
          if (line.startsWith('//')) {
            continue;
          }
          if (palette.hasMatch(line) || hex.hasMatch(line)) {
            hits.add('$p:${i + 1}: ${line.trim()}');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
