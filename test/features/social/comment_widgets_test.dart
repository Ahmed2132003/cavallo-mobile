import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/comment_entity.dart';
import 'package:social_commerce_app/features/social/presentation/comment_input_widget.dart';
import 'package:social_commerce_app/features/social/presentation/comment_list_widget.dart';

import 'fake_social_interaction_repository.dart';

CommentEntity _comment({
  required int id,
  required String text,
  bool hidden = false,
}) {
  return CommentEntity(
    id: id,
    userId: 100 + id,
    contentType: 'post',
    objectId: 1,
    text: text,
    isHidden: hidden,
    createdAt: DateTime.utc(2026, 9, 24, 10),
  );
}

Widget _host(FakeSocialInteractionRepository fake, {bool withInput = false}) {
  return ProviderScope(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (withInput)
                const CommentInputWidget(contentType: 'post', objectId: 1),
              const CommentListWidget(contentType: 'post', objectId: 1),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('CommentListWidget trusts the backend response', () {
    testWidgets('shows a hidden comment the API returned, with a marker',
        (tester) async {
      // Simulates the comment's AUTHOR viewing: the backend includes their own
      // hidden comment. The widget must show it as-is, not filter it out.
      final fake = FakeSocialInteractionRepository()
        ..commentsToReturn = [
          _comment(id: 1, text: 'visible comment'),
          _comment(id: 2, text: 'my hidden comment', hidden: true),
        ];
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();

      expect(find.text('visible comment'), findsOneWidget);
      expect(find.text('my hidden comment'), findsOneWidget);
      expect(find.textContaining('Pending review'), findsOneWidget);
    });

    testWidgets('shows only what the API returned for another viewer',
        (tester) async {
      // Simulates an unrelated viewer: the backend already left the hidden
      // comment out, so nothing about it may appear in the UI.
      final fake = FakeSocialInteractionRepository()
        ..commentsToReturn = [_comment(id: 1, text: 'visible comment')];
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();

      expect(find.text('visible comment'), findsOneWidget);
      expect(find.text('my hidden comment'), findsNothing);
      expect(find.textContaining('Pending review'), findsNothing);
    });

    testWidgets('shows the empty state when there are no comments',
        (tester) async {
      await tester.pumpWidget(_host(FakeSocialInteractionRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No comments yet'), findsOneWidget);
    });

    testWidgets('shows an error and a Retry button when loading fails',
        (tester) async {
      final fake = FakeSocialInteractionRepository()
        ..errorToThrow = Exception('boom');
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CommentInputWidget', () {
    testWidgets('a new comment appears on top of the list and the field clears',
        (tester) async {
      final fake = FakeSocialInteractionRepository();
      await tester.pumpWidget(_host(fake, withInput: true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello there');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('createComment:post:1'));
      // Shown once (in the list), and the input field was cleared.
      expect(find.text('hello there'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('keeps the typed text and shows an error when posting fails',
        (tester) async {
      final fake = FakeSocialInteractionRepository();
      await tester.pumpWidget(_host(fake, withInput: true));
      await tester.pumpAndSettle();

      // Fail only from now on (the initial list load already succeeded).
      fake.errorToThrow = Exception('boom');

      await tester.enterText(find.byType(TextField), 'will fail');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'will fail');
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty comment sends nothing', (tester) async {
      final fake = FakeSocialInteractionRepository();
      await tester.pumpWidget(_host(fake, withInput: true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(
        fake.calls.where((c) => c.startsWith('createComment')),
        isEmpty,
      );
    });
  });
}