import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/presentation/saved_screen.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import 'saved_test_support.dart';

/// Part P-113 (STEP 3B): widget tests of the Saved screen.
///
/// * three tabs, each showing only its own type;
/// * rows open the existing Post / Reel / Product detail route;
/// * a row whose target is gone says so and opens nothing;
/// * unsave in place, with a message and a rollback when it fails;
/// * empty and error states;
/// * pages are loaded automatically while a tab is short;
/// * the list is refreshed when the tab becomes active again;
/// * Arabic labels.

const String _arPosts = '\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a';
const String _arProducts =
    '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a';

GoRouter _router(ValueNotifier<bool> tabActive) {
  GoRoute stub(String name, String path) {
    return GoRoute(
      path: path,
      name: name,
      builder:
          (BuildContext context, GoRouterState state) => Scaffold(
            appBar: AppBar(),
            body: Text('stub:$name:${state.pathParameters[RouteNames.idParam]}'),
          ),
    );
  }

  return GoRouter(
    initialLocation: RouteNames.savedPath,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.savedPath,
        name: RouteNames.saved,
        builder:
            (BuildContext context, GoRouterState state) =>
                ValueListenableBuilder<bool>(
                  valueListenable: tabActive,
                  builder:
                      (BuildContext context, bool active, Widget? child) =>
                          TickerMode(enabled: active, child: child!),
                  child: const SavedScreen(),
                ),
      ),
      stub(RouteNames.postDetail, RouteNames.postDetailPath),
      stub(RouteNames.reelDetail, RouteNames.reelDetailPath),
      stub(RouteNames.productDetail, RouteNames.productDetailPath),
    ],
  );
}

Future<ValueNotifier<bool>> _pump(
  WidgetTester tester, {
  required FakeSavedRepository saved,
  required FakeSocialInteractionRepository social,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ValueNotifier<bool> tabActive = ValueNotifier<bool>(true);
  addTearDown(tabActive.dispose);
  final GoRouter router = _router(tabActive);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => FakeSavedSession(savedTestCustomer)),
        savedRepositoryProvider.overrideWithValue(saved),
        socialInteractionRepositoryProvider.overrideWithValue(social),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tabActive;
}

Future<void> _selectTab(WidgetTester tester, SavedContentType type) async {
  await tester.tap(find.byKey(SavedScreen.tabKey(type)));
  await tester.pumpAndSettle();
}

Finder _item(SavedContentType type, int objectId) =>
    find.byKey(SavedScreen.itemKey(type, objectId));

Finder _unsaveButton(SavedContentType type, int objectId) =>
    find.byKey(SavedScreen.unsaveKey(type, objectId));

FakeSavedRepository _mixedRepository() {
  return FakeSavedRepository(<List<SavedItem>>[
    <SavedItem>[
      savedTestItem(5, SavedContentType.post, objectId: 105, text: 'Linen shirt'),
      savedTestItem(4, SavedContentType.reel, objectId: 204, text: 'Factory tour'),
      savedTestItem(3, SavedContentType.product, objectId: 303, text: 'Cotton roll'),
      savedTestItem(2, SavedContentType.post, objectId: 102, unavailable: true),
      savedTestItem(1, SavedContentType.post, objectId: 101, text: 'Denim lookbook'),
    ],
  ]);
}

