import 'business_profile_entity.dart';

/// Part P-028A scope: the domain-facing contract Part P-028B's
/// onboarding/edit screens (and `BusinessProfileNotifier`, this part's
/// own `presentation/business_profile_provider.dart`) depend on. The
/// implementation (`business_profile_repository_impl.dart`) is the only
/// thing that knows this is backed by HTTP/DTOs — mirrors
/// `AuthRepository`'s exact split (Part P-020).
///
/// All three methods below call the same single endpoint,
/// `/api/v1/businesses/me/` (Part P-026) — there is no
/// `/businesses/{id}/` write path and never a URL/body-supplied id: the
/// backend resolves "my own profile" strictly from `request.user`,
/// IDOR-safe by construction (P-026's own "Template established for
/// future parts" note). This is the "second, business-account-specific
/// gate" the part spec's Architecture Rules describe conceptually — the
/// actual *router* gate reusing P-021's redirect-guard pattern is
/// presentation-layer work for Part P-028B, not this file.
abstract class BusinessProfileRepository {
  /// Calls `GET /api/v1/businesses/me/`.
  ///
  /// Returns `null` on a backend 404 — "the signed-in Business account
  /// hasn't completed onboarding yet" is a valid, expected result of
  /// this call, not an error (per the part spec's own scope note, and
  /// `BusinessProfileNotifier`'s docstring). Any other failure (network,
  /// 5xx, an actual auth problem, etc.) propagates as a [DioException]
  /// with `.error` already a typed `ApiFailure` (Part P-004) — same
  /// convention as [AuthRepository], nothing re-wrapped here except the
  /// 404-to-`null` case.
  Future<BusinessProfile?> fetchMyProfile();

  /// Calls `POST /api/v1/businesses/me/` — creates the signed-in
  /// Business account's profile for the first time (the onboarding
  /// flow). [businessName]/[businessType]/[country]/[city] are required
  /// on the backend; [description]/[categoryId]/[phoneNumber] are
  /// optional and omitted from the request body entirely when left
  /// `null` (rather than sent as an explicit `null`) — matching how a
  /// brand-new profile has nothing to "clear" yet.
  ///
  /// Throws via the underlying `DioException.error` (an `ApiFailure`)
  /// on failure — e.g. a `ValidationFailure` with
  /// `fields['phone_number']` set to the backend's own message
  /// ("Enter a valid phone number including the country code, e.g.
  /// +201234567890.", confirmed in P-027's handoff note) when
  /// [phoneNumber] doesn't carry an explicit country code.
  Future<BusinessProfile> createProfile({
    required String businessName,
    required BusinessType businessType,
    required String country,
    required String city,
    String? description,
    int? categoryId,
    String? phoneNumber,
  });

  /// Calls `PATCH /api/v1/businesses/me/` — edits an existing profile.
  ///
  /// [businessName]/[businessType]/[country]/[city] are never nullable
  /// backend-side, so passing one simply means "change it"; leaving it
  /// `null` means "leave it alone" (the field is omitted from the
  /// request body entirely).
  ///
  /// [description]/[categoryId]/[phoneNumber] ARE nullable backend-side
  /// (a Business can clear its description, un-pick a category, or
  /// remove its phone number), so a plain nullable parameter can't tell
  /// "leave alone" apart from "clear this." Each of those three instead
  /// takes a [Patchable] — its default, `Patchable<T>.unset()`, omits
  /// the field from the request body (leave alone); `Patchable<T>.value(x)`
  /// sends `x`; `Patchable<T>.clear()` sends an explicit
  /// `null` to actually clear the field server-side.
  Future<BusinessProfile> updateProfile({
    String? businessName,
    BusinessType? businessType,
    String? country,
    String? city,
    Patchable<String> description = const Patchable.unset(),
    Patchable<int> categoryId = const Patchable.unset(),
    Patchable<String> phoneNumber = const Patchable.unset(),
  });
}

/// A tiny tri-state wrapper distinguishing "not provided, leave the
/// backend field unchanged" from "explicitly provided as `null`, clear
/// the backend field" — needed only for the nullable-on-the-backend
/// fields on a PATCH request (see [BusinessProfileRepository.
/// updateProfile]'s docstring). A plain `T?` parameter can't express
/// this distinction on its own, since Dart has no way to tell "argument
/// omitted" apart from "argument explicitly passed as `null`" for a
/// nullable parameter type.
class Patchable<T> {
  const Patchable.value(T value) : _value = value, _isSet = true;

  const Patchable.clear() : _value = null, _isSet = true;

  const Patchable.unset() : _value = null, _isSet = false;

  final T? _value;
  final bool _isSet;

  /// `true` for both [Patchable.value] and [Patchable.clear] — "this
  /// field should be included in the request body at all," regardless
  /// of whether the value being sent is non-null or an explicit `null`.
  bool get isSet => _isSet;

  /// The value to send, or `null` for [Patchable.clear]. Only
  /// meaningful when [isSet] is `true` — callers should always check
  /// [isSet] before reading this, exactly like `BusinessProfileRepositoryImpl`
  /// does when building the PATCH request body.
  T? get value => _value;
}