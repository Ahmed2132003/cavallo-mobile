import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import '../../social/fake_social_interaction_repository.dart';

const _reel = PublicReel(
  id: 601,
  businessId: 7,
  caption: 'Behind the scenes at our workshop.',
  videoUrl: 'https://example.com/reel-601.mp4',
  thumbnailUrl: 'https://example.com/reel-601-thumb.jpg',
  durationSeconds: 42,
);

/// See `post_card_test.dart`'s identical helper for why this is needed —
/// same 4:3-image-vs-800×600-default overflow, same fix.
void _growSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Part P-058: `ReelCard` contains `ContentActionRow`, so every test needs
/// a `ProviderScope` with the social repository overridden by a fake.
Future<FakeSocialInteractionRepository> _pumpCard(
  WidgetTester tester, {
  PublicReel reel = _reel,
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
          body: ReelCard(
            reel: reel,
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
  group('ReelCard — rendering', () {
    testWidgets('renders the business name, caption, and a play overlay', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(find.text('Behind the scenes at our workshop.'), findsOneWidget);
      // The play-icon overlay is purely decorative on the card (real
      // playback is the Reel detail screen's own, separately-flagged
      // stub) — present, but not asserted as tappable here.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders a neutral placeholder when thumbnailUrl is null', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        reel: const PublicReel(
          id: 602,
          businessId: 7,
          caption: 'No thumbnail yet — still processing.',
        ),
      );

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tapping the card invokes onTap', (tester) async {
      var tapped = false;
      await _pumpCard(tester, onTap: () => tapped = true);

      await tester.tap(find.byType(ReelCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('ReelCard — Like and Comment', () {
    testWidgets(
      'tapping Like shows the liked state immediately, before any response',
      (tester) async {
        final fake = FakeSocialInteractionRepository()
          ..gate = Completer<void>();
        await _pumpCard(tester, repository: fake);

        await tester.tap(find.byTooltip('Like'));
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);

        fake.gate!.complete();
        await tester.pumpAndSettle();

        expect(fake.calls, ['like:reel:601']);
      },
    );

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

  group('ReelCard — Report menu', () {
    testWidgets('the "..." menu reports the Reel with the chosen reason', (
      tester,
    ) async {
      final fake = await _pumpCard(tester);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Misleading'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['report:reel:601:misleading']);
      expect(find.text('Thanks, your report was submitted.'), findsOneWidget);
    });
  });
}