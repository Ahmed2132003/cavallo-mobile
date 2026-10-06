import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/presentation/saved_list_provider.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import 'saved_test_support.dart';

/// Part P-113 (STEP 3B): the Saved list notifier - paging, unsave in place
/// (optimistic, with rollback) and account changes.

class _Harness {
  _Harness({
    required this.saved,
    required this.social,
    required this.session,
    required this.container,
  });

  final FakeSavedRepository saved;
  final FakeSocialInteractionRepository social;
  final FakeSavedSession session;
  final ProviderContainer container;

  SavedListNotifier get notifier => container.read(savedListProvider.notifier);

  SavedListState get state => container.read(savedListProvider).requireValue;
}

Future<_Harness> _start(List<List<SavedItem>> pages) async {
  final FakeSavedRepository saved = FakeSavedRepository(pages);
  final FakeSocialInteractionRepository social =
      FakeSocialInteractionRepository();
  final FakeSavedSession session = FakeSavedSession(savedTestCustomer);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => session),
      savedRepositoryProvider.overrideWithValue(saved),
      socialInteractionRepositoryProvider.overrideWithValue(social),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose: keep the provider alive for the whole test.
  final ProviderSubscription<AsyncValue<SavedListState>> sub = container
      .listen(savedListProvider, (previous, next) {});
  addTearDown(sub.close);
  await container.read(savedListProvider.future);
  return _Harness(
    saved: saved,
    social: social,
    session: session,
    container: container,
  );
}

void main() {
  group('first page', () {
    test('loads the first page and filters it per tab', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(3, SavedContentType.product),
          savedTestItem(2, SavedContentType.reel),
          savedTestItem(1, SavedContentType.post),
        ],
      ]);

      expect(h.saved.requestedCursors, <String?>[null]);
      expect(h.state.items, hasLength(3));
      expect(h.state.hasMore, isFalse);
      expect(
        h.state.itemsOf(SavedContentType.post).map((SavedItem i) => i.id),
        <int>[1],
      );
      expect(
        h.state.itemsOf(SavedContentType.reel).map((SavedItem i) => i.id),
        <int>[2],
      );
      expect(
        h.state.itemsOf(SavedContentType.product).map((SavedItem i) => i.id),
        <int>[3],
      );
    });
  });

  group('loadMore', () {
    test('appends the next page, skips known ids and clears the cursor', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(3, SavedContentType.post)],
        <SavedItem>[
          savedTestItem(3, SavedContentType.post), // already loaded
          savedTestItem(2, SavedContentType.reel),
        ],
      ]);
      expect(h.state.hasMore, isTrue);

      await h.notifier.loadMore();

      expect(h.saved.requestedCursors, <String?>[null, '1']);
      expect(h.state.items.map((SavedItem i) => i.id), <int>[3, 2]);
      expect(h.state.hasMore, isFalse);
      expect(h.state.isLoadingMore, isFalse);
    });

    test('does nothing when there is no next page', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);

      await h.notifier.loadMore();

      expect(h.saved.requestedCursors, <String?>[null]);
    });

    test('a failure keeps the items, flags it and rethrows; retry works', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(2, SavedContentType.post)],
        <SavedItem>[savedTestItem(1, SavedContentType.reel)],
      ]);
      h.saved.failNext = StateError('boom');

      await expectLater(h.notifier.loadMore(), throwsA(isA<StateError>()));

      expect(h.state.items.map((SavedItem i) => i.id), <int>[2]);
      expect(h.state.loadMoreFailed, isTrue);
      expect(h.state.isLoadingMore, isFalse);
      expect(h.state.hasMore, isTrue);

      await h.notifier.loadMore();

      expect(h.state.items.map((SavedItem i) => i.id), <int>[2, 1]);
      expect(h.state.loadMoreFailed, isFalse);
      expect(h.state.hasMore, isFalse);
    });
  });

  group('unsave', () {
    test('removes the item at once, then calls the existing unsave API', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(2, SavedContentType.product, objectId: 77),
          savedTestItem(1, SavedContentType.post, objectId: 55),
        ],
      ]);
      h.social.hold = Completer<void>();

      final Future<void> pending = h.notifier.unsave(h.state.items.first);

      // Optimistic: gone before the server answered.
      expect(h.state.items.map((SavedItem i) => i.id), <int>[1]);
      await Future<void>.delayed(Duration.zero);
      expect(h.social.unsaved, hasLength(1));
      expect(h.social.unsaved.single.contentType, 'product');
      expect(h.social.unsaved.single.objectId, 77);

      h.social.hold!.complete();
      await pending;
      expect(h.state.items.map((SavedItem i) => i.id), <int>[1]);
    });

    test('a failed unsave puts the item back at its old position', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(3, SavedContentType.post),
          savedTestItem(2, SavedContentType.post),
          savedTestItem(1, SavedContentType.post),
        ],
      ]);
      h.social.fail = true;
      final SavedItem middle = h.state.items[1];

      await expectLater(h.notifier.unsave(middle), throwsA(isA<StateError>()));

      expect(h.state.items.map((SavedItem i) => i.id), <int>[3, 2, 1]);
    });

    test('unsaving an item that is not in the list does nothing', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);

      await h.notifier.unsave(savedTestItem(99, SavedContentType.post));

      expect(h.social.unsaved, isEmpty);
      expect(h.state.items, hasLength(1));
    });
  });

  group('refresh', () {
    test('refreshSilently replaces the list and keeps it on failure', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      h.saved.pages
        ..clear()
        ..add(<SavedItem>[
          savedTestItem(5, SavedContentType.reel),
          savedTestItem(1, SavedContentType.post),
        ]);

      await h.notifier.refreshSilently();
      expect(h.state.items.map((SavedItem i) => i.id), <int>[5, 1]);

      h.saved.failNext = StateError('offline');
      await h.notifier.refreshSilently();
      expect(h.state.items.map((SavedItem i) => i.id), <int>[5, 1]);
    });

    test('refresh settles into an error state instead of throwing', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      h.saved.failNext = StateError('down');

      await h.notifier.refresh();

      expect(h.container.read(savedListProvider).hasError, isTrue);

      await h.notifier.refresh();
      expect(h.container.read(savedListProvider).hasError, isFalse);
      expect(h.state.items, hasLength(1));
    });
  });

  group('account change', () {
    test('another signed-in user gets a freshly loaded list', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      expect(h.saved.requestedCursors, hasLength(1));

      h.session.signInAs(savedTestOtherCustomer);
      await h.container.read(savedListProvider.future);

      expect(h.saved.requestedCursors, hasLength(2));
    });
  });
}
