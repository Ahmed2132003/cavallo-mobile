import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/presentation/content_action_row.dart';

import 'fake_social_interaction_repository.dart';

Widget _host(FakeSocialInteractionRepository fake, {VoidCallback? onComment}) {
  return ProviderScope(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: ContentActionRow(
          contentType: 'post',
          objectId: 1,
          onCommentTap: onComment ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Like shows the liked state immediately, before any response',
      (tester) async {
    final fake = FakeSocialInteractionRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake));

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byTooltip('Like'));
    await tester.pump();

    // The "server" has not answered yet (the gate is still closed).
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('1'), findsOneWidget);

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Like reverts and shows an error when the request fails',
      (tester) async {
    final fake = FakeSocialInteractionRepository()
      ..gate = Completer<void>()
      ..errorToThrow = Exception('boom');
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Like'));
    await tester.pump();

    // Optimistic state is visible while the request is still pending.
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    fake.gate!.complete();
    await tester.pumpAndSettle();

    // Reverted, and a brief error indication is shown.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Save toggles the bookmark immediately', (tester) async {
    final fake = FakeSocialInteractionRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('Comment icon calls onCommentTap and makes no network call',
      (tester) async {
    final fake = FakeSocialInteractionRepository();
    var tapped = 0;
    await tester.pumpWidget(_host(fake, onComment: () => tapped++));

    await tester.tap(find.byTooltip('Comment'));
    await tester.pump();

    expect(tapped, 1);
    expect(fake.calls, isEmpty);
  });
}