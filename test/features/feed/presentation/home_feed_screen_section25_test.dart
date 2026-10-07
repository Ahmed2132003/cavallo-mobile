import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/feed/data/feed_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_repository.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';

/// Part P-097 (STEP 2) scope: the dedicated Architecture Section 25
/// closing pass for `HomeFeedScreen` - infinite scroll and pull-to-refresh.
///
/// `home_feed_screen_test.dart` (P-061) already has one infinite-scroll
/// test (a huge fling, which cannot show WHERE `loadMore()` fires) and one
/// pull-to-refresh test (replace, not append). This file adds only:
///
///  - loadMore() does NOT fire below the 80% threshold and DOES fire above it
///  - no extra request once `nextCursor` is null
///  - repeated scrolling while a page is in flight sends ONE request, the
///    bottom spinner shows, and the already-loaded items stay on screen
///  - refresh resets the cursor too (the next loadMore uses the NEW cursor)
///  - a failed refresh shows the error state and Retry recovers
///
/// Hand-rolled fakes only (no mockito), same as P-061's own file.
class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this.pages);

  /// Keyed by the cursor that should return it (`null` = first page).
  final Map<String?, FeedPage> pages;

  /// Optional per-cursor gate: when present the call waits on it, so a
  /// test can observe the "load more in flight" state deterministically.
  final Map<String?, Completer<FeedPage>> gates = {};

  final List<String?> cursorsRequested = [];

  /// When set, every call throws this instead of resolving.
  Object? error;

  @override
  Future<FeedPage> fetchHomeFeed({String? cursor}) async {
    cursorsRequested.add(cursor);
    final gate = gates[cursor];
    if (gate != null) {
      return gate.future;
    }
    if (error != null) {
      throw error!;
    }
    final page = pages[cursor];
    if (page == null) {
      throw StateError('Unexpected cursor requested: $cursor');
    }
    return page;
  }
}

class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    return BusinessProfile(
      id: id,
      businessName: 'Test Business',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

class _FakeSessionNotifier extends SessionNotifier {
  @override
  Future<User?> build() async => null;
}

PostFeedItem _post(int id) => PostFeedItem(
  PublicPost(id: id, businessId: 1, caption: 'Post caption $id'),
);

/// Ten posts with consecutive ids starting at [startId] - tall enough that
/// the list scrolls on the 400x800 test surface.
List<FeedItem> _posts(int startId, {int count = 10}) =>
    List.generate(count, (i) => _post(startId + i));

Widget _wrap(_FakeFeedRepository feedRepository) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(feedRepository),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(),
      ),
      sessionProvider.overrideWith(() => _FakeSessionNotifier()),
    ],
    child: const MaterialApp(home: HomeFeedScreen()),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The feed list's real scroll position (the screen's own
