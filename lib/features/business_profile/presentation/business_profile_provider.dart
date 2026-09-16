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
/// `updateProfile` (the edit-screen flow) is deliberately **not** added
/// here — that stays Part P-028C's job, per the same handoff note.
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