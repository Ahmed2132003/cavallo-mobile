import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../social/data/social_interaction_repository_impl.dart';
import '../data/saved_repository_impl.dart';
import '../domain/saved_item.dart';

/// Part P-113 (STEP 3B): `savedListProvider` - the Saved screen's list and its
/// pagination position. Plain Riverpod `AsyncNotifier`, same convention as
/// `notificationListProvider` and `homeFeedProvider`.
///
/// ### One list, three tabs
/// `GET /api/v1/saves/me/` has no content-type filter, so the notifier holds
/// ONE mixed, newest-first list and each tab filters it with
/// [SavedListState.itemsOf]. A tab may therefore be short or empty while the
/// server still has more pages; the screen keeps loading pages until the tab
/// has enough rows or the list ends.
///
/// ### Unsave in place
/// [SavedListNotifier.unsave] removes the row immediately, calls the EXISTING
/// `SocialInteractionRepository.unsaveContent` (P-058, idempotent), and puts
/// the row back at its old position if the call fails.
///
/// ### Account changes
/// `build()` watches the signed-in user id, so a different account never sees
/// the previous account's list. The provider is `autoDispose` as well.
class SavedListState {
  const SavedListState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<SavedItem> items;

  /// The `next` URL of the last loaded page, or null when the list has ended.
  final String? nextCursor;

  final bool isLoadingMore;

  /// The last attempt to load another page failed. While true the screen does
  /// not retry on its own (no request loop); the user's retry clears it.
  final bool loadMoreFailed;

  bool get hasMore => nextCursor != null;

  /// The loaded items of one tab, in the server's (newest-first) order.
  List<SavedItem> itemsOf(SavedContentType type) => <SavedItem>[
    for (final SavedItem item in items)
      if (item.contentType == type) item,
  ];

  SavedListState copyWith({
    List<SavedItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return SavedListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

class SavedListNotifier extends AsyncNotifier<SavedListState> {
  @override
  Future<SavedListState> build() async {
    // Wait until the session has settled BEFORE watching it. Otherwise the
    // first build runs while the session is still loading, the id then flips
    // from null to the real id, and the notifier rebuilt and fetched the first
    // page twice. A failed session is not this screen's error to report.
    try {
      await ref.read(sessionProvider.future);
    } catch (_) {
      // Ignored on purpose.
    }

    // A different signed-in account rebuilds this notifier, which drops the
    // old account's list.
    ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value?.id,
          _ => null,
        },
      ),
    );

    final page = await ref.watch(savedRepositoryProvider).listSaved();
    return SavedListState(items: page.results, nextCursor: page.next);
  }

  /// Discards the local list and fetches a genuine fresh first page (the
  /// screen shows its loading state meanwhile). A failure settles into
  /// `AsyncError` without rethrowing, so the screen can offer "Retry".
  Future<void> refresh() async {
    state = const AsyncValue<SavedListState>.loading();
    state = await AsyncValue.guard<SavedListState>(() async {
      final page = await ref.read(savedRepositoryProvider).listSaved();
      return SavedListState(items: page.results, nextCursor: page.next);
    });
  }

  /// Fetches a fresh first page WITHOUT clearing the screen: used for
  /// pull-to-refresh and when the Saved tab is selected again (the user may
  /// have saved something elsewhere meanwhile). On failure the list on screen
  /// is simply kept. When there is no list yet (error state), it falls back
  /// to [refresh].
  Future<void> refreshSilently() async {
    final current = state.value;
    if (current == null) {
      if (state.hasError) {
        await refresh();
      }
      return;
    }
    if (current.isLoadingMore) {
      return;
    }
    try {
      final page = await ref.read(savedRepositoryProvider).listSaved();
      if (!ref.mounted) return;
      state = AsyncData(
        SavedListState(items: page.results, nextCursor: page.next),
      );
    } catch (_) {
      // Keep the list that is already on screen.
    }
  }

  /// Appends the next page. No-op when there is no cursor or a load is
  /// already running. On failure the loaded items are kept, `loadMoreFailed`
  /// is set and the error is rethrown to the caller.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final page = await ref
          .read(savedRepositoryProvider)
          .listSaved(cursor: current.nextCursor);
      if (!ref.mounted) return;

      // Re-read: an unsave may have changed the list while the page loaded.
      final latest = state.value ?? current;
      final knownIds = latest.items.map((SavedItem i) => i.id).toSet();
      state = AsyncData(
        latest.copyWith(
          items: <SavedItem>[
            ...latest.items,
            ...page.results.where((SavedItem i) => !knownIds.contains(i.id)),
          ],
          nextCursor: page.next,
          clearNextCursor: page.next == null,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
      rethrow;
    }
  }

  /// Removes [item] from the list at once, then unsaves it on the server. If
  /// the server call fails the item returns to its old position and the error
  /// is rethrown (the screen shows a SnackBar).
  Future<void> unsave(SavedItem item) async {
    final current = state.value;
    if (current == null) return;
    final int index = current.items.indexWhere(
      (SavedItem i) => i.id == item.id,
    );
    if (index < 0) return;

    state = AsyncData(
      current.copyWith(
        items: <SavedItem>[
          for (final SavedItem i in current.items)
            if (i.id != item.id) i,
        ],
      ),
    );

    try {
      await ref
          .read(socialInteractionRepositoryProvider)
          .unsaveContent(
            contentType: item.contentType.wireValue,
            objectId: item.objectId,
          );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null &&
            !latest.items.any((SavedItem i) => i.id == item.id)) {
          final List<SavedItem> restored = List<SavedItem>.of(latest.items);
          restored.insert(
            index > restored.length ? restored.length : index,
            item,
          );
          state = AsyncData(latest.copyWith(items: restored));
        }
      }
      rethrow;
    }
  }
}

final savedListProvider =
    AsyncNotifierProvider.autoDispose<SavedListNotifier, SavedListState>(
      SavedListNotifier.new,
      retry: (retryCount, error) => null,
    );
