import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_public_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_ring_widget.dart';

/// Part P-114 STEP 1: the story ring is the shared AppAvatar with the blue
/// gradient ring while unseen and the outline ring once seen.
class _FakeRepository implements StoryPublicRepository {
  _FakeRepository(this.stories);

  final List<PublicStory> stories;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: stories,
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PublicStory _story(int id) => PublicStory(
  id: id,
  businessId: 1,
  mediaUrl: 'https://example.com/story-$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

Widget _host(ProviderContainer container, {ThemeData? theme}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: StoryRingWidget(businessId: 1, businessName: 'Alpha Traders'),
        ),
      ),
    ),
  );
}

ProviderContainer _container(List<PublicStory> stories) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      storyPublicRepositoryProvider.overrideWithValue(_FakeRepository(stories)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('unseen story: gradient ring, name shown', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container(<PublicStory>[_story(101)]);
    container.listen(viewedStoriesProvider(1), (_, __) {});

    await tester.pumpWidget(_host(container));
    await tester.pump();
    await tester.pump();

    expect(find.text('Alpha Traders'), findsOneWidget);
    expect(tester.widget<AppAvatar>(find.byType(AppAvatar)).ring,
        AppAvatarRing.unseen);
  });

  testWidgets('seen story: outline ring', (WidgetTester tester) async {
    final ProviderContainer container = _container(<PublicStory>[_story(101)]);
    container.listen(viewedStoriesProvider(1), (_, __) {});
    container.read(viewedStoriesProvider(1).notifier).state = <int>{101};

    await tester.pumpWidget(_host(container, theme: AppTheme.dark));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<AppAvatar>(find.byType(AppAvatar)).ring,
        AppAvatarRing.seen);
  });

  testWidgets('no stories: draws nothing', (WidgetTester tester) async {
    final ProviderContainer container = _container(<PublicStory>[]);
    container.listen(viewedStoriesProvider(1), (_, __) {});

    await tester.pumpWidget(_host(container));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppAvatar), findsNothing);
    expect(find.text('Alpha Traders'), findsNothing);
  });
}