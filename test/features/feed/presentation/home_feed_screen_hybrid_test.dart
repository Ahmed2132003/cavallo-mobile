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
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/feed/data/feed_repository.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_repository.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_feed_screen.dart';

/// Part P-097 (STEP 3) scope: the hybrid-algorithm UI-consumption test for
/// `HomeFeedScreen` (Architecture Section 25).
///
/// The backend (P-059 `get_home_feed()`) returns ONE ordered list: the
/// followed tier first (newest first), then the backfill tier (featured
/// businesses first, then newest). Items carry NO tier marker, so the UI
/// has nothing to sort or filter on - its only job is to render the list
/// exactly as given. These tests fail if anything in the widget layer
/// re-sorts (by id, by type, by business), drops an item, or de-duplicates
/// two items from the same business.
///
/// The fixture is deliberately "unsorted by every key the UI could reach":
/// ids are not monotonic, posts and reels are interleaved, and business 1
/// appears twice. Business 5 has NO public profile (lookup returns null),
/// to prove a failed name lookup never removes a row.
class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this.pages);

  final Map<String?, FeedPage> pages;
  final List<String?> cursorsRequested = [];

  @override
  Future<FeedPage> fetchHomeFeed({String? cursor}) async {
    cursorsRequested.add(cursor);
    final page = pages[cursor];
    if (page == null) {
      throw StateError('Unexpected cursor requested: $cursor');
    }
    return page;
  }
}

class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  /// Business ids that HAVE a public profile. Anything else resolves to null.
  static const _known = {1, 2, 3, 4};

  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    if (!_known.contains(id)) return null;
    return BusinessProfile(
      id: id,
      businessName: 'Business $id',
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

PostFeedItem _post(int id, int businessId) => PostFeedItem(
  PublicPost(id: id, businessId: businessId, caption: 'Post caption $id'),
);

ReelFeedItem _reel(int id, int businessId) => ReelFeedItem(
  PublicReel(id: id, businessId: businessId, caption: 'Reel caption $id'),
);

// ---- Followed tier (businesses the user follows), newest first. ----
final _followedTier = <FeedItem>[
  _post(30, 1),
  _reel(12, 2),
  _post(5, 1), // business 1 again: must NOT be de-duplicated
];

// ---- Backfill tier: featured business first, then the rest. ----
final _backfillTier = <FeedItem>[
  _reel(77, 3), // featured
  _post(61, 3),
  _post(20, 4),
  _reel(3, 5), // business 5 has no public profile
];

/// The exact captions, in the exact order the backend returned them.
const _expectedOrder = <String>[
  'Post caption 30',
  'Reel caption 12',
  'Post caption 5',
  'Reel caption 77',
  'Post caption 61',
  'Post caption 20',
  'Reel caption 3',
];

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

/// Very tall surface so EVERY row is laid out at once (a lazy ListView would
/// otherwise only build the rows near the viewport and hide ordering bugs).
void _useVeryTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Asserts every caption is on screen exactly once, and that each one sits
/// strictly below the previous one (i.e. the on-screen order is [captions]).
void _expectRenderedInOrder(WidgetTester tester, List<String> captions) {
  final tops = <double>[];
  for (final caption in captions) {
    expect(
      find.text(caption),
      findsOneWidget,
      reason: '"$caption" should be rendered exactly once',
    );
    tops.add(tester.getTopLeft(find.text(caption)).dy);
  }
  for (var i = 1; i < tops.length; i++) {
    expect(
      tops[i],
      greaterThan(tops[i - 1]),
      reason: '"${captions[i]}" should be rendered below "${captions[i - 1]}"',
    );
  }
}

void main() {
  group('HomeFeedScreen (Section 25) - hybrid followed + backfill response', () {
    testWidgets(
      'renders every item of a mixed response in exactly the backend order, '
      'with the right card per item, and no re-sort / re-filter / de-dup',
      (tester) async {
        _useVeryTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(
            items: [..._followedTier, ..._backfillTier],
            nextCursor: null,
          ),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        // One request, no cursor: the UI did not ask for anything extra.
        expect(fake.cursorsRequested, [null]);

        // All 7 items present, in the backend's order. A re-sort by id,
        // by type, or by business would break this.
        _expectRenderedInOrder(tester, _expectedOrder);

        // Right card per item: 4 posts, 3 reels.
        expect(find.byType(PostCard), findsNWidgets(4));
        expect(find.byType(ReelCard), findsNWidgets(3));

        // Business 1 appears twice in the followed tier: both rows survive.
        expect(find.text('Post caption 30'), findsOneWidget);
        expect(find.text('Post caption 5'), findsOneWidget);

        // Business 5 has no public profile: the row is still rendered.
        expect(find.text('Reel caption 3'), findsOneWidget);
      },
    );

    testWidgets(
      'a followed->backfill boundary that falls across two pages is '
      'appended in order, with page 1 left untouched',
      (tester) async {
        _useVeryTallSurface(tester);

        // Page 1: the whole followed tier plus the START of the backfill.
        // Page 2: the rest of the backfill.
        final fake = _FakeFeedRepository({
          null: FeedPage(
            items: [..._followedTier, _backfillTier[0]],
            nextCursor: 'cursor-a',
          ),
          'cursor-a': FeedPage(
            items: _backfillTier.sublist(1),
            nextCursor: null,
          ),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        _expectRenderedInOrder(tester, _expectedOrder.sublist(0, 4));
        expect(find.text('Post caption 61'), findsNothing);

        // Drive loadMore() through the real provider (the 6000px surface
        // cannot scroll, so the scroll listener cannot be the trigger here -
        // that path is covered in the Section 25 infinite-scroll tests).
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeFeedScreen)),
        );
        await container.read(homeFeedProvider.notifier).loadMore();
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, 'cursor-a']);

        // Pages concatenated, nothing re-sorted across the page boundary.
        _expectRenderedInOrder(tester, _expectedOrder);
        expect(find.byType(PostCard), findsNWidgets(4));
        expect(find.byType(ReelCard), findsNWidgets(3));
      },
    );

    testWidgets(
      'a refreshed response in a DIFFERENT mixed order is rendered in the '
      'new backend order (the UI keeps no memory of the old order)',
      (tester) async {
        _useVeryTallSurface(tester);

        final fake = _FakeFeedRepository({
          null: FeedPage(
            items: [..._followedTier, ..._backfillTier],
            nextCursor: null,
          ),
        });

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();
        _expectRenderedInOrder(tester, _expectedOrder);

        // The backend now returns the same items in a different order
        // (e.g. a new followed post landed, the featured reel changed).
        final reordered = [
          _backfillTier[0],
          _followedTier[2],
          _backfillTier[3],
          _followedTier[0],
          _backfillTier[1],
          _followedTier[1],
          _backfillTier[2],
        ];
        fake.pages[null] = FeedPage(items: reordered, nextCursor: null);

        // RefreshIndicator needs a drag of ~25% of the viewport height (about
        // 1500px on this 6000px surface), so drive the same refresh() the
        // indicator calls, through the real provider. The pull gesture itself
        // is covered by the Section 25 pull-to-refresh tests (400x800 surface).
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeFeedScreen)),
        );
        await container.read(homeFeedProvider.notifier).refresh();
        await tester.pumpAndSettle();

        expect(fake.cursorsRequested, [null, null]);
        _expectRenderedInOrder(tester, const [
          'Reel caption 77',
          'Post caption 5',
          'Reel caption 3',
          'Post caption 30',
          'Post caption 61',
          'Reel caption 12',
          'Post caption 20',
        ]);
      },
    );
  });
}
