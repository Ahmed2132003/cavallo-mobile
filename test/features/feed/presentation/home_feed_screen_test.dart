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
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/feed/data/feed_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_repository.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';

/// Part P-061 scope (STEP 3 tests). Hand-rolled fakes only — no
/// mockito/mocktail anywhere in this project (confirmed against
/// PROJECT_PROGRESS.md's P-021a note). Mirrors
/// `home_feed_provider_test.dart`'s own `_FakeFeedRepository` shape,
/// plus a minimal `_FakeBusinessProfilePublicRepository` so `PostCard`/
/// `ReelCard` rows have a real (if fake) `businessName` to resolve.
class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this.pages);

  /// Keyed by the cursor that should return it (`null` = first page).
  final Map<String?, FeedPage> pages;
  int callCount = 0;
  final List<String?> cursorsRequested = [];

  /// When set, the first call blocks on this instead of resolving —
  /// lets a test observe the initial [LoadingIndicator] deterministically.
  Completer<void>? firstCallGate;

  /// When set, every call throws this instead of resolving.
  Object? error;

  @override
  Future<FeedPage> fetchHomeFeed({String? cursor}) async {
    callCount++;
    cursorsRequested.add(cursor);
    if (callCount == 1 && firstCallGate != null) {
      await firstCallGate!.future;
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
  _FakeBusinessProfilePublicRepository(this.namesById);

  final Map<int, String> namesById;

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    final name = namesById[id];
    if (name == null) return null;
    return BusinessProfile(
      id: id,
      businessName: name,
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

/// Resolves immediately to a fixed session — same shape as
/// `moderation_router_gate_test.dart`'s own `_FakeSessionNotifier`.
/// `null` (a guest/unauthenticated session) is used throughout this
/// file: the feed itself does not require a signed-in user, and it
/// keeps `_DebugMenu` from ever touching `businessProfileProvider`
/// (Dart's `&&` short-circuit skips that `ref.watch` when
/// `isBusinessUser` is false — see `home_feed_screen.dart`).
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._fixedValue);

  final User? _fixedValue;

  @override
  Future<User?> build() async => _fixedValue;
}

PostFeedItem _post(int id, {int businessId = 1}) => PostFeedItem(
  PublicPost(id: id, businessId: businessId, caption: 'Post caption $id'),
);

ReelFeedItem _reel(int id, {int businessId = 1}) => ReelFeedItem(
  PublicReel(id: id, businessId: businessId, caption: 'Reel caption $id'),
);

Widget _wrap(
  _FakeFeedRepository feedRepository, {
  Map<int, String> businessNames = const {1: 'Test Business'},
}) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(feedRepository),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(businessNames),
      ),
      sessionProvider.overrideWith(() => _FakeSessionNotifier(null)),
    ],
    child: const MaterialApp(home: HomeFeedScreen()),
  );
}

/// A tall, narrow surface so a handful of feed cards are all laid out
/// (and, for the scroll test, so `maxScrollExtent` is reliably > 0)
/// without needing dozens of items. Same convention as
/// `moderation_queue_screen_test.dart`'s `_useTallSurface`.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('loading, empty and error states', () {
    testWidgets('shows a loading indicator while the first page is in flight', (
      tester,
    ) async {
      final fake = _FakeFeedRepository({
        null: FeedPage(items: [_post(1)], nextCursor: null),
      })..firstCallGate = Completer<void>();

      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.firstCallGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Post caption 1'), findsOneWidget);
    });

    testWidgets(
      'an all-empty feed (no follows, empty backfill) shows the empty state',
      (tester) async {
        final fake = _FakeFeedRepository({
          null: const FeedPage(items: [], nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.textContaining('Your feed is empty right now'), findsOneWidget);
      },
    );

    testWidgets(
      'a first-load failure shows the error state with a Retry that reloads',
      (tester) async {
        final fake = _FakeFeedRepository({
          null: FeedPage(items: [_post(1)], nextCursor: null),
        })..error = StateError('backend exploded');

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Could not load your feed.'), findsOneWidget);
        expect(fake.callCount, 1);

        // "Fix the backend", then retry.
        fake.error = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Post caption 1'), findsOneWidget);
        expect(find.text('Could not load your feed.'), findsNothing);
      },
    );
  });

  group('infinite scroll', () {
    testWidgets(
      'scrolling near the bottom of the list triggers loadMore() and '
      'appends the next page',
      (tester) async {
        _useTallSurface(tester);

        final page1Items = List.generate(10, (i) => _post(i + 1));
        final fake = _FakeFeedRepository({
          null: FeedPage(items: page1Items, nextCursor: 'cursor-a'),
          'cursor-a': FeedPage(items: [_post(99)], nextCursor: null),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null]);
        expect(find.text('Post caption 99'), findsNothing);

        // Drag the list well past 80% of its scroll extent.
        await tester.fling(
          find.byType(ListView),
          const Offset(0, -4000),
          3000,
        );
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, 'cursor-a']);
        expect(find.text('Post caption 99'), findsOneWidget);
      },
    );
  });

  group('pull to refresh', () {
    testWidgets(
      'pull-to-refresh discards local state and REPLACES the list with a '
      'fresh first page, rather than appending to it',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(items: [_post(1), _post(2)], nextCursor: 'cursor-a'),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Post caption 1'), findsOneWidget);
        expect(find.text('Post caption 2'), findsOneWidget);

        // The next `fetchHomeFeed(cursor: null)` call (triggered by the
        // refresh below) returns a DIFFERENT first page — if refresh()
        // appended instead of replacing, both pages' items would be
        // visible together afterwards.
        fake.pages[null] = FeedPage(items: [_post(7)], nextCursor: null);

        await tester.fling(
          find.byType(ListView),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(find.text('Post caption 7'), findsOneWidget);
        expect(find.text('Post caption 1'), findsNothing);
        expect(find.text('Post caption 2'), findsNothing);
        expect(fake.cursorsRequested, [null, null]);
      },
    );
  });

  group('mixed content', () {
    testWidgets('renders both post and reel items via PostCard/ReelCard', (
      tester,
    ) async {
      _useTallSurface(tester);

      final fake = _FakeFeedRepository({
        null: FeedPage(
          items: [_post(1), _reel(2)],
          nextCursor: null,
        ),
      });

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('Post caption 1'), findsOneWidget);
      expect(find.text('Reel caption 2'), findsOneWidget);
    });
  });
}