import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/discover_screen.dart';
import 'package:social_commerce_app/features/feed/domain/feed_item_entity.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';

/// Part P-062 scope (STEP 6 tests). Hand-rolled fakes only, mirroring
/// `home_feed_screen_test.dart`'s (Part P-061) exact convention — no
/// mockito/mocktail anywhere in this project. `_FakeDiscoverRepository`
/// folds BOTH `DiscoverRepository` methods into one fake (unlike
/// `home_feed_screen_test.dart`'s single-method `_FakeFeedRepository`),
/// since `DiscoverScreen` composes both `activeStoryGroupsProvider` and
/// `discoverFeedProvider` — each call is counted separately so the
/// pull-to-refresh group below can assert BOTH were actually re-hit.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository({required this.pages, this.groups = const []});

  /// Keyed by the cursor that should return it (`null` = first page) —
  /// same convention as `home_feed_screen_test.dart`'s `_FakeFeedRepository.pages`.
  final Map<String?, FeedPage> pages;

  List<ActiveStoryGroup> groups;

  int feedCallCount = 0;
  int groupsCallCount = 0;
  final List<String?> cursorsRequested = [];

  /// When set, the first `fetchDiscoverFeed` call blocks on this instead
  /// of resolving — lets a test observe the initial [LoadingIndicator]
  /// deterministically, same purpose as the Home Feed test's own gate.
  Completer<void>? firstCallGate;

  /// When set, every `fetchDiscoverFeed` call throws this instead of
  /// resolving.
  Object? error;

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async {
    groupsCallCount++;
    return groups;
  }

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) async {
    feedCallCount++;
    cursorsRequested.add(cursor);
    if (feedCallCount == 1 && firstCallGate != null) {
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

/// Fixes the bug this replaced version had: `StoryRingWidget` (used
/// inside `StoriesBarWidget`) independently watches `businessStoriesProvider`,
/// which calls the REAL `storyPublicRepositoryProvider` unless it is
/// also overridden here — leaving it un-overridden made the ring hit
/// live HTTP through `dioClientProvider` (blocked/400 under
/// `flutter_test`'s `HttpClient`), so the ring never rendered
/// `businessName` and every assertion on it failed. Copied verbatim
/// from `stories_bar_widget_test.dart` (STEP 4)'s own
/// `_FakeStoryPublicRepository` — same fake, not a new one.
class _FakeStoryPublicRepository implements StoryPublicRepository {
  _FakeStoryPublicRepository(this.storiesByBusiness);

  final Map<int, List<PublicStory>> storiesByBusiness;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: storiesByBusiness[businessId] ?? [],
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PostFeedItem _post(int id, {int businessId = 1}) => PostFeedItem(
  PublicPost(id: id, businessId: businessId, caption: 'Post caption $id'),
);

ReelFeedItem _reel(int id, {int businessId = 1}) => ReelFeedItem(
  PublicReel(id: id, businessId: businessId, caption: 'Reel caption $id'),
);

PublicStory _story(int id, int businessId) => PublicStory(
  id: id,
  businessId: businessId,
  mediaUrl: 'https://cdn.example.com/stories/$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

/// No `GoRouter` in this tree, deliberately — same choice
/// `home_feed_screen_test.dart` makes: nothing in this file taps a
/// `PostCard`/`ReelCard`/story ring (each of those already has its own
/// dedicated navigation test — `stories_bar_widget_test.dart`, STEP 4 —
/// so `context.pushNamed` is never actually invoked here), so a real
/// router is unnecessary scaffolding for what this file covers.
Widget _wrap(
  _FakeDiscoverRepository discoverRepository, {
  Map<int, String> businessNames = const {1: 'Test Business'},
  Map<int, List<PublicStory>> storiesByBusiness = const {},
}) {
  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(discoverRepository),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfilePublicRepository(businessNames),
      ),
      // Required whenever a test's `groups` puts a business in the
      // stories bar — see `_FakeStoryPublicRepository`'s own doc above
      // for why this was the actual bug, not `discoverRepositoryProvider`.
      storyPublicRepositoryProvider.overrideWithValue(
        _FakeStoryPublicRepository(storiesByBusiness),
      ),
    ],
    child: const MaterialApp(home: DiscoverScreen()),
  );
}

/// A tall, narrow surface so `maxScrollExtent` is reliably > 0 for the
/// scroll/refresh groups below — same convention as
/// `home_feed_screen_test.dart`'s own `_useTallSurface`.
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
      final fake = _FakeDiscoverRepository(
        pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
      )..firstCallGate = Completer<void>();

      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.firstCallGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Post caption 1'), findsOneWidget);
    });

    testWidgets(
      'an all-empty Recommended section shows the empty state',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: const FeedPage(items: [], nextCursor: null)},
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Nothing to discover yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a first-load failure shows the error state with a Retry that reloads',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
        )..error = StateError('backend exploded');

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Could not load Discover right now.'), findsOneWidget);
        expect(fake.feedCallCount, 1);

        // "Fix the backend", then retry.
        fake.error = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Post caption 1'), findsOneWidget);
        expect(find.text('Could not load Discover right now.'), findsNothing);
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
        final fake = _FakeDiscoverRepository(
          pages: {
            null: FeedPage(items: page1Items, nextCursor: 'cursor-a'),
            'cursor-a': FeedPage(items: [_post(99)], nextCursor: null),
          },
        );

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
      'pull-to-refresh discards local Recommended state and REPLACES the '
      'list with a fresh first page, rather than appending to it',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {
            null: FeedPage(
              items: [_post(1), _post(2)],
              nextCursor: 'cursor-a',
            ),
          },
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Post caption 1'), findsOneWidget);
        expect(find.text('Post caption 2'), findsOneWidget);

        // The next `fetchDiscoverFeed(cursor: null)` call (triggered by
        // the refresh below) returns a DIFFERENT first page — if
        // refresh() appended instead of replacing, both pages' items
        // would be visible together afterwards.
        fake.pages[null] = FeedPage(items: [_post(7)], nextCursor: null);

        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        expect(find.text('Post caption 7'), findsOneWidget);
        expect(find.text('Post caption 1'), findsNothing);
        expect(find.text('Post caption 2'), findsNothing);
        expect(fake.cursorsRequested, [null, null]);
      },
    );

    testWidgets(
      'pull-to-refresh ALSO re-fetches the stories bar '
      '(activeStoryGroupsProvider is invalidated, not just discoverFeedProvider)',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
          groups: [
            ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
          ],
        );

        await tester.pumpWidget(
          _wrap(
            fake,
            businessNames: {1: 'Test Business', 5: 'Alpha Traders'},
            storiesByBusiness: {
              5: [_story(1, 5)],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Traders'), findsOneWidget);
        expect(fake.groupsCallCount, 1);

        // With the stories bar actually rendering a ring, there are now
        // TWO `ListView`s in the tree: the outer vertical Recommended
        // list (`.first`, an ANCESTOR of everything else on screen —
        // ordinary widget-tree ancestors are found before their
        // descendants) and `StoriesBarWidget`'s own horizontal
        // `ListView.separated`. `.first` disambiguates to the outer,
        // vertical one — the one `RefreshIndicator` actually wraps.
        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(fake.groupsCallCount, 2);
        // The business still has an active story after the "refresh",
        // so its ring is still there — this asserts the invalidate
        // actually re-ran the fetch, not merely that nothing crashed.
        expect(find.text('Alpha Traders'), findsOneWidget);
      },
    );
  });

  group('mixed content', () {
    testWidgets('renders both post and reel items via PostCard/ReelCard', (
      tester,
    ) async {
      _useTallSurface(tester);

      final fake = _FakeDiscoverRepository(
        pages: {
          null: FeedPage(items: [_post(1), _reel(2)], nextCursor: null),
        },
      );

      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('Post caption 1'), findsOneWidget);
      expect(find.text('Reel caption 2'), findsOneWidget);
    });
  });

  group('composition with the stories bar', () {
    testWidgets(
      'the stories bar renders above the Recommended section, both from '
      'the same screen',
      (tester) async {
        _useTallSurface(tester);

        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
          groups: [
            ActiveStoryGroup(businessId: 5, stories: [_story(1, 5)]),
          ],
        );

        await tester.pumpWidget(
          _wrap(
            fake,
            businessNames: {1: 'Test Business', 5: 'Alpha Traders'},
            storiesByBusiness: {
              5: [_story(1, 5)],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Traders'), findsOneWidget);
        expect(find.text('Post caption 1'), findsOneWidget);
      },
    );

    testWidgets(
      'no active story groups -> the bar renders nothing, but the '
      'Recommended section still renders normally',
      (tester) async {
        final fake = _FakeDiscoverRepository(
          pages: {null: FeedPage(items: [_post(1)], nextCursor: null)},
        );

        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.byType(CircleAvatar), findsNothing);
        expect(find.text('Post caption 1'), findsOneWidget);
      },
    );
  });
}