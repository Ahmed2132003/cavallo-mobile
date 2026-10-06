import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/l10n/rtl_helpers.dart';

/// Part P-112 STEP 6: right-to-left helpers.
Widget _host(TextDirection direction, Widget child) =>
    Directionality(textDirection: direction, child: child);

void main() {
  testWidgets('isRtl follows the Directionality above it', (tester) async {
    late bool rtl;
    late bool ltr;
    await tester.pumpWidget(
      _host(
        TextDirection.rtl,
        Builder(
          builder: (BuildContext context) {
            rtl = isRtl(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        TextDirection.ltr,
        Builder(
          builder: (BuildContext context) {
            ltr = isRtl(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(rtl, isTrue);
    expect(ltr, isFalse);
  });

  group('DirectionalIcon', () {
    testWidgets('an icon with no built-in mirroring is flipped only in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(TextDirection.ltr, const DirectionalIcon(Icons.play_arrow)),
      );
      expect(
        find.descendant(
          of: find.byType(DirectionalIcon),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await tester.pumpWidget(
        _host(TextDirection.rtl, const DirectionalIcon(Icons.play_arrow)),
      );
      expect(
        find.descendant(
          of: find.byType(DirectionalIcon),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an icon that mirrors itself is not flipped twice', (
      tester,
    ) async {
      expect(Icons.arrow_back.matchTextDirection, isTrue);
      await tester.pumpWidget(
        _host(TextDirection.rtl, const DirectionalIcon(Icons.arrow_back)),
      );
      // Exactly one flip: the one Icon itself applies.
      expect(
        find.descendant(
          of: find.byType(DirectionalIcon),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    });
  });
}
