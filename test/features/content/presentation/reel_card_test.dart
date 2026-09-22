import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';

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

Future<void> _pumpCard(WidgetTester tester, {VoidCallback? onTap}) async {
  _growSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReelCard(reel: _reel, businessName: 'Al Ananka Store', onTap: onTap),
      ),
    ),
  );
}

void main() {
  group('ReelCard — rendering', () {
    testWidgets('renders the business name, caption, and a play overlay', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(
        find.text('Behind the scenes at our workshop.'),
        findsOneWidget,
      );
      // The play-icon overlay is purely decorative on the card (real
      // playback is the Reel detail screen's own, separately-flagged
      // stub — see reel_detail_screen.dart) — present, but not asserted
      // as tappable here.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders a neutral placeholder when thumbnailUrl is null', (
      tester,
    ) async {
      _growSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReelCard(
              reel: const PublicReel(
                id: 602,
                businessId: 7,
                caption: 'No thumbnail yet — still processing.',
              ),
              businessName: 'Al Ananka Store',
            ),
          ),
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

  group('ReelCard — stub action row', () {
    testWidgets(
      'tapping Like/Comment/Share shows an honest "coming soon" SnackBar '
      'instead of doing nothing silently',
      (tester) async {
        await _pumpCard(tester);

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pump();
        expect(find.text('Like — Coming soon'), findsOneWidget);
      },
    );
  });
}