// test/features/business_console/presentation/business_console_shell_test.dart
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/business_console/presentation/business_console_shell.dart';
import 'package:social_commerce_app/features/stories/data/story_creation_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_upload_queue_provider.dart';

/// Part P-083 (Chat 2). Widget tests for [BusinessConsoleShell].
///
/// The router below is built INSIDE this file on purpose: it mirrors
/// the shape the real `app_router.dart` gives the shell (a
/// `StatefulShellRoute.indexedStack` with four branches, in the
/// shared-contract order) but uses throw-away fake pages, so these
/// tests exercise the shell widget alone and do not depend on the
/// real router, the real screens, or any gate logic.

const _navProducts = Key('business-console-nav-products');
const _navContent = Key('business-console-nav-content');
const _navStories = Key('business-console-nav-stories');
const _navAnalytics = Key('business-console-nav-analytics');
const _navBar = Key('business-console-nav-bar');
const _banner = Key('storyUploadStatusBanner');

/// Never resolves — keeps an enqueued upload in the `uploading` state
/// deterministically, with no backoff Timer left pending.
class _NeverCompletesRepository extends StoryCreationRepository {
  _NeverCompletesRepository() : super(dio: Dio());

  @override
  Future<void> uploadStoryMedia({
    required File mediaFile,
    CancelToken? cancelToken,
  }) {
    return Completer<void>().future;
  }
}

/// A path-only [File]; it is never created or read (the fake
/// repository above ignores it).
File _fakeMediaFile() => File(
  '${Directory.systemTemp.path}/p083_shell_test_'
  '${DateTime.now().microsecondsSinceEpoch}.png',
);

/// A plain fake page: no AppBar, one identifiable text.
class _FakePage extends StatelessWidget {
  const _FakePage({required this.name, this.child});

  final String name;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final extra = child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('page $name', key: Key('page-$name')),
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }
}

/// Branch-0 root. Counts how many times it has been mounted, and
/// shows the top inset it sees, so tests can observe both remounts
/// and the status-bar handling.
class _ProductsRoot extends StatefulWidget {
  const _ProductsRoot();

  static int initCount = 0;

  @override
  State<_ProductsRoot> createState() => _ProductsRootState();
}

class _ProductsRootState extends State<_ProductsRoot> {
  @override
  void initState() {
    super.initState();
    _ProductsRoot.initCount++;
  }

