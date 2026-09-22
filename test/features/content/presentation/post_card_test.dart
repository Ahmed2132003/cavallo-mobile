import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';

const _post = PublicPost(
  id: 501,
  businessId: 7,
  caption: 'New arrivals just landed — check them out!',
  imageUrl: 'https://example.com/post-501.jpg',
);

/// Grows the test surface beyond the 800×600 default. `PostCard` fills
/// its parent's full width, and its image alone (`AspectRatio` 4:3)
/// already needs 600px of height at 800px wide — leaving zero room for
/// the business-name row, caption, and stub action row below it and
/// causing a real `RenderFlex overflowed` failure at the default size.
/// This is a test-environment limitation only: in the real app,
/// `PostCard` always renders inside a bounded-width list (the business
/// profile screen's `Column`, and eventually Phase 10's Feed), never at
/// full device width with no scroll parent.
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
        body: PostCard(post: _post, businessName: 'Al Ananka Store', onTap: onTap),
      ),
    ),
  );
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
      _growSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: const PublicPost(
                id: 502,
                businessId: 7,
                caption: 'No image on this one.',
              ),
              businessName: 'Al Ananka Store',
            ),
          ),
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

  group('PostCard — stub action row', () {
    // Split into three independent tests rather than tapping all three
    // icons in sequence within one test: each test here pumps a brand
    // new widget tree (a fresh ScaffoldMessengerState with nothing
    // queued), so there is no dependency on correctly waiting out a
    // previous SnackBar's hold-and-exit timing before the next tap —
    // that manual-timing approach proved flaky in practice (the
    // "Comment" tap's SnackBar was not reliably observable after a
    // fixed 5-second `pump`, even though "Like"'s was).
    testWidgets(
      'tapping Like shows an honest "coming soon" SnackBar instead of '
      'doing nothing silently',
      (tester) async {
        await _pumpCard(tester);

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pump();

        expect(find.text('Like — Coming soon'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Comment shows an honest "coming soon" SnackBar instead of '
      'doing nothing silently',
      (tester) async {
        await _pumpCard(tester);

        await tester.tap(find.byIcon(Icons.mode_comment_outlined));
        await tester.pump();

        expect(find.text('Comment — Coming soon'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Share shows an honest "coming soon" SnackBar instead of '
      'doing nothing silently',
      (tester) async {
        await _pumpCard(tester);

        await tester.tap(find.byIcon(Icons.share_outlined));
        await tester.pump();

        expect(find.text('Share — Coming soon'), findsOneWidget);
      },
    );
  });
}