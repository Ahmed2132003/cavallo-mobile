import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/presentation/follow_button.dart';

import 'fake_social_interaction_repository.dart';

Widget _host(FakeSocialInteractionRepository fake, {VoidCallback? onToggled}) {
  return ProviderScope(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: FollowButton(
            businessId: 5,
            followerCount: 12,
            onToggled: onToggled,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('starts as Follow with the real follower count', (tester) async {
    await tester.pumpWidget(_host(FakeSocialInteractionRepository()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Follow'), findsOneWidget);
    expect(find.text('12 followers'), findsOneWidget);
  });

  testWidgets(
    'tapping Follow shows Following and the higher count immediately, '
    'before any response',
    (tester) async {
      final fake = FakeSocialInteractionRepository();
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();

      // Close the gate only now, after the widget finished seeding.
      fake.gate = Completer<void>();

      await tester.tap(find.widgetWithText(AppButton, 'Follow'));
      await tester.pump();

      // The "server" has not answered yet.
      expect(find.widgetWithText(AppButton, 'Following'), findsOneWidget);
      expect(find.text('13 followers'), findsOneWidget);

      fake.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Following'), findsOneWidget);
      expect(find.text('13 followers'), findsOneWidget);
      expect(fake.calls, ['follow:5']);
    },
  );

  testWidgets(
    'a failed Follow reverts the label and the count and shows an error',
    (tester) async {
      final fake = FakeSocialInteractionRepository();
      var toggledCalls = 0;
      await tester.pumpWidget(_host(fake, onToggled: () => toggledCalls++));
      await tester.pumpAndSettle();

      fake.gate = Completer<void>();
      fake.errorToThrow = Exception('boom');

      await tester.tap(find.widgetWithText(AppButton, 'Follow'));
      await tester.pump();
      expect(find.widgetWithText(AppButton, 'Following'), findsOneWidget);

      fake.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Follow'), findsOneWidget);
      expect(find.text('12 followers'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      // onToggled must not run after a failed request.
      expect(toggledCalls, 0);
    },
  );

  testWidgets('tapping Following unfollows and lowers the count', (
    tester,
  ) async {
    final fake = FakeSocialInteractionRepository();
    var toggledCalls = 0;
    await tester.pumpWidget(_host(fake, onToggled: () => toggledCalls++));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Follow'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Following'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Follow'), findsOneWidget);
    expect(find.text('12 followers'), findsOneWidget);
    expect(fake.calls, ['follow:5', 'unfollow:5']);
    expect(toggledCalls, 2);
  });

  testWidgets('a second tap while a request is in flight is ignored', (
    tester,
  ) async {
    final fake = FakeSocialInteractionRepository();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    fake.gate = Completer<void>();

    await tester.tap(find.widgetWithText(AppButton, 'Follow'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Following'));
    await tester.pump();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    // Only the first request went out; the second tap did nothing.
    expect(fake.calls, ['follow:5']);
    expect(find.widgetWithText(AppButton, 'Following'), findsOneWidget);
  });
}