void main() {
  testWidgets('each tab shows only its own type', (WidgetTester tester) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);

    // Posts tab (selected first).
    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(find.text('Linen shirt'), findsOneWidget);
    expect(find.text('Denim lookbook'), findsOneWidget);
    expect(_item(SavedContentType.reel, 204), findsNothing);

    await _selectTab(tester, SavedContentType.reel);
    expect(_item(SavedContentType.reel, 204), findsOneWidget);
    expect(find.text('Factory tour'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);

    await _selectTab(tester, SavedContentType.product);
    expect(_item(SavedContentType.product, 303), findsOneWidget);
    expect(find.text('Cotton roll'), findsOneWidget);
  });

  testWidgets('tapping a row opens the matching detail route', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    await tester.tap(_item(SavedContentType.post, 105));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.postDetail}:105'), findsOneWidget);

    // Back to the Saved screen, then a Reel and a Product.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _selectTab(tester, SavedContentType.reel);
    await tester.tap(_item(SavedContentType.reel, 204));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.reelDetail}:204'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _selectTab(tester, SavedContentType.product);
    await tester.tap(_item(SavedContentType.product, 303));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.productDetail}:303'), findsOneWidget);
  });

  testWidgets('an item whose target is gone says so and opens nothing', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('This item is no longer available'), findsOneWidget);

    await tester.tap(_item(SavedContentType.post, 102));
    await tester.pumpAndSettle();

    expect(find.textContaining('stub:'), findsNothing);
    expect(find.byKey(SavedScreen.tabBarKey), findsOneWidget);
  });

  testWidgets('unsave removes the row in place and calls the unsave API', (
    WidgetTester tester,
  ) async {
    final FakeSocialInteractionRepository social =
        FakeSocialInteractionRepository();
    await _pump(tester, saved: _mixedRepository(), social: social);
    expect(_item(SavedContentType.post, 105), findsOneWidget);

    await tester.tap(_unsaveButton(SavedContentType.post, 105));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsNothing);
    expect(_item(SavedContentType.post, 101), findsOneWidget);
    expect(social.unsaved, hasLength(1));
    expect(social.unsaved.single.contentType, 'post');
    expect(social.unsaved.single.objectId, 105);
  });

  testWidgets('a failed unsave keeps the row and tells the user', (
    WidgetTester tester,
  ) async {
    final FakeSocialInteractionRepository social =
        FakeSocialInteractionRepository()..fail = true;
    await _pump(tester, saved: _mixedRepository(), social: social);

    await tester.tap(_unsaveButton(SavedContentType.post, 105));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(
      find.text("Couldn't remove it from saved. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('every tab has its own empty message', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: FakeSavedRepository(<List<SavedItem>>[<SavedItem>[]]),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.byKey(SavedScreen.emptyKey(SavedContentType.post)), findsOneWidget);
    expect(
      find.text('No saved posts yet. Tap the bookmark on a post to keep it here.'),
      findsOneWidget,
    );

    await _selectTab(tester, SavedContentType.reel);
    expect(find.byKey(SavedScreen.emptyKey(SavedContentType.reel)), findsOneWidget);
    expect(
      find.text('No saved reels yet. Tap the bookmark on a reel to keep it here.'),
      findsOneWidget,
    );

    await _selectTab(tester, SavedContentType.product);
    expect(
      find.byKey(SavedScreen.emptyKey(SavedContentType.product)),
      findsOneWidget,
    );
    expect(
      find.text(
        'No saved products yet. Tap the bookmark on a product to keep it here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed first load shows Retry and Retry reloads', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = _mixedRepository()
      ..failNext = StateError('offline');
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsOneWidget);
  });

  testWidgets('pages are loaded automatically while a tab is short', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = FakeSavedRepository(<List<SavedItem>>[
      <SavedItem>[savedTestItem(2, SavedContentType.post, objectId: 102)],
      <SavedItem>[savedTestItem(1, SavedContentType.product, objectId: 301)],
    ]);
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    // The Posts tab has one row (< minRowsPerTab) and the server has more.
    expect(saved.requestedCursors, <String?>[null, '1']);

    await _selectTab(tester, SavedContentType.product);
    expect(_item(SavedContentType.product, 301), findsOneWidget);
  });

  testWidgets('a failed page load shows a retry row and does not loop', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = FakeSavedRepository(<List<SavedItem>>[
      <SavedItem>[savedTestItem(2, SavedContentType.post, objectId: 102)],
      <SavedItem>[savedTestItem(1, SavedContentType.post, objectId: 101)],
    ])..failOnCursor = '1';
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    // The automatic page load failed once and was NOT retried in a loop.
    expect(saved.requestedCursors, <String?>[null, '1']);
    expect(_item(SavedContentType.post, 102), findsOneWidget);
    expect(find.byKey(SavedScreen.retryMoreKey), findsOneWidget);
    expect(find.text("Couldn't load more saved items."), findsOneWidget);

    saved.failOnCursor = null;
    await tester.tap(find.byKey(SavedScreen.retryMoreKey));
    await tester.pumpAndSettle();

    expect(saved.requestedCursors, <String?>[null, '1', '1']);
    expect(_item(SavedContentType.post, 101), findsOneWidget);
    expect(find.byKey(SavedScreen.retryMoreKey), findsNothing);
  });

  testWidgets('the list is refreshed when the tab becomes active again', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = _mixedRepository();
    final ValueNotifier<bool> tabActive = await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );
    expect(saved.requestedCursors, <String?>[null]);

    // Another tab is shown: no request.
    tabActive.value = false;
    await tester.pumpAndSettle();
    expect(saved.requestedCursors, <String?>[null]);

    // The Saved tab is shown again: one silent refresh.
    saved.pages
      ..clear()
      ..add(<SavedItem>[
        savedTestItem(9, SavedContentType.post, objectId: 909, text: 'Fresh save'),
      ]);
    tabActive.value = true;
    await tester.pumpAndSettle();

    expect(saved.requestedCursors, <String?>[null, null]);
    expect(find.text('Fresh save'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);
  });

  testWidgets('works in Arabic', (WidgetTester tester) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
      locale: const Locale('ar'),
    );

    expect(find.text(_arPosts), findsOneWidget);
    expect(find.text(_arProducts), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(SavedScreen.tabBarKey))),
      TextDirection.rtl,
    );
  });
}
