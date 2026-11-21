import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/presentation/order_status_chip.dart';

import '../orders_test_helpers.dart';

void main() {
  test('every lifecycle status has a distinct icon (not colour alone)', () {
    final icons = <IconData>{
      for (final s in OrderStatus.lifecycle)
        orderStatusTone(AppColors.light, s).icon,
    };
    expect(icons, hasLength(OrderStatus.lifecycle.length));
  });

  test('every status has a non-empty, different label in en and ar', () {
    final en = l10nFor('en');
    final ar = l10nFor('ar');
    for (final s in OrderStatus.values) {
      expect(orderStatusLabel(en, s), isNotEmpty);
      expect(orderStatusLabel(ar, s), isNotEmpty);
    }
    for (final s in OrderStatus.lifecycle) {
      expect(orderStatusLabel(en, s), isNot(orderStatusLabel(ar, s)));
    }
  });

  for (final dark in <bool>[false, true]) {
    testWidgets('chip uses the ${dark ? 'dark' : 'light'} tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        orderTestApp(
          const Scaffold(
            body: Center(child: OrderStatusChip(status: OrderStatus.delivered)),
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();

      final colors = dark ? AppColors.dark : AppColors.light;
      final tone = orderStatusTone(colors, OrderStatus.delivered);
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect((container.decoration! as BoxDecoration).color, tone.background);
      expect(
        find.text(orderStatusLabel(l10nFor('en'), OrderStatus.delivered)),
        findsOneWidget,
      );
    });
  }

  testWidgets('a status change cross-fades (both visible mid-way, one after)', (
    tester,
  ) async {
    Widget chip(OrderStatus s) =>
        orderTestApp(Scaffold(body: Center(child: OrderStatusChip(status: s))));

    await tester.pumpWidget(chip(OrderStatus.pending));
    await tester.pumpAndSettle();
    expect(byKeyName('orderStatusChip_pending'), findsOneWidget);

    await tester.pumpWidget(chip(OrderStatus.confirmed));
    await tester.pump(const Duration(milliseconds: 100));
    expect(byKeyName('orderStatusChip_pending'), findsOneWidget);
    expect(byKeyName('orderStatusChip_confirmed'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(byKeyName('orderStatusChip_pending'), findsNothing);
    expect(byKeyName('orderStatusChip_confirmed'), findsOneWidget);
  });
}
