import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_provider.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_review_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 7B): the Staff review screen and the reject dialog use the
/// design tokens (Light and Dark), Reject is the destructive action in the
/// danger colour, and the layout mirrors in Arabic (RTL). The behaviour tests
/// (approve, reject, errors, already handled) stay in the P-040 file, which is
/// unchanged.
///
/// The moderation strings are localized (STEP 8A). The English tests use
/// English finders; the Arabic tests read their expected text from the
/// generated Arabic localizations (this file stays ASCII).

class _FixedQueue extends ModerationQueueNotifier {
  _FixedQueue(this._items);

  final List<QueueItem> _items;

  @override
  Future<List<QueueItem>> build() async => _items;
}

final QueueItem _target = QueueItem(
  id: 7,
  contentType: 'post',
  status: QueueItemStatus.pending,
  priority: QueuePriority.fastPath,
  createdAt: DateTime.utc(2026, 10, 1, 10),
  ageDuration: const Duration(minutes: 40),
  previewText: 'Great deal on shoes',
  submitterBusinessName: 'Cavallo Shoes',
);

Future<void> _pump(
  WidgetTester tester, {
  required bool dark,
  Locale locale = const Locale('en'),
  Size size = const Size(800, 2000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        moderationQueueProvider.overrideWith(
          () => _FixedQueue(<QueueItem>[_target]),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: ModerationReviewScreen(item: _target),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _approve => find.byKey(const ValueKey('review-approve-button'));
Finder get _reject => find.byKey(const ValueKey('review-reject-button'));
Finder get _confirm => find.byKey(const ValueKey('reject-confirm-button'));

Future<void> _openRejectDialog(WidgetTester tester) async {
  await tester.tap(_reject);
  await tester.pumpAndSettle();
}

void main() {
  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';
    final AppColors c = dark ? AppColors.dark : AppColors.light;

    testWidgets('Reject is the danger action, Approve stays primary - $mode', (
      tester,
    ) async {
      await _pump(tester, dark: dark);

      final OutlinedButton reject = tester.widget<OutlinedButton>(_reject);
      expect(
        reject.style?.foregroundColor?.resolve(<WidgetState>{}),
        c.dangerText,
      );
      expect(reject.style?.side?.resolve(<WidgetState>{})?.color, c.dangerText);

      expect(
        tester.widget<AppButton>(_approve).variant,
        AppButtonVariant.filled,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the details card is a hairline surface from the tokens - '
        '$mode', (tester) async {
      await _pump(tester, dark: dark);

      final Material card = tester.widget<Material>(
        find.byKey(const ValueKey('review-details-card')),
      );
      expect(card.color, c.surface);
      expect((card.shape! as RoundedRectangleBorder).side.color, c.outline);
      expect(find.text('Great deal on shoes'), findsOneWidget);
      expect(find.text('Cavallo Shoes'), findsOneWidget);
    });

    testWidgets('reject dialog: danger confirm, disabled until a reason, '
        'danger-coloured message - $mode', (tester) async {
      await _pump(tester, dark: dark);
      await _openRejectDialog(tester);

      // Nothing typed: the confirm button is the danger variant and disabled.
      expect(
        tester.widget<AppButton>(_confirm).variant,
        AppButtonVariant.danger,
      );
      expect(tester.widget<AppButton>(_confirm).onPressed, isNull);

      // Blank input: the required message shows in the danger text colour.
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pumpAndSettle();
      final Finder requiredMessage = find.byKey(
        const ValueKey('reject-reason-required'),
      );
      expect(requiredMessage, findsOneWidget);
      expect(tester.widget<Text>(requiredMessage).style?.color, c.dangerText);
      expect(tester.widget<AppButton>(_confirm).onPressed, isNull);

      // A real reason enables the button, painted with the danger tokens.
      await tester.enterText(find.byType(TextFormField), 'Blurry photo');
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(_confirm).onPressed, isNotNull);
      final FilledButton filled = tester.widget<FilledButton>(
        find.descendant(of: _confirm, matching: find.byType(FilledButton)),
      );
      expect(filled.style?.backgroundColor?.resolve(<WidgetState>{}), c.danger);
      expect(
        filled.style?.foregroundColor?.resolve(<WidgetState>{}),
        c.onDanger,
      );

      // The hint tells the staff member the business will read the reason.
      expect(
        tester
            .widget<Text>(find.text('The business will see this reason.'))
            .style
            ?.color,
        c.textSecondary,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('English (LTR): Reject is before Approve, labels before values', (
    tester,
  ) async {
    await _pump(tester, dark: false);

    expect(
      tester.getCenter(_reject).dx,
      lessThan(tester.getCenter(_approve).dx),
    );
    expect(
      tester.getCenter(find.text('Type')).dx,
      lessThan(tester.getCenter(find.text('Post')).dx),
    );
  });

  testWidgets('Arabic (RTL): the bottom bar and the detail rows mirror', (
    tester,
  ) async {
    await _pump(tester, dark: true, locale: const Locale('ar'));

    expect(
      tester.getCenter(_reject).dx,
      greaterThan(tester.getCenter(_approve).dx),
    );
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      tester.getCenter(find.text(ar.moderationDetailType)).dx,
      greaterThan(tester.getCenter(find.text(ar.moderationContentTypePost)).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark + Arabic + narrow screen: screen and dialog never '
      'overflow', (tester) async {
    await _pump(
      tester,
      dark: true,
      locale: const Locale('ar'),
      size: const Size(320, 700),
    );
    await _openRejectDialog(tester);
    await tester.enterText(
      find.byType(TextFormField),
      'The product photo is blurry, the logo is cropped and the price tag is '
      'not readable. Please upload a clear photo of the whole product.',
    );
    await tester.pumpAndSettle();

    expect(tester.widget<AppButton>(_confirm).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
