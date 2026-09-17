import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_profile_public_repository.dart';
import '../domain/business_profile_entity.dart';

/// Part P-029 scope: the public, by-id business profile a Customer sees
/// at `/business/:id`.
///
/// ### The three states this provider can settle into
///
/// * `AsyncLoading` — the request is in flight (screen shows
///   `LoadingIndicator`, Part P-006).
/// * `AsyncData(non-null)` — the business exists; render the header.
/// * `AsyncData(null)` — the backend returned 404: this business
///   genuinely does not exist. A real, renderable state, NOT an error —
///   the screen must show a "business not found" empty state, distinct
///   from the generic error state, per this part's own acceptance
///   criteria. The `null` originates in
///   `BusinessProfilePublicRepositoryImpl.fetchPublicProfile`, which is
///   the only place a 404 is interpreted (see that file's docstring for
///   why `core/network` can't do it).
/// * `AsyncError` — a genuine failure (no connectivity, 5xx, an
///   unexpected payload). Screen shows `ErrorStateWidget` with a Retry
///   action.
///
/// This mirrors `businessProfileProvider`'s (Part P-028A) own
/// "AsyncData(null) is a state, not an error" contract exactly, so both
/// halves of this feature behave the same way for the same reason.
///
/// ### Why `FutureProvider` and not an `AsyncNotifier` like P-028A's
///
/// `BusinessProfileNotifier` (Part P-028A/C2) is an `AsyncNotifier`
/// because it owns mutations: `createProfile`, `updateProfile`,
/// `refreshProfile`. This screen is read-only forever — the backend view
/// is a DRF `RetrieveAPIView` with no write verbs at all — so there is
/// no method to put on a notifier. Retry is expressed as
/// `ref.invalidate(businessProfilePublicProvider(id))`, which re-runs
/// the fetch below. Adding an otherwise-empty notifier class purely for
/// symmetry with P-028A would be structure without behavior.
///
/// ### Why `autoDispose`
///
/// Unlike every other Riverpod provider in this project so far, this one
/// is a family keyed by business id: browsing 50 businesses would
/// otherwise keep 50 cached profiles (and their fetch results) alive for
/// the whole app session, with no eviction. `autoDispose` drops each
/// one once no screen is watching it, which for a discovery feed is the
/// correct default. Flagged rather than silently chosen, since it IS a
/// deviation from this project's other providers — they're all
/// singletons, where the same reasoning doesn't apply.
///
/// ### Why automatic retry is disabled
///
/// Riverpod 3.x retries a failed provider `build()` on its own, with
/// real exponential backoff (up to seconds per attempt) — the exact
/// behavior that hung `session_provider_test` for its full timeout
/// during Part P-028's closure (documented in `PROJECT_PROGRESS.md`).
/// This screen already gives the user an explicit Retry button, so a
/// hidden background retry only delays the visible error state and adds
/// pending timers that widget tests then have to wait out. `retry`
/// returning `null` means "never retry automatically" — failures settle
/// into `AsyncError` immediately and stay there until the user (or a
/// test) invalidates the provider.
///
/// ### Argument type
///
/// The family argument is an `int`, not the raw `:id` `String` from the
/// route: the backend route is `<int:pk>/` (`businesses/urls.py`), so a
/// non-numeric id can never resolve to a business at all. Parsing
/// happens once, in the screen, before this provider is ever read — see
/// `business_profile_public_screen.dart` (Part P-029).
final businessProfilePublicProvider = FutureProvider.autoDispose
    .family<BusinessProfile?, int>((ref, id) {
      return ref
          .watch(businessProfilePublicRepositoryProvider)
          .fetchPublicProfile(id);
    }, retry: (retryCount, error) => null);
