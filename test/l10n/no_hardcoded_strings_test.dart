import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Part P-115 (STEP 8): the repository-wide "no hardcoded user-facing
/// strings" guard.
///
/// It reads every `.dart` file under `lib/` (except the generated
/// `lib/l10n/`) and fails when a user-facing string literal is written
/// directly in the code instead of coming from `AppLocalizations`.
///
/// What counts as user-facing (the literal must be the direct argument):
///   * `Text('...')` / `Text("...")`  (this also covers SnackBar content,
///     dialog titles and AppBar titles, which are all `Text`)
///   * `hintText:`, `labelText:`, `helperText:`, `errorText:`, `tooltip:`,
///     `semanticLabel:`, `semanticsLabel:`
///   * `label:` and `message:` - only in presentation code and in
///     `lib/core/widgets/` (AppButton, AppTextField, EmptyStateWidget...);
///     data and network layers use `message:` for API failures, which is a
///     separate concern and is not scanned.
///
/// A literal is ignored when, after removing `$interpolations` and escapes,
/// it holds no letters (for example `'#${item.id}'` or `'${a}/${b}'`), and
/// when it sits on a comment line.
///
/// Rules for this file:
///   * Never weaken the scanner to make a test pass.
///   * An entry in [_allowlist] needs a written reason (a comment on the
///     entry). The whole file is exempt, so keep entries rare: debug-only
///     code is the only accepted reason.
///   * [_pendingMigration] is a TEMPORARY list used while the migration is
///     split over several steps. It must end up empty. A file that is on the
///     list but has no violations left fails the test, so the list can only
///     shrink.
///
/// `flutter test` runs from the project root, so the paths are relative.

/// Files that are allowed to keep literals, each with the reason.
const Map<String, String> _allowlist = <String, String>{
  // Developer-only widget gallery (Part P-006). Nothing in lib/ imports it:
  // only its own widget test builds it, so it is never shown to a user and
  // its labels (component names such as 'AppButton') are not product text.
  'lib/core/widgets/widget_gallery_demo.dart':
      'debug-only gallery, not reachable from the app',
};

/// Files that still contain literals and are being migrated. TEMPORARY.
/// Empty since P-115 STEP 9C: the last four chat files were localized.
/// Keep the set (the tests below use it); add to it only with a written reason.
const Set<String> _pendingMigration = <String>{};

class HardcodedLiteral {
  const HardcodedLiteral(this.file, this.line, this.kind, this.text);

  final String file;
  final int line;
  final String kind;
  final String text;

  @override
  String toString() => '$file:$line  $kind  "$text"';
}

final RegExp _literalPattern = RegExp(
  r'''(\bText\(|\bhintText:|\blabelText:|\bhelperText:|\berrorText:|\btooltip:|\bsemanticLabel:|\bsemanticsLabel:|\blabel:|\bmessage:)\s*(['"])((?:\\.|(?!\2)[^\\])*)\2''',
  dotAll: true,
);

final RegExp _letters = RegExp(r'[A-Za-z\u0600-\u06FF]');

String _visibleText(String raw) {
  return raw
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_]\w*'), '')
      .replaceAll(RegExp(r'\\u[0-9A-Fa-f]{4}'), '')
      .replaceAll(RegExp(r'\\.'), '');
}

bool _kindNeedsPresentationPath(String kind) =>
    kind == 'label:' || kind == 'message:';

bool _isPresentationPath(String path) =>
    path.contains('/presentation/') || path.startsWith('lib/core/widgets/');

/// Finds the user-facing literals in [source]. [path] uses forward slashes.
List<HardcodedLiteral> scanSource(String path, String source) {
  final List<HardcodedLiteral> found = <HardcodedLiteral>[];
  for (final RegExpMatch match in _literalPattern.allMatches(source)) {
    final String kind = match.group(1)!;
    if (_kindNeedsPresentationPath(kind) && !_isPresentationPath(path)) {
      continue;
    }
    final int lineStart = source.lastIndexOf('\n', match.start) + 1;
    final int lineEnd = source.indexOf('\n', match.start);
    final String lineText = source.substring(
      lineStart,
      lineEnd == -1 ? source.length : lineEnd,
    );
    if (lineText.trimLeft().startsWith('//')) {
      continue;
    }
    final String literal = match.group(3)!;
    if (!_letters.hasMatch(_visibleText(literal))) {
      continue;
    }
    final int line =
        '\n'.allMatches(source.substring(0, match.start)).length + 1;
    found.add(
      HardcodedLiteral(
        path,
        line,
        kind.endsWith('(') ? 'Text' : kind,
        literal.length > 60 ? '${literal.substring(0, 60)}...' : literal,
      ),
    );
  }
  return found;
}

