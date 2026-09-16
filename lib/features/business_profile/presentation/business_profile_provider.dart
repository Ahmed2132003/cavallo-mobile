import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_profile_repository_impl.dart';
import '../domain/business_profile_entity.dart';
import '../domain/business_profile_repository.dart';

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
///   surfaced as an error. Part P-028C's router guard/onboarding screen
///   should treat this as "route to onboarding," not as a failure.
/// * `AsyncData(BusinessProfile(...))` — a profile exists.
/// * `AsyncError` — a genuine failure fetching the profile (network,
///   5xx, an actual `ApiFailure` other than the special-cased 404 — see
///   `BusinessProfileRepositoryImpl`'s module docstring), distinct from
///   "no profile yet."
///
/// ### Part P-028B addition — `createProfile()`
///
/// P-028A's own scope bullet for this file said exactly one thing:
/// "fetches on build()." Its own handoff note to this part was explicit
/// that adding the onboarding/create flow here — not redesigning
/// `build()` — is Part P-028B's job: "P-028B should ADD to this class
/// (new methods calling
/// `ref.read(businessProfileRepositoryProvider)` and updating `state`),
/// never redesign or replace `build()` itself." [createProfile] below is
/// exactly that addition, and mirrors `SessionNotifier.login`'s exact
/// loading → data/rethrow convention (Part P-021a) rather than
/// inventing a new one:
/// * `state` is set to [AsyncValue.loading] the instant the call starts.
/// * On success, `state` becomes `AsyncData` holding the newly created
///   [BusinessProfile] — so anything watching [businessProfileProvider]
///   (a future router guard, Part P-028C) reacts immediately, with no
///   extra re-fetch needed.
/// * On failure, `state` becomes [AsyncError] **and** the original
///   exception is rethrown to the caller — so
///   `BusinessOnboardingScreen` (Part P-028B) can both react to `state`
///   reactively and catch the thrown `ApiFailure` (Part P-004) directly
///   for inline, per-field form errors (a `ValidationFailure`'s
///   `fields['phone_number']`, etc.) — exactly how `RegisterScreen`
///   already uses `SessionNotifier.register`/`login` (Part P-021c).
///
/// ### Part P-028C2 addition — `updateProfile()` / `refreshProfile()`
///
/// P-028A's and P-028B's handoff notes both deferred the edit flow to
/// "Part P-028C" ("using `Patchable` for the clearable fields, exactly
/// as `BusinessProfileRepository.updateProfile`'s own interface already
/// expects"). The original P-028C spec was later split in two: P-028C1
/// took the router gate, and this — the edit screen's own
/// provider-level flow — is Part P-028C2's job. [updateProfile] below is
/// that addition, and follows [createProfile]'s exact convention (which
/// itself mirrors `SessionNotifier.login`, Part P-021a) rather than
/// inventing a second one: `AsyncValue.loading()` synchronously, then
/// `AsyncData(updatedProfile)` on success, or `AsyncError` **plus** a
/// rethrow of the original exception on failure so
/// `BusinessProfileEditScreen` can map a `ValidationFailure`'s
/// `fields` onto its own form fields inline.
///
/// [refreshProfile] re-runs the same `GET /api/v1/businesses/me/` call
/// `build()` makes, without rebuilding the notifier — the "perform a
/// fresh fetch and confirm the change persisted" half of Part P-028C2's
/// own acceptance criteria, and the retry action for the [AsyncError]
/// state on the edit screen. It deliberately does **not** use
/// `ref.invalidateSelf()`: this provider is NOT `.autoDispose` (see
/// [businessProfileProvider]'s own note below) and is subscribed to by
/// `app_router.dart`'s `_SessionRefreshListenable` (Part P-028C1), so
/// invalidating it would tear down and rebuild the exact notifier
/// instance that listener is bridged to. Re-running the fetch and
/// assigning `state` keeps one stable notifier for the app's lifetime,
/// which is what the router gate's subscription assumes.
class BusinessProfileNotifier extends AsyncNotifier<BusinessProfile?> {
  @override
  Future<BusinessProfile?> build() {
    return ref.watch(businessProfileRepositoryProvider).fetchMyProfile();
  }

