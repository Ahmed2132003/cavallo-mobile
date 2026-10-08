import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/comment_entity.dart';
import 'package:social_commerce_app/features/social/presentation/comment_input_widget.dart';
import 'package:social_commerce_app/features/social/presentation/comments_section.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import 'fake_social_interaction_repository.dart';

/// Part P-114 STEP 4B: the comments bottom sheet. Presentation only: these
/// tests prove the anatomy (sheet, avatar rows, skeleton, pinned input bar)
/// in English LTR, Arabic RTL and dark, and that posting still works.
CommentEntity _comment(int id, String text) => CommentEntity(
  id: id,
  userId: 100 + id,
  contentType: 'post',
  objectId: 1,
  text: text,
  isHidden: false,
  createdAt: DateTime.utc(2026, 9, 24, 10),
);

Widget _host(
  FakeSocialInteractionRepository fake, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showCommentsSheet(context, contentType: 'post', objectId: 1),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

FakeSocialInteractionRepository _twoComments() =>
    FakeSocialInteractionRepository()
      ..commentsToReturn = [_comment(1, 'first one'), _comment(2, 'second one')];

void main() {
  group('comments sheet', () {
    testWidgets('opens as a bottom sheet with title, avatar rows and input',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(CommentsSheet), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('first one'), findsOneWidget);
      expect(find.text('second one'), findsOneWidget);
      expect(find.byType(AppAvatar), findsNWidgets(2));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Post comment'), findsOneWidget);
    });

    testWidgets('posting from the sheet still creates the comment',
        (WidgetTester tester) async {
      final FakeSocialInteractionRepository fake = _twoComments();
      await tester.pumpWidget(_host(fake));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sheet comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('createComment:post:1'));
      expect(find.text('sheet comment'), findsOneWidget);
    });

    testWidgets('shows a skeleton, not a spinner, while the list loads',
        (WidgetTester tester) async {
      final FakeSocialInteractionRepository fake =
          FakeSocialInteractionRepository()..gate = Completer<void>();
      await tester.pumpWidget(_host(fake));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      fake.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('No comments yet. Be the first to comment.'),
          findsOneWidget);
    });

    testWidgets('Arabic: RTL sheet with localized title and hint',
        (WidgetTester tester) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      await tester.pumpWidget(_host(_twoComments(), locale: const Locale('ar')));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(CommentsSheet))),
        TextDirection.rtl,
      );
      expect(find.text(ar.commentsTitle), findsOneWidget);
      expect(find.byTooltip(ar.commentsPostTooltip), findsOneWidget);
      expect(find.text(ar.commentsAuthorFallback('101')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments(), theme: AppTheme.dark));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('first one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the input bar stays above the keyboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 300 logical px keyboard (the test view has a 3.0 pixel ratio).
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final double inputBottom = tester
          .getBottomLeft(find.byType(CommentInputWidget))
          .dy;
      final double screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(inputBottom, lessThanOrEqualTo(screenHeight - 300));
      expect(tester.takeException(), isNull);
    });
  });
}
