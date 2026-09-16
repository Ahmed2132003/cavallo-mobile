import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_profile_repository_impl.dart';
import '../domain/business_profile_entity.dart';

/// Part P-028A scope: `businessProfileProvider` — the single source of
/// truth for "does the signed-in Business account have a profile yet,
/// and what's in it." Plain, non-code-gen Riverpod (`AsyncNotifier`, no
/// `@riverpod`), confirmed against the real `pubspec.yaml`
/// (`flutter_riverpod: 3.3.2`, no `riverpod_generator`/
/// `riverpod_annotation`) before writing this file, not assumed — same
/// check `SessionNotifier` (Part P-021a) made before choosing the same
/// approach.
///
/// State is `AsyncValue<BusinessProfile?>`:
/// * `AsyncData(null)` — confirmed no profile yet (a backend 404 on
///   `GET /api/v1/businesses/me/`, mapped to `null` by
///   `BusinessProfileRepositoryImpl.fetchMyProfile()`). This is a valid,
///   expected state per the part spec's own scope note — the Business
///   account exists but hasn't completed onboarding — and is never
///   surfaced as an error. Part P-028B's router guard/onboarding screen
///   should treat this as "route to onboarding," not as a failure.
/// * `AsyncData(BusinessProfile(...))` — a profile exists.
/// * `AsyncError` — a genuine failure fetching the profile (network,
///   5xx, an actual `ApiFailure` other than the special-cased 404 — see
///   `BusinessProfileRepositoryImpl`'s module docstring), distinct from
///   "no profile yet."
///
/// ### Scope note — what this file deliberately does NOT include yet
///
/// The part spec's own "Scope" bullet for this file says exactly one
/// thing: "fetches on build()." `BusinessProfileRepository` (this
/// part's data layer) already exposes `createProfile`/`updateProfile`
/// for the onboarding/edit flow, but wiring those into this notifier's
/// `state` (so a screen can call e.g. `ref.read(businessProfileProvider.
/// notifier).createProfile(...)` and see `state` update reactively) is
/// exactly the "onboarding screen and its POST/create flow" the
/// EXECUTION PROMPT's HANDOFF TO P-028B note explicitly assigns to that
/// next part. Adding those methods here now — beyond what this part's
/// own scope bullet asks for — would be the same kind of
/// scope-creep this project's own convention repeatedly flags rather
/// than silently does (see e.g. `AuthRepository`'s and
/// `SessionNotifier`'s own module docstrings). P-028B should ADD to this
/// class (new methods calling `ref.read(businessProfileRepositoryProvider)`
/// and updating `state`), never redesign or replace `build()` itself,
/// per the handoff note's own instruction.
class BusinessProfileNotifier extends AsyncNotifier<BusinessProfile?> {
  @override
  Future<BusinessProfile?> build() {
    return ref.watch(businessProfileRepositoryProvider).fetchMyProfile();
  }
}

/// Exposes [BusinessProfileNotifier] to the rest of the app, per this
/// project's established Riverpod pattern (`sessionProvider`,
/// `authRepositoryProvider`) — a plain `AsyncNotifierProvider`, no
/// code-gen. NOT `.autoDispose`: a signed-in Business account's own
/// profile is meant to live for the session, the same lifetime rule
/// `sessionProvider` itself follows (architecture Section 13), so it
/// isn't silently disposed and re-fetched between screens.
final businessProfileProvider =
    AsyncNotifierProvider<BusinessProfileNotifier, BusinessProfile?>(
      BusinessProfileNotifier.new,
    );
