import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moderation_repository_impl.dart';
import '../domain/queue_item_entity.dart';

/// Part P-040 scope: the ordering rule the moderator queue screen shows —
/// `fast_path` items first, then, inside each priority tier, the OLDEST
/// item first (largest [QueueItem.ageDuration]). Ties on age fall back to
/// the lower queue id so the order is fully deterministic (a list that
/// reshuffles between refreshes would make a moderator lose their place).
///
/// This is a presentation rule, not a data-layer one: the backend orders
/// by `-created_at` (newest first) and `ModerationRepository` deliberately
/// returns that order untouched. Returns a NEW list; [items] is not
/// mutated.
List<QueueItem> sortModerationQueue(Iterable<QueueItem> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    if (a.isFastPath != b.isFastPath) {
      return a.isFastPath ? -1 : 1;
    }
    final byAge = b.ageDuration.compareTo(a.ageDuration);
    if (byAge != 0) {
      return byAge;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

/// Part P-040 scope: `moderationQueueProvider` — the single source of
/// truth for "what is waiting for review right now." Plain, non-code-gen
/// Riverpod (`AsyncNotifier`), same convention as `OwnProductsNotifier`
/// and `SessionNotifier`.
///
/// State is `AsyncValue<List<QueueItem>>`: pending items only, already
/// sorted by [sortModerationQueue]. An empty list is a valid, expected
/// state ("queue is clear"), never an error. Only the first page (up to
/// the backend's max of 100 items) is loaded — see
/// `ModerationRepository.fetchQueue`. Approved/rejected items leave the
/// pending list, so refreshing after clearing a batch naturally reveals
/// the next one.
///
/// ### Decision: remove on success, no refetch, no optimistic removal
///
/// [approve]/[reject] call the backend FIRST and only remove the item
/// from local [state] once that call has succeeded. Two alternatives were
/// rejected on purpose:
///   * *Refetching the whole queue after every action* (what
///     `OwnProductsNotifier` does) costs a full 100-item round trip per
///     decision, and a moderator clears items back-to-back — the extra
///     latency and flicker would be felt on every single action.
///   * *Optimistic removal before the response* would make an item
///     vanish even when the action then fails (403, network drop) — for a
///     moderation queue, "I think I approved it but it never happened" is
///     the worst failure mode.
/// Removing locally after a confirmed success is instant for the moderator
/// and never lies about what the backend accepted.
///
/// ### Failure contract (mirrors `OwnProductsNotifier`)
///
/// On failure the original exception (a `DioException` whose `.error` is
/// a typed `ApiFailure`) propagates to the caller — the review screen —
/// and [state] is left exactly as it was, so a failed action never makes
/// the queue vanish. ONE exception to "untouched": a 409 (already
/// decided, e.g. by another moderator) or 404 (row no longer exists)
/// means the item is no longer pending, so it is removed locally too
/// before the error is rethrown — leaving it in the list would only
/// invite the same doomed action again.
///
/// ### Why `autoDispose`, and why retry is disabled
///
/// Unlike a Business account's own product list (session-lived), the
/// moderation queue is live, fast-changing data: re-entering the screen
/// should show a fresh queue, and no moderator's queue contents should
/// linger in memory after they leave the screen or sign out.
/// `autoDispose` gives both. Riverpod 3.x's automatic exponential-backoff
/// retry is disabled (`retry: (retryCount, error) => null`), matching
/// `categoryTreeProvider` and the public product providers: a 403 (the
/// account has `is_moderator` but no `can_moderate_content` permission —
/// see the P-040 gap note) must surface as an error immediately, not sit
/// in a loading state while it silently retries.
class ModerationQueueNotifier extends AsyncNotifier<List<QueueItem>> {
  /// Queue ids with an approve/reject call currently in flight. A second
  /// call for the same id while the first is still running is ignored —
  /// a double-tap must never fire two decisions (the second would just
  /// 409, and a stray error message would confuse the moderator).
  final Set<int> _inFlight = <int>{};

  @override
  Future<List<QueueItem>> build() async {
    final page = await ref.watch(moderationRepositoryProvider).fetchQueue();
    return sortModerationQueue(page.results);
  }

  /// Re-runs the same `GET` [build] makes — the pull-to-refresh action.
  /// Goes through `invalidateSelf`, so the previous list stays visible
  /// (`AsyncValue.isRefreshing`) while the new one loads, instead of the
  /// whole screen flipping to a spinner.
  ///
  /// A failed refresh settles into `AsyncError` in [state] and is NOT
  /// rethrown — it is a non-destructive, retryable read, same reasoning
  /// as `OwnProductsNotifier.refreshProducts`.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Deliberately swallowed: the failure is already in [state] as an
      // AsyncError, which is where the screen reads it from.
    }
  }

  /// Calls `ModerationRepository.approve`, then removes the item from
  /// [state]. See the class docstring for the failure contract.
  Future<void> approve(int queueItemId) async {
    if (!_inFlight.add(queueItemId)) {
      return;
    }
    try {
      await ref.read(moderationRepositoryProvider).approve(queueItemId);
      _removeFromState(queueItemId);
    } on DioException catch (e) {
      if (_isNoLongerPending(e)) {
        _removeFromState(queueItemId);
      }
      rethrow;
    } finally {
      _inFlight.remove(queueItemId);
    }
  }

  /// Calls `ModerationRepository.reject` with the trimmed [reason], then
  /// removes the item from [state]. See the class docstring for the
  /// failure contract.
  ///
  /// A blank [reason] throws [ArgumentError] BEFORE any network call.
  /// The reject UI already keeps its button disabled until a reason is
  /// typed (mirroring the backend's non-blank rule), so reaching this
  /// guard means a programming error, not a user mistake — the backend
  /// stays the real authority either way.
  Future<void> reject(int queueItemId, String reason) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be blank');
    }
    if (!_inFlight.add(queueItemId)) {
      return;
    }
    try {
      await ref
          .read(moderationRepositoryProvider)
          .reject(queueItemId: queueItemId, reason: trimmedReason);
      _removeFromState(queueItemId);
    } on DioException catch (e) {
      if (_isNoLongerPending(e)) {
        _removeFromState(queueItemId);
      }
      rethrow;
    } finally {
      _inFlight.remove(queueItemId);
    }
  }

  void _removeFromState(int queueItemId) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<List<QueueItem>>(
      current.where((item) => item.id != queueItemId).toList(),
    );
  }

  /// 409 = already decided (`ConflictError`), 404 = row no longer exists
  /// (`NotFound`) — both mean the item is not pending anymore. Neither has
  /// a dedicated `ApiFailure` subtype (they arrive as `UnknownFailure`),
  /// so the status code is read from the response, as
  /// `ModerationRepository`'s docstring documents.
  static bool _isNoLongerPending(DioException e) {
    final statusCode = e.response?.statusCode;
    return statusCode == 409 || statusCode == 404;
  }
}

/// Exposes [ModerationQueueNotifier] to the rest of the app. `autoDispose`
/// and retry-disabled on purpose — see [ModerationQueueNotifier]'s
/// docstring.
final moderationQueueProvider =
    AsyncNotifierProvider.autoDispose<ModerationQueueNotifier, List<QueueItem>>(
      ModerationQueueNotifier.new,
      retry: (retryCount, error) => null,
    );