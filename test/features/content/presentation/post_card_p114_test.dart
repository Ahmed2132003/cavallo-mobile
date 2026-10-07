import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/core/widgets/media_carousel.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the Instagram-style anatomy of [PostCard], in English
/// (left-to-right) and Arabic (right-to-left), Light and Dark. The behavior
/// tests (Like, Comment, Report, tap) stay in `post_card_test.dart`.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
const PublicPost _post = PublicPost(
  id: 701,
  businessId: 7,
  caption: 'New arrivals just landed.',
);

PublicPost _with({
  int likes = 0,
  int comments = 0,
  bool featured = false,
  DateTime? createdAt,
  String caption = 'New arrivals just landed.',
}) {
  return PublicPost(
    id: 701,
    businessId: 7,
    caption: caption,
    likesCount: likes,
    commentsCount: comments,
    isFeatured: featured,
    createdAt: createdAt,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  PublicPost post = _post,
  VoidCallback? onTap,
  bool verified = false,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // A clean tree each time, so a test can call _pump more than once.
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
          body: PostCard(
            post: post,
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

void main() {
  group('PostCard (P-114) - header', () {
    testWidgets('shows the avatar and the name, and no Verified mark', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsNothing,
      );
      expect(find.byType(FeaturedBadge), findsNothing);
    });

    testWidgets('shows the blue Verified mark when the business is verified', (
      tester,
    ) async {
      await _pump(tester, verified: true);

      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsOneWidget,
      );
    });

    testWidgets('shows the single Featured badge for a Featured business', (
      tester,
    ) async {
      await _pump(tester, post: _with(featured: true));

      expect(find.byType(FeaturedBadge), findsOneWidget);
    });
  });

  group('PostCard (P-114) - media and action row', () {
    testWidgets('media is a fixed 1:1 box', (tester) async {
      await _pump(tester);

      final AspectRatio box = tester.widget<AspectRatio>(
        find.descendant(
          of: find.byType(MediaCarousel),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(box.aspectRatio, 1);
    });

    testWidgets('left-to-right: Like, Comment, Share first, Save last', (
      tester,
    ) async {
      await _pump(tester);

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dx;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dx;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dx;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dx;

      expect(like, lessThan(comment));
      expect(comment, lessThan(share));
      expect(share, lessThan(save));
    });

    testWidgets('right-to-left: the same order, mirrored', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dx;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dx;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dx;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dx;

      expect(like, greaterThan(comment));
      expect(comment, greaterThan(share));
      expect(share, greaterThan(save));
    });

    testWidgets('the counts beside the icons are replaced by the likes line', (
      tester,
    ) async {
      await _pump(tester, post: _with(likes: 12, comments: 3));

      expect(find.text('12 likes'), findsOneWidget);
      // Not repeated as bare numbers next to the icons.
      expect(find.text('12'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('PostCard (P-114) - likes line, comments link, time', () {
    testWidgets('likes line: none for 0, singular for 1, compact for 1200', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.textContaining('like'), findsNothing);

      await _pump(tester, post: _with(likes: 1));
      expect(find.text('1 like'), findsOneWidget);

      await _pump(tester, post: _with(likes: 1200));
      expect(find.text('1.2K likes'), findsOneWidget);
    });

    testWidgets('comments link: "View 1 comment" and "View all 3 comments"', (
      tester,
    ) async {
      await _pump(tester, post: _with(comments: 1));
      expect(find.text('View 1 comment'), findsOneWidget);

      await _pump(tester, post: _with(comments: 3));
      expect(find.text('View all 3 comments'), findsOneWidget);
    });

    testWidgets('no comments link when there are no comments', (tester) async {
      await _pump(tester);

      expect(find.textContaining('comment'), findsNothing);
    });

    testWidgets('tapping the comments link calls onTap once', (tester) async {
      int taps = 0;
      await _pump(tester, post: _with(comments: 3), onTap: () => taps++);

      await tester.tap(find.text('View all 3 comments'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a long caption is cut with "more" and expands in place', (
      tester,
    ) async {
      final String longCaption = List<String>.filled(60, 'word').join(' ');
      await _pump(tester, post: _with(caption: longCaption));

      expect(find.text('more'), findsOneWidget);

      await tester.tap(find.text('more'));
      await tester.pump();

      expect(find.text('more'), findsNothing);
      expect(find.text(longCaption), findsOneWidget);
    });

    testWidgets('relative time is shown under the action row', (tester) async {
      await _pump(
        tester,
        post: _with(
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );

      expect(find.text('3 hours ago'), findsOneWidget);
    });
  });

  group('PostCard (P-114) - Arabic and Dark', () {
    testWidgets('Arabic: likes line and tooltips come from the ARB file', (
      tester,
    ) async {
      await _pump(
        tester,
        post: _with(likes: 1),
        locale: const Locale('ar'),
      );

      // "One like" (ar) and the Like tooltip (ar).
      expect(
        find.text('\u0625\u0639\u062c\u0627\u0628 \u0648\u0627\u062d\u062f'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('\u0625\u0639\u062c\u0627\u0628'),
        findsOneWidget,
      );
    });

    testWidgets('renders in Dark without errors', (tester) async {
      await _pump(
        tester,
        post: _with(likes: 5, comments: 2, featured: true),
        verified: true,
        theme: AppTheme.dark,
      );

      expect(find.byType(PostCard), findsOneWidget);
      expect(find.text('5 likes'), findsOneWidget);
    });
  });
}