/// `ScrollController` is private, so tests read it through the widget tree).
ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  group('HomeFeedScreen (Section 25) - infinite scroll', () {
    testWidgets(
      'loadMore() does not fire below 80% of the extent and does fire above it',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: _posts(1), nextCursor: 'cursor-a'),
          'cursor-a': FeedPage(items: [_post(99)], nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        var position = _position(tester);
        expect(position.maxScrollExtent, greaterThan(0));

        // Halfway down: well below the 80% threshold.
        position.jumpTo(position.maxScrollExtent * 0.5);
        await tester.pump();
        await tester.pump();

        position = _position(tester);
        expect(position.pixels / position.maxScrollExtent, lessThan(0.8));
        expect(fake.cursorsRequested, [null]);

        // Past 80%: the next page is requested, with the cursor from page 1.
        position.jumpTo(position.maxScrollExtent * 0.9);
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, 'cursor-a']);

        // And the appended item really is reachable at the bottom.
        position = _position(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        expect(find.text('Post caption 99'), findsOneWidget);
        expect(fake.cursorsRequested, [null, 'cursor-a']);
      },
    );

    testWidgets(
      'scrolling to the bottom when nextCursor is null sends no extra request',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: _posts(1), nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        var position = _position(tester);
        expect(position.maxScrollExtent, greaterThan(0));

        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        position = _position(tester);
        position.jumpTo(position.maxScrollExtent - 100);
        await tester.pump();
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null]);
      },
    );

    testWidgets(
      'repeated scrolling while a page is in flight sends ONE request, '
      'shows the bottom spinner, and keeps the loaded items on screen',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: _posts(1), nextCursor: 'cursor-a'),
        });
        final gate = Completer<FeedPage>();
        fake.gates['cursor-a'] = gate;

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        var position = _position(tester);
        position.jumpTo(position.maxScrollExtent * 0.9);
        await tester.pump();
        await tester.pump();
        expect(fake.cursorsRequested, [null, 'cursor-a']);

        // Bring the bottom of the list (where the spinner row lives) on screen.
        position = _position(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        // Part P-114 STEP 2: the bottom row is a skeleton card, not a spinner.
        expect(
          find.byKey(const ValueKey<String>('home_feed_loading_more')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Not a full-screen reload: page 1's last item is still there.
        expect(find.text('Post caption 10'), findsOneWidget);

        // Keep scrolling around the bottom while the request is pending.
        for (var i = 0; i < 3; i++) {
          position = _position(tester);
          position.jumpTo(position.maxScrollExtent - 100);
          await tester.pump();
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
        }
        expect(fake.cursorsRequested, [null, 'cursor-a']);

        // The page arrives: spinner goes away, item is appended, still ONE request.
        gate.complete(FeedPage(items: [_post(99)], nextCursor: null));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('home_feed_loading_more')),
          findsNothing,
        );
        position = _position(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        expect(find.text('Post caption 99'), findsOneWidget);
        expect(fake.cursorsRequested, [null, 'cursor-a']);
      },
    );
  });

  group('HomeFeedScreen (Section 25) - pull to refresh', () {
    testWidgets(
      'refresh after a loadMore resets the cursor: the next page request '
      'uses the NEW cursor, never the old one',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: _posts(1), nextCursor: 'cursor-a'),
          'cursor-a': FeedPage(items: [_post(99)], nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        // Load page 2 by scrolling past the threshold.
        var position = _position(tester);
        position.jumpTo(position.maxScrollExtent * 0.9);
        await tester.pumpAndSettle();
        expect(fake.cursorsRequested, [null, 'cursor-a']);

        // The server now returns a DIFFERENT first page with a NEW cursor.
        fake.pages[null] = FeedPage(
          items: _posts(201),
          nextCursor: 'cursor-b',
        );
        fake.pages['cursor-b'] = FeedPage(items: [_post(299)], nextCursor: null);

        // Back to the top, then pull down to refresh.
        position = _position(tester);
        position.jumpTo(0);
        await tester.pump();
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        // Replaced, not appended: nothing from the old pages survives.
        expect(find.text('Post caption 201'), findsOneWidget);
        expect(find.text('Post caption 1'), findsNothing);
        expect(find.text('Post caption 99'), findsNothing);
        expect(fake.cursorsRequested, [null, 'cursor-a', null]);

        // Scrolling again follows the NEW cursor chain.
        position = _position(tester);
        position.jumpTo(position.maxScrollExtent * 0.9);
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, 'cursor-a', null, 'cursor-b']);
      },
    );

    testWidgets(
      'a failed refresh shows the error state, and Retry loads a fresh page',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: [_post(1), _post(2)], nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();
        expect(find.text('Post caption 1'), findsOneWidget);

        // The backend breaks, then the user pulls to refresh.
        fake.error = StateError('backend exploded');
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        expect(find.text('Could not load your feed.'), findsOneWidget);
        expect(find.text('Post caption 1'), findsNothing);
        expect(fake.cursorsRequested, [null, null]);

        // The backend recovers; Retry rebuilds the feed from scratch.
        fake.error = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Post caption 1'), findsOneWidget);
        expect(find.text('Could not load your feed.'), findsNothing);
        expect(fake.cursorsRequested, [null, null, null]);
      },
    );
  });
}