  @override
  Widget build(BuildContext context) {
    return _FakePage(
      name: 'products',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'inset:${MediaQuery.paddingOf(context).top}',
            key: const Key('inset-probe'),
          ),
          ElevatedButton(
            key: const Key('open-detail'),
            onPressed: () => context.go('/products/detail'),
            child: const Text('open detail'),
          ),
        ],
      ),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/products',
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                BusinessConsoleShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const _ProductsRoot(),
                routes: [
                  GoRoute(
                    path: 'detail',
                    builder:
                        (context, state) =>
                            const _FakePage(name: 'products-detail'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/content',
                builder: (context, state) => const _FakePage(name: 'content'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stories',
                builder: (context, state) => const _FakePage(name: 'stories'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const _FakePage(name: 'analytics'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  double statusBarHeight = 0,
}) async {
  final container = ProviderContainer(
    overrides: [
      storyCreationRepositoryProvider.overrideWithValue(
        _NeverCompletesRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = _buildRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.theme,
        routerConfig: router,
        builder: (context, child) {
          if (statusBarHeight == 0) return child!;
          final data = MediaQuery.of(context);
          final inset = EdgeInsets.only(top: statusBarHeight);
          return MediaQuery(
            data: data.copyWith(padding: inset, viewPadding: inset),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapAndSettle(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byKey(_navBar)).selectedIndex;

void main() {
  setUp(() {
    _ProductsRoot.initCount = 0;
  });

  testWidgets('shows the four destinations, in contract order, with keys', (
    tester,
  ) async {
    await _pumpShell(tester);

    for (final key in [_navProducts, _navContent, _navStories, _navAnalytics]) {
      expect(find.byKey(key), findsOneWidget);
    }
    for (final label in ['Products', 'Posts/Reels', 'Stories', 'Analytics']) {
      expect(find.text(label), findsOneWidget);
    }

    final xs = [
      for (final key in [_navProducts, _navContent, _navStories, _navAnalytics])
        tester.getCenter(find.byKey(key)).dx,
    ];
    expect(xs, [...xs]..sort(), reason: 'destinations must be in index order');
    expect(xs.toSet().length, 4);

    expect(
      tester.widget<NavigationBar>(find.byKey(_navBar)).destinations,
      hasLength(4),
    );
    expect(_selectedIndex(tester), 0);
    expect(find.byKey(const Key('page-products')), findsOneWidget);
  });

  testWidgets('tapping each destination shows the matching page', (
    tester,
  ) async {
    await _pumpShell(tester);

    await _tapAndSettle(tester, _navContent);
    expect(find.byKey(const Key('page-content')), findsOneWidget);
    expect(find.byKey(const Key('page-products')), findsNothing);
    expect(_selectedIndex(tester), 1);

    await _tapAndSettle(tester, _navStories);
    expect(find.byKey(const Key('page-stories')), findsOneWidget);
    expect(find.byKey(const Key('page-content')), findsNothing);
    expect(_selectedIndex(tester), 2);

    await _tapAndSettle(tester, _navAnalytics);
    expect(find.byKey(const Key('page-analytics')), findsOneWidget);
    expect(find.byKey(const Key('page-stories')), findsNothing);
    expect(_selectedIndex(tester), 3);

    await _tapAndSettle(tester, _navProducts);
    expect(find.byKey(const Key('page-products')), findsOneWidget);
    expect(find.byKey(const Key('page-analytics')), findsNothing);
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('switching tabs keeps branch state; re-tapping the current tab '
      'returns to the branch root', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byKey(const Key('open-detail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-products-detail')), findsOneWidget);

    // Away and back: the detail page is still on top of branch 0.
    await _tapAndSettle(tester, _navStories);
    expect(find.byKey(const Key('page-stories')), findsOneWidget);
    await _tapAndSettle(tester, _navProducts);
    expect(find.byKey(const Key('page-products-detail')), findsOneWidget);

    // Re-tapping the tab we are already on pops to the branch root.
    await _tapAndSettle(tester, _navProducts);
    expect(find.byKey(const Key('page-products')), findsOneWidget);
    expect(find.byKey(const Key('page-products-detail')), findsNothing);
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('the upload banner shows above every tab while a task exists', (
    tester,
  ) async {
    final container = await _pumpShell(tester);
    expect(find.byKey(_banner), findsNothing);

    final taskId = container
        .read(storyUploadQueueProvider.notifier)
        .enqueueUpload(_fakeMediaFile());
    await tester.pump();

    for (final entry
        in {
          _navProducts: 'products',
          _navContent: 'content',
          _navStories: 'stories',
          _navAnalytics: 'analytics',
        }.entries) {
      await _tapAndSettle(tester, entry.key);
      expect(find.byKey(Key('page-${entry.value}')), findsOneWidget);
      expect(
        find.byKey(_banner),
        findsOneWidget,
        reason: 'banner must be visible on the ${entry.value} tab',
      );
      expect(
        find.byKey(Key('storyUploadStatusBanner_row_$taskId')),
        findsOneWidget,
      );
      // Banner sits above the page content, not below it.
      expect(
        tester.getTopLeft(find.byKey(_banner)).dy,
        lessThan(tester.getTopLeft(find.byKey(Key('page-${entry.value}'))).dy),
      );
    }

    // Cancelling the only task removes the banner again.
    container.read(storyUploadQueueProvider.notifier).cancel(taskId);
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('the shell itself adds no AppBar', (tester) async {
    final container = await _pumpShell(tester);

    expect(find.byType(AppBar), findsNothing);
    await _tapAndSettle(tester, _navStories);
    expect(find.byType(AppBar), findsNothing);

    // Not even while the upload banner is showing.
    container
        .read(storyUploadQueueProvider.notifier)
        .enqueueUpload(_fakeMediaFile());
    await tester.pump();
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
    'status bar inset is applied once: by the banner while it is shown, '
    'by the tab otherwise',
    (tester) async {
      final container = await _pumpShell(tester, statusBarHeight: 24);

      String inset() =>
          tester.widget<Text>(find.byKey(const Key('inset-probe'))).data!;

      // No banner: nothing consumed the inset, the tab sees it.
      expect(inset(), 'inset:24.0');

      final taskId = container
          .read(storyUploadQueueProvider.notifier)
          .enqueueUpload(_fakeMediaFile());
      await tester.pump();

      // Banner shown: it sits below the status bar, and the tab is told
      // the inset is already consumed (no double gap under the banner).
      expect(find.byKey(_banner), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(_banner)).dy,
        greaterThanOrEqualTo(24),
      );
      expect(inset(), 'inset:0.0');

      container.read(storyUploadQueueProvider.notifier).cancel(taskId);
      await tester.pump();
      expect(find.byKey(_banner), findsNothing);
      expect(inset(), 'inset:24.0');
    },
  );

  testWidgets('the banner appearing or disappearing never remounts a tab', (
    tester,
  ) async {
    final container = await _pumpShell(tester);
    expect(_ProductsRoot.initCount, 1);

    final taskId = container
        .read(storyUploadQueueProvider.notifier)
        .enqueueUpload(_fakeMediaFile());
    await tester.pump();
    expect(find.byKey(_banner), findsOneWidget);
    expect(_ProductsRoot.initCount, 1);

    container.read(storyUploadQueueProvider.notifier).cancel(taskId);
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
    expect(_ProductsRoot.initCount, 1);
  });
}
