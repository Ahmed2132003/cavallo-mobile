import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/orders/domain/order.dart';
import 'package:social_commerce_app/features/orders/domain/order_status.dart';
import 'package:social_commerce_app/features/orders/presentation/order_action_sheets.dart';

import '../orders_test_helpers.dart';

Future<void> _open(
  WidgetTester tester,
  FakeOrdersRepository repo,
  Order order, {
  required bool statusSheet,
}) async {
  await pumpOrdersApp(
    tester,
    Builder(
      builder:
          (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey<String>('openSheet'),
                onPressed:
                    () =>
                        statusSheet
                            ? showChangeStatusSheet(context, order: order)
                            : showAddNoteSheet(context, order: order),
                child: const SizedBox(width: 40, height: 20),
              ),
            ),
          ),
    ),
    repository: repo,
  );
  await tester.tap(byKeyName('openSheet'));
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor('en');

  group('change status sheet', () {
    testWidgets(
      'offers only the server-allowed statuses; Save needs a choice',
      (tester) async {
        final repo = FakeOrdersRepository();
        await _open(tester, repo, testOrder(), statusSheet: true);

        expect(byKeyName('statusOption_confirmed'), findsOneWidget);
        expect(byKeyName('statusOption_cancelled'), findsOneWidget);
        expect(byKeyName('statusOption_delivered'), findsNothing);
        expect(
          tester.widget<FilledButton>(byKeyName('statusSaveButton')).onPressed,
          isNull,
        );

        await tester.tap(byKeyName('statusOption_confirmed'));
        await tester.pump();
        expect(
          tester.widget<FilledButton>(byKeyName('statusSaveButton')).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('saves status + note, closes the sheet, shows the snackbar', (
      tester,
    ) async {
      final repo = FakeOrdersRepository();
      await _open(tester, repo, testOrder(), statusSheet: true);

      await tester.tap(byKeyName('statusOption_confirmed'));
      await tester.enterText(byKeyName('statusNoteField'), 'Ships Sunday');
      await tester.tap(byKeyName('statusSaveButton'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, hasLength(1));
      expect(repo.statusCalls.single.orderId, 5);
      expect(repo.statusCalls.single.status, OrderStatus.confirmed);
      expect(repo.statusCalls.single.note, 'Ships Sunday');
      expect(byKeyName('statusSaveButton'), findsNothing);
      expect(find.text(en.ordersStatusChanged), findsOneWidget);
    });

    testWidgets('a failure keeps the sheet open and shows the reason', (
      tester,
    ) async {
      final repo =
          FakeOrdersRepository()
            ..statusError = const ServerFailure(message: 'boom');
      await _open(tester, repo, testOrder(), statusSheet: true);

      await tester.tap(byKeyName('statusOption_cancelled'));
      await tester.pump();
      await tester.tap(byKeyName('statusSaveButton'));
      await tester.pumpAndSettle();

      expect(byKeyName('statusSaveButton'), findsOneWidget);
      expect(find.text(en.ordersErrorGeneric), findsOneWidget);
      expect(find.text(en.ordersStatusChanged), findsNothing);
    });

    testWidgets('no legal transition shows the explanation', (tester) async {
      final repo = FakeOrdersRepository();
      await _open(
        tester,
        repo,
        testOrder(status: OrderStatus.delivered, next: const []),
        statusSheet: true,
      );

      expect(find.text(en.ordersStatusNoTransitions), findsOneWidget);
      expect(byKeyName('statusNoteField'), findsNothing);
    });
  });

  group('add note sheet', () {
    testWidgets('internal by default; an empty note is rejected locally', (
      tester,
    ) async {
      final repo = FakeOrdersRepository();
      await _open(tester, repo, testOrder(), statusSheet: false);

      expect(
        tester.widget<SwitchListTile>(byKeyName('noteInternalSwitch')).value,
        isTrue,
      );

      await tester.tap(byKeyName('noteSaveButton'));
      await tester.pump();

      expect(find.text(en.ordersNoteRequired), findsOneWidget);
      expect(repo.noteCalls, isEmpty);
    });

    testWidgets('saves an internal note by default', (tester) async {
      final repo = FakeOrdersRepository();
      await _open(tester, repo, testOrder(), statusSheet: false);

      await tester.enterText(byKeyName('noteField'), 'Call tomorrow');
      await tester.tap(byKeyName('noteSaveButton'));
      await tester.pumpAndSettle();

      expect(repo.noteCalls.single.note, 'Call tomorrow');
      expect(repo.noteCalls.single.isInternal, isTrue);
      expect(find.text(en.ordersNoteAdded), findsOneWidget);
      expect(byKeyName('noteSaveButton'), findsNothing);
    });

    testWidgets('the merchant must opt in to a customer-visible note', (
      tester,
    ) async {
      final repo = FakeOrdersRepository();
      await _open(tester, repo, testOrder(), statusSheet: false);

      await tester.enterText(byKeyName('noteField'), 'Ready for pickup');
      await tester.tap(byKeyName('noteInternalSwitch'));
      await tester.pump();
      await tester.tap(byKeyName('noteSaveButton'));
      await tester.pumpAndSettle();

      expect(repo.noteCalls.single.isInternal, isFalse);
    });

    testWidgets('a failure keeps the sheet and shows the reason', (
      tester,
    ) async {
      final repo =
          FakeOrdersRepository()
            ..noteError = const NetworkFailure(message: 'down');
      await _open(tester, repo, testOrder(), statusSheet: false);

      await tester.enterText(byKeyName('noteField'), 'x');
      await tester.tap(byKeyName('noteSaveButton'));
      await tester.pumpAndSettle();

      expect(byKeyName('noteSaveButton'), findsOneWidget);
      expect(find.text(en.ordersErrorNetwork), findsOneWidget);
    });
  });
}