Map<String, List<HardcodedLiteral>> _scanLib() {
  final Map<String, List<HardcodedLiteral>> byFile =
      <String, List<HardcodedLiteral>>{};
  final Directory lib = Directory('lib');
  expect(lib.existsSync(), isTrue, reason: 'run flutter test from the root');
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String path = entity.path.replaceAll('\\', '/');
    if (path.startsWith('lib/l10n/')) {
      continue;
    }
    final List<HardcodedLiteral> found = scanSource(
      path,
      entity.readAsStringSync(),
    );
    if (found.isNotEmpty) {
      byFile[path] = found;
    }
  }
  return byFile;
}

void main() {
  group('scanner self-test', () {
    test('finds literals in the user-facing positions', () {
      const String path = 'lib/features/x/presentation/x.dart';
      expect(scanSource(path, "Text('Hello')"), hasLength(1));
      expect(scanSource(path, 'Text("Hello")'), hasLength(1));
      expect(
        scanSource(path, "const Text(\n  'Hello world',\n)"),
        hasLength(1),
      );
      expect(scanSource(path, "TextField(hintText: 'Search')"), hasLength(1));
      expect(
        scanSource(path, "InputDecoration(labelText: 'Name')"),
        hasLength(1),
      );
      expect(scanSource(path, "IconButton(tooltip: 'Back')"), hasLength(1));
      expect(
        scanSource(path, "SnackBar(content: Text('Saved'))"),
        hasLength(1),
      );
      expect(scanSource(path, "AppButton(label: 'Save')"), hasLength(1));
      expect(
        scanSource(path, "EmptyStateWidget(message: 'Nothing')"),
        hasLength(1),
      );
      expect(
        scanSource(path, "Text('Total: \${t.count} items')"),
        hasLength(1),
      );
    });

    test('ignores localized text, numbers, comments and other layers', () {
      const String path = 'lib/features/x/presentation/x.dart';
      expect(scanSource(path, 'Text(context.l10n.save)'), isEmpty);
      expect(scanSource(path, "Text('#\${item.id}')"), isEmpty);
      expect(scanSource(path, "Text('\${a}/\${b}')"), isEmpty);
      expect(scanSource(path, "Text('\\u2014')"), isEmpty);
      expect(scanSource(path, "  // Text('Hello')"), isEmpty);
      expect(scanSource(path, "  /// Text('Hello')"), isEmpty);
      expect(scanSource(path, "SelectableText('Hello')"), isEmpty);
      expect(
        scanSource('lib/features/x/data/x.dart', "Failure(message: 'Oops')"),
        isEmpty,
      );
    });
  });

  group('repository scan', () {
    late Map<String, List<HardcodedLiteral>> violations;

    setUpAll(() {
      violations = _scanLib();
    });

    test('no user-facing hardcoded string outside the allowlist', () {
      final List<HardcodedLiteral> unexpected = <HardcodedLiteral>[];
      violations.forEach((String file, List<HardcodedLiteral> items) {
        if (_allowlist.containsKey(file) || _pendingMigration.contains(file)) {
          return;
        }
        unexpected.addAll(items);
      });
      expect(
        unexpected,
        isEmpty,
        reason:
            'Move these into lib/l10n/app_en.arb + app_ar.arb and read them '
            'through context.l10n:\n${unexpected.join('\n')}',
      );
    });

    test('every allowlist entry has a reason and is still needed', () {
      _allowlist.forEach((String file, String reason) {
        expect(reason.trim(), isNotEmpty, reason: '$file has no reason');
        expect(
          violations.containsKey(file),
          isTrue,
          reason: '$file is on the allowlist but has no literals: remove it',
        );
      });
    });

    test('every pending-migration file still has literals', () {
      for (final String file in _pendingMigration) {
        expect(
          violations.containsKey(file),
          isTrue,
          reason: '$file is clean now: remove it from _pendingMigration',
        );
      }
    });
  });
}
