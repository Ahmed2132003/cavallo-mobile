import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import '../../social/fake_social_interaction_repository.dart';

const _post = PublicPost(
  id: 501,
  businessId: 7,
  caption: 'New arrivals just landed — check them out!',
  imageUrl: 'https://example.com/post-501.jpg',
);

/// Grows the test surface beyond the 800×600 default. `PostCard` fills
/// its parent's full width, and its image alone (`AspectRatio` 4:3)
/// already needs 600px of height at 800px wide — leaving zero room for
/// the business-name row, caption, and action row below it and causing a
/// real `RenderFlex overflowed` failure at the default size. This is a
/// test-environment limitation only: in the real app, `PostCard` always
/// renders inside a bounded-width list, never at full device width with
/// no scroll parent.
void _growSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Part P-058: `PostCard` now contains `ContentActionRow` (a Riverpod
/// ConsumerWidget), so every test needs a `ProviderScope` with the social
/// repository overridden by a controllable fake (never the real Dio one).
Future<FakeSocialInteractionRepository> _pumpCard(
  WidgetTester tester, {
  PublicPost post = _post,
  VoidCallback? onTap,
  FakeSocialInteractionRepository? repository,
}) async {
  final fake = repository ?? FakeSocialInteractionRepository();
  _growSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post,
            businessName: 'Al Ananka Store',
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
  return fake;
}

void main() {
  group('PostCard — rendering', () {
    testWidgets('renders the business name and caption', (tester) async {
      await _pumpCard(tester);

      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(
        find.text('New arrivals just landed — check them out!'),
        findsOneWidget,
      );
    });

    testWidgets('renders a neutral placeholder when imageUrl is null', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        post: const PublicPost(
          id: 502,
          businessId: 7,
          caption: 'No image on this one.',
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tapping the card invokes onTap', (tester) async {
      var tapped = false;
      await _pumpCard(tester, onTap: () => tapped = true);

      await tester.tap(find.byType(PostCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('PostCard — Like (optimistic update)', () {
    testWidgets(
      'tapping Like shows the liked state immediately, before any response',
      (tester) async {
        final fake = FakeSocialInteractionRepository()
          ..gate = Completer<void>();
        await _pumpCard(tester, repository: fake);

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
        expect(fake.calls, ['like:post:501']);
      },
    );

    testWidgets(
      'a failed Like reverts to the unliked state and shows an error',
      (tester) async {
        final fake = FakeSocialInteractionRepository()
          ..gate = Completer<void>()
          ..errorToThrow = Exception('boom');
        await _pumpCard(tester, repository: fake);

        await tester.tap(find.byTooltip('Like'));
        await tester.pump();
        expect(find.byIcon(Icons.favorite), findsOneWidget);

        fake.gate!.complete();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.text('1'), findsNothing);
        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });

  group('PostCard — Comment', () {
    testWidgets('tapping Comment invokes onTap and makes no network call', (
      tester,
    ) async {
      var tapped = 0;
      final fake = await _pumpCard(tester, onTap: () => tapped++);

      await tester.tap(find.byTooltip('Comment'));
      await tester.pump();

      expect(tapped, 1);
      expect(fake.calls, isEmpty);
    });
  });

  group('PostCard — Report menu', () {
    testWidgets(
      'the "..." menu opens a reason picker with exactly the 4 reasons, '
      'and Submit sends the chosen one',
      (tester) async {
        final fake = await _pumpCard(tester);

        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();

        expect(find.text('Spam'), findsOneWidget);
        expect(find.text('Inappropriate content'), findsOneWidget);
        expect(find.text('Misleading'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);

        final submit = find.widgetWithText(FilledButton, 'Submit');
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);

        await tester.tap(find.text('Inappropriate content'));
        await tester.pump();
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(fake.calls, ['report:post:501:inappropriate']);
        expect(find.text('Thanks, your report was submitted.'), findsOneWidget);
        expect(find.text('Submit'), findsNothing);
      },
    );

    testWidgets(
      'a failed report keeps the dialog open and shows the error inside it',
      (tester) async {
        final fake = FakeSocialInteractionRepository()
          ..errorToThrow = Exception('boom');
        await _pumpCard(tester, repository: fake);

        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Spam'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
        await tester.pumpAndSettle();

        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Submit'), findsOneWidget);
        expect(find.text('Thanks, your report was submitted.'), findsNothing);
      },
    );
  });
}