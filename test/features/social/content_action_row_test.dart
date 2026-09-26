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

  group('Part BUGFIX-058: seeding from real per-viewer data', () {
    testWidgets(
      'seeded with isLiked: true, isSaved: true and real counts shows the '
      'liked/saved state and counts immediately, before any interaction — '
      'this is the exact bug: a card must never render as "not liked" for '
      'an account that actually already liked it',
      (tester) async {
        final fake = FakeSocialInteractionRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialInteractionRepositoryProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ContentActionRow(
                  contentType: 'post',
                  objectId: 1,
                  onCommentTap: () {},
                  isLiked: true,
                  isSaved: true,
                  likesCount: 12,
                  commentsCount: 3,
                  sharesCount: 1,
                  updatedAt: DateTime.utc(2026, 9, 24),
                ),
              ),
            ),
          ),
        );

        // Very first frame, zero interaction, before the deferred seed's
        // microtask has even had a chance to run.
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(fake.calls, isEmpty);

        // Once the deferred seed has actually landed, the provider itself
        // now agrees, and the widget keeps showing the same real values
        // (reading from the provider branch of build() instead of the
        // constructor-fallback branch, per the `_seeded` flag).
        await tester.pump();
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
      },
    );

    testWidgets(
      'reseeds when the parent supplies new per-viewer data for the same '
      '(contentType, objectId) — e.g. a different account\'s real data '
      'replacing the previous one\'s for the same widget/key, such as after '
      'a pull-to-refresh or a fresh feed page post-account-switch',
      (tester) async {
        final fake = FakeSocialInteractionRepository();
        Widget hostWith({required bool isLiked, required int likesCount}) {
          return ProviderScope(
            overrides: [
              socialInteractionRepositoryProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ContentActionRow(
                  contentType: 'post',
                  objectId: 1,
                  onCommentTap: () {},
                  isLiked: isLiked,
                  likesCount: likesCount,
                  updatedAt: DateTime.utc(2026, 9, 24),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(hostWith(isLiked: true, likesCount: 5));
        await tester.pump();
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.text('5'), findsOneWidget);

        // Same widget tree, same (contentType, objectId) — new real data,
        // exactly what a different signed-in account viewing the same
        // content would supply.
        await tester.pumpWidget(hostWith(isLiked: false, likesCount: 2));
        await tester.pump();

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.text('2'), findsOneWidget);
      },
    );
  });
}