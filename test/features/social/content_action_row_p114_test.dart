import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/presentation/content_action_row.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import 'fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the three looks of [ContentActionRow] (plain bar,
/// summary lines for posts, overlay column for reels). The behavior tests
/// (optimistic Like, Save, error revert) stay in `content_action_row_test.dart`
/// and run against the plain bar, which did not change.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
Future<void> _pumpRow(
  WidgetTester tester, {
  int likes = 0,
  int comments = 0,
  bool summary = false,
  bool overlay = false,
  Widget? caption,
  VoidCallback? onComment,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: ContentActionRow(
              contentType: 'post',
              objectId: 1,
              onCommentTap: onComment ?? () {},
              likesCount: likes,
              commentsCount: comments,
              showSummaryLines: summary,
              summaryCaption: caption,
              overlay: overlay,
            ),
          ),
        ),
      ),
    ),
  );
  // Let the deferred seed land.
  await tester.pump();
}

void main() {
  group('ContentActionRow (P-114) - plain bar (unchanged look)', () {
    testWidgets('keeps the compact counts beside the icons, no likes line', (
      tester,
    ) async {
      await _pumpRow(tester, likes: 1200, comments: 3);

      expect(find.text('1.2K'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('likes'), findsNothing);
      expect(find.textContaining('View'), findsNothing);
    });

    testWidgets('icons use the primary text colour of the theme', (
      tester,
    ) async {
      await _pumpRow(tester);

      final Icon share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
      expect(share.color, AppColors.light.textPrimary);
    });
  });

  group('ContentActionRow (P-114) - summary lines', () {
    testWidgets('likes line, then the caption, then the comments link', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        likes: 12,
        comments: 3,
        summary: true,
        caption: const Text('Caption here'),
      );

      final double likes = tester.getTopLeft(find.text('12 likes')).dy;
      final double caption = tester.getTopLeft(find.text('Caption here')).dy;
      final double link =
          tester.getTopLeft(find.text('View all 3 comments')).dy;

      expect(likes, lessThan(caption));
      expect(caption, lessThan(link));
    });

    testWidgets('the counts beside the icons are hidden', (tester) async {
      await _pumpRow(tester, likes: 12, comments: 3, summary: true);

      expect(find.text('12'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('tapping the comments link calls onCommentTap', (tester) async {
      int taps = 0;
      await _pumpRow(
        tester,
        comments: 2,
        summary: true,
        onComment: () => taps++,
      );

      await tester.tap(find.text('View all 2 comments'));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('ContentActionRow (P-114) - overlay column', () {
    testWidgets('stacks Like, Comment, Share, Save top to bottom', (
      tester,
    ) async {
      await _pumpRow(tester, overlay: true);

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dy;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dy;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dy;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dy;

      expect(like, lessThan(comment));
      expect(comment, lessThan(share));
      expect(share, lessThan(save));
    });

    testWidgets('icons are white and the counts are shown', (tester) async {
      await _pumpRow(tester, overlay: true, likes: 12, comments: 3);

      final Icon share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
      expect(share.color, const Color(0xFFFFFFFF));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ContentActionRow (P-114) - Arabic', () {
    testWidgets('tooltips come from the ARB file', (tester) async {
      await _pumpRow(tester, locale: const Locale('ar'));

      // Like, Comment, Share, Save in Arabic.
      expect(find.byTooltip('\u0625\u0639\u062c\u0627\u0628'), findsOneWidget);
      expect(find.byTooltip('\u062a\u0639\u0644\u064a\u0642'), findsOneWidget);
      expect(
        find.byTooltip('\u0645\u0634\u0627\u0631\u0643\u0629'),
        findsOneWidget,
      );
      expect(find.byTooltip('\u062d\u0641\u0638'), findsOneWidget);
    });
  });
}
