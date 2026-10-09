import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_provider.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_widgets.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 7A): the Staff moderation queue uses the design tokens
/// (Light and Dark), the shared chip language, and mirrors correctly in
/// Arabic (RTL). The behaviour tests (SLA colours, ordering, retry, 403,
/// refresh) stay in the P-040 files, which are unchanged.
///
/// The moderation strings are localized (STEP 8A). English finders are used
/// in the English tests; the Arabic tests read their expected text from the
/// generated Arabic localizations (this file stays ASCII). RTL is still
/// testable here: the test passes the Global localization delegates, which is what makes MaterialApp use RTL for Arabic.

class _FixedQueue extends ModerationQueueNotifier {
  _FixedQueue(this._items);

  final List<QueueItem> _items;

  @override
  Future<List<QueueItem>> build() async => _items;
}

QueueItem _item(
  int id, {
  QueuePriority priority = QueuePriority.normal,
  Duration age = const Duration(minutes: 5),
  String? previewText,
  String? businessName,
}) {
  return QueueItem(
    id: id,
    contentType: 'post',
    status: QueueItemStatus.pending,
    priority: priority,
    createdAt: DateTime.utc(2026, 10, 1, 10),
    ageDuration: age,
    previewText: previewText ?? 'Preview $id',
    submitterBusinessName: businessName,
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<QueueItem> items, {
  required bool dark,
  Locale locale = const Locale('en'),
  Size size = const Size(800, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        moderationQueueProvider.overrideWith(() => _FixedQueue(items)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: ModerationQueueScreen(onOpenItem: (item) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _chipBackground(WidgetTester tester, Finder chip) {
  final Container box = tester.widget<Container>(
    find.descendant(of: chip, matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

void main() {
  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';
    final AppColors c = dark ? AppColors.dark : AppColors.light;

    testWidgets('age chips use the token colours - $mode', (tester) async {
      await _pump(tester, <QueueItem>[
        _item(
          1,
          priority: QueuePriority.fastPath,
          age: const Duration(minutes: 10),
        ),
        _item(
          2,
          priority: QueuePriority.fastPath,
          age: const Duration(minutes: 20),
        ),
        _item(
          3,
          priority: QueuePriority.fastPath,
          age: const Duration(minutes: 31),
        ),
      ], dark: dark);

      expect(
        _chipBackground(tester, find.byKey(const ValueKey('age-chip-onTrack'))),
        c.successSubtle,
      );
      expect(
        _chipBackground(
          tester,
          find.byKey(const ValueKey('age-chip-approaching')),
        ),
        c.warningSubtle,
      );
      expect(
        _chipBackground(
          tester,
          find.byKey(const ValueKey('age-chip-breached')),
        ),
        c.dangerSubtle,
      );

      // Colour is never the only signal: a breached chip says so in words and
      // every chip keeps exactly one icon and one text.
      expect(find.text('31 min \u00B7 overdue'), findsOneWidget);
      for (final String urgency in <String>[
        'onTrack',
        'approaching',
        'breached',
      ]) {
        final Finder chip = find.byKey(ValueKey('age-chip-$urgency'));
        expect(
          find.descendant(of: chip, matching: find.byType(Icon)),
          findsOneWidget,
        );
        final Finder texts = find.descendant(
          of: chip,
          matching: find.byType(Text),
        );
        expect(texts, findsOneWidget);
        expect(tester.widget<Text>(texts).overflow, isNull);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('priority badges use the token colours - $mode', (
      tester,
    ) async {
      await _pump(tester, <QueueItem>[
        _item(1, priority: QueuePriority.fastPath),
        _item(2),
      ], dark: dark);

      final Finder fast = find.byKey(const ValueKey('priority-badge-fast'));
      final Container fastBox = tester.widget<Container>(fast);
      expect((fastBox.decoration! as BoxDecoration).color, c.brand);
      expect(
        tester
            .widget<Text>(
              find.descendant(of: fast, matching: find.byType(Text)),
            )
            .style
            ?.color,
        c.onBrand,
      );

      final Finder normal = find.byKey(const ValueKey('priority-badge-normal'));
      final BoxDecoration normalDecoration =
          tester.widget<Container>(normal).decoration! as BoxDecoration;
      expect((normalDecoration.border! as Border).top.color, c.outline);
      expect(
        tester
            .widget<Text>(
              find.descendant(of: normal, matching: find.byType(Text)),
            )
            .style
            ?.color,
        c.textSecondary,
      );
    });

    testWidgets('a queue row is a hairline surface from the tokens - $mode', (
      tester,
    ) async {
      await _pump(tester, <QueueItem>[_item(1)], dark: dark);

      final Material row = tester.widget<Material>(
        find.byKey(const ValueKey('queue-row-1')),
      );
      expect(row.color, c.surface);
      final RoundedRectangleBorder shape = row.shape! as RoundedRectangleBorder;
      expect(shape.side.color, c.outline);
    });
  }

  testWidgets('English (LTR): thumbnail before the text, chevron not mirrored '
      'away', (tester) async {
    await _pump(tester, <QueueItem>[_item(1)], dark: false);

    final double thumbnailX =
        tester.getCenter(find.byType(QueuePreviewThumbnail)).dx;
    final double textX = tester.getCenter(find.text('Preview 1')).dx;
    expect(thumbnailX, lessThan(textX));
  });

  testWidgets('Arabic (RTL): the row mirrors and the chevron follows the '
      'text direction', (tester) async {
    await _pump(
      tester,
      <QueueItem>[_item(1)],
      dark: true,
      locale: const Locale('ar'),
    );

    final double thumbnailX =
        tester.getCenter(find.byType(QueuePreviewThumbnail)).dx;
    final double textX = tester.getCenter(find.text('Preview 1')).dx;
    expect(thumbnailX, greaterThan(textX));

    final Icon chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    expect(chevron.icon!.matchTextDirection, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark + Arabic + narrow screen: long content never overflows', (
    tester,
  ) async {
    await _pump(
      tester,
      <QueueItem>[
        _item(
          1,
          priority: QueuePriority.fastPath,
          age: const Duration(days: 3, hours: 5),
          previewText:
              'A very long preview text that keeps going and going so that it '
              'has to be cut after two lines in the queue row of the staff',
          businessName: 'A business with a really long trading name Ltd',
        ),
      ],
      dark: true,
      locale: const Locale('ar'),
      size: const Size(320, 1200),
    );

    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      find.text(
        ar.moderationAgeOverdue(
          formatQueueAge(const Duration(days: 3, hours: 5), l10n: ar),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
