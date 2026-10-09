import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/presentation/content_list_screen.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_list_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 5B): restyle checks for the content and stories tabs of
/// the Business Console. The behaviour tests (status rules, polling, retry,
/// refresh, navigation) stay in the P-044 / P-051 / P-083 test files, which
/// are unchanged. ASCII only: Arabic is read from the generated localizations.

class _EmptyContent extends OwnContentNotifier {
  @override
  Future<List<ContentItem>> build() async => const <ContentItem>[];
}

class _EmptyStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => const <OwnStory>[];
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<dynamic> overrides, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('content tab: empty state and create buttons in Arabic', (
    tester,
  ) async {
    await _pump(
      tester,
      ContentListScreen(onCreatePost: () {}, onCreateReel: () {}),
      [ownContentProvider.overrideWith(_EmptyContent.new)],
      locale: const Locale('ar'),
      theme: AppTheme.dark,
    );
    final l10n = lookupAppLocalizations(const Locale('ar'));

    expect(find.text(l10n.consoleContentTitle), findsOneWidget);
    expect(find.text(l10n.consoleContentNewPost), findsOneWidget);
    expect(find.text(l10n.consoleContentNewReel), findsOneWidget);
    expect(find.text(l10n.consoleContentEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stories tab: empty state and create button in Arabic', (
    tester,
  ) async {
    await _pump(tester, const StoryListScreen(), [
      ownStoriesProvider.overrideWith(_EmptyStories.new),
    ], locale: const Locale('ar'));
    final l10n = lookupAppLocalizations(const Locale('ar'));

    expect(find.text(l10n.consoleNavStories), findsOneWidget);
    expect(find.text(l10n.consoleStoriesCreate), findsOneWidget);
    expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stories tab: empty state in English, light theme', (
    tester,
  ) async {
    await _pump(tester, const StoryListScreen(), [
      ownStoriesProvider.overrideWith(_EmptyStories.new),
    ]);
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(find.text(l10n.consoleStoriesEmpty), findsOneWidget);
  });
}
