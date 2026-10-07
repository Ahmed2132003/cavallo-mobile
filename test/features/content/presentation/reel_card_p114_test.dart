import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the Instagram-style anatomy of [ReelCard], in English
/// (left-to-right) and Arabic (right-to-left), Light and Dark. The behavior
/// tests (Like, Comment, Report, tap) stay in `reel_card_test.dart`.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
PublicReel _reel({
  int likes = 0,
  int comments = 0,
  bool featured = false,
  String caption = 'Behind the scenes.',
}) {
  return PublicReel(
    id: 801,
    businessId: 7,
    caption: caption,
    likesCount: likes,
    commentsCount: comments,
    isFeatured: featured,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  PublicReel? reel,
  VoidCallback? onTap,
  bool verified = false,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: ReelCard(
            reel: reel ?? _reel(),
            businessName: 'Al Ananka Store',
            onTap: onTap,
            isBusinessVerified: verified,
          ),
        ),
      ),
    ),
  );
  // Let the deferred like/save seed of the action row land.
  await tester.pump();
}

/// The fixed 9:16 media box (the AspectRatio that holds the play mark).
Finder _media() => find.ancestor(
  of: find.byIcon(Icons.play_arrow),
  matching: find.byType(AspectRatio),
);

void main() {
  group('ReelCard (P-114) - media', () {
    testWidgets('media is a fixed 9:16 box', (tester) async {
      await _pump(tester);

      final AspectRatio box = tester.widget<AspectRatio>(_media());
      expect(box.aspectRatio, closeTo(9 / 16, 0.0001));
    });

    testWidgets('the caption is overlaid on the media, not below it', (
      tester,
    ) async {
      await _pump(tester);

      final Rect media = tester.getRect(_media());
      final Rect caption = tester.getRect(find.text('Behind the scenes.'));
      expect(caption.top, greaterThan(media.top));
      expect(caption.bottom, lessThanOrEqualTo(media.bottom));
    });

    testWidgets('the four actions are overlaid on the media', (tester) async {
      await _pump(tester);

      final Rect media = tester.getRect(_media());
      for (final IconData icon in <IconData>[
        Icons.favorite_border,
        Icons.mode_comment_outlined,
        Icons.share_outlined,
        Icons.bookmark_border,
      ]) {
        final Offset center = tester.getCenter(find.byIcon(icon));
        expect(media.contains(center), isTrue, reason: '$icon is outside');
      }
    });

    testWidgets('the counts are shown beside the overlaid actions', (
      tester,
    ) async {
      await _pump(tester, reel: _reel(likes: 12, comments: 3));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ReelCard (P-114) - reading direction', () {
    testWidgets('left-to-right: the actions sit at the right (end) side', (
      tester,
    ) async {
      await _pump(tester);

      final double middle = tester.getCenter(find.byType(ReelCard)).dx;
      expect(tester.getCenter(find.byIcon(Icons.favorite_border)).dx, greaterThan(middle));
    });

    testWidgets('right-to-left: the actions sit at the left (end) side', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('ar'));

      final double middle = tester.getCenter(find.byType(ReelCard)).dx;
      expect(tester.getCenter(find.byIcon(Icons.favorite_border)).dx, lessThan(middle));
    });

    testWidgets('Arabic tooltips come from the ARB file', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      // Like (ar) and Save (ar).
      expect(
        find.byTooltip('\u0625\u0639\u062c\u0627\u0628'),
        findsOneWidget,
      );
      expect(find.byTooltip('\u062d\u0641\u0638'), findsOneWidget);
    });
  });

  group('ReelCard (P-114) - header and theme', () {
    testWidgets('Verified mark and Featured badge show only when set', (
      tester,
    ) async {
      await _pump(tester);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsNothing,
      );
      expect(find.byType(FeaturedBadge), findsNothing);

      await _pump(tester, reel: _reel(featured: true), verified: true);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsOneWidget,
      );
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('renders in Dark without errors', (tester) async {
      await _pump(
        tester,
        reel: _reel(likes: 5, comments: 2, featured: true),
        verified: true,
        theme: AppTheme.dark,
      );

      expect(find.byType(ReelCard), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