  /// Calls `BusinessProfileRepository.createProfile` — the onboarding
  /// "create my profile for the first time" call (`POST
  /// /api/v1/businesses/me/`, Part P-026) — and transitions [state] to
  /// the result. See this class's docstring for the exact
  /// loading/success/failure contract.
  ///
  /// Parameters mirror `BusinessProfileRepository.createProfile`
  /// exactly: [businessName]/[businessType]/[country]/[city] are
  /// required by the backend; [description]/[categoryId]/[phoneNumber]
  /// are optional and omitted from the request body entirely when left
  /// `null` (see `BusinessProfileRepositoryImpl`'s own docstring).
  Future<void> createProfile({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  }) async {
    state = const AsyncValue<BusinessProfile?>.loading();
    try {
      final profile = await ref
          .read(businessProfileRepositoryProvider)
          .createProfile(
            businessName: businessName,
            businessType: businessType,
            country: country,
            city: city,
            description: description,
            categoryId: categoryId,
            phoneNumber: phoneNumber,
          );
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Calls `BusinessProfileRepository.updateProfile` — the edit-screen
  /// "change my existing profile" call (`PATCH /api/v1/businesses/me/`,
  /// Part P-026) — and transitions [state] to the result. See this
  /// class's docstring for the exact loading/success/failure contract
  /// (identical to [createProfile]'s).
  ///
  /// Parameters mirror `BusinessProfileRepository.updateProfile`
  /// **exactly**, including its `Patchable` tri-state for the three
  /// nullable-on-the-backend fields — this method deliberately does not
  /// flatten them into plain nullables, which would silently lose the
  /// "explicitly clear this field" case the interface was built to
  /// express (see `business_profile_repository.dart`'s own docstring).
  ///
  /// The `AsyncData` assigned on success holds the **backend's own
  /// response body**, not a locally-patched copy of the previous
  /// profile: the backend normalizes values on write (most visibly
  /// `phone_number` → E.164, Part P-027), so anything reading
  /// [businessProfileProvider] straight after a successful PATCH sees
  /// exactly what a fresh `GET` would return, not this app's guess at
  /// it. That's what makes the router gate (Part P-028C1) and the edit
  /// screen's own pre-filled fields agree with the server without an
  /// extra round trip.
  Future<void> updateProfile({
    String? businessName,
    BusinessType? businessType,
    String? country,
    String? city,
    Patchable<String> description = const Patchable.unset(),
    Patchable<int> categoryId = const Patchable.unset(),
    Patchable<String> phoneNumber = const Patchable.unset(),
  }) async {
    state = const AsyncValue<BusinessProfile?>.loading();
    try {
      final profile = await ref
          .read(businessProfileRepositoryProvider)
          .updateProfile(
            businessName: businessName,
            businessType: businessType,
            country: country,
            city: city,
            description: description,
            categoryId: categoryId,
            phoneNumber: phoneNumber,
          );
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Re-runs the same `GET /api/v1/businesses/me/` call [build] makes
  /// and assigns the result to [state], without disposing/rebuilding
  /// this notifier (see this class's docstring for why
  /// `ref.invalidateSelf()` is deliberately not used here).
  ///
  /// Unlike [createProfile]/[updateProfile] this never rethrows: a
  /// failed refresh is a non-destructive, retryable condition (the last
  /// known profile is still whatever the previous successful call
  /// returned), so it settles into [AsyncError] via [AsyncValue.guard]
  /// and lets whatever is watching decide how to present a retry. A 404
  /// still maps to `AsyncData(null)` exactly as in [build] — that
  /// mapping lives in `BusinessProfileRepositoryImpl.fetchMyProfile`,
  /// not here, so "the profile was deleted server-side" correctly
  /// re-arms Part P-028C1's onboarding redirect rather than showing an
  /// error.
  Future<void> refreshProfile() async {
    state = const AsyncValue<BusinessProfile?>.loading();
    state = await AsyncValue.guard<BusinessProfile?>(
      () => ref.read(businessProfileRepositoryProvider).fetchMyProfile(),
    );
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