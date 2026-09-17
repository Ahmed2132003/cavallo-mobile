import 'business_profile_entity.dart';

/// Part P-029 scope: the customer-facing, READ-ONLY view of some other
/// business's profile — `GET /api/v1/businesses/{id}/`
/// (`BusinessProfilePublicView`, Part P-026).
///
/// ### Why this is a separate interface from [BusinessProfileRepository]
///
/// [BusinessProfileRepository] (Part P-028A) is "my own profile":
/// `/businesses/me/`, resolved strictly from `request.user` server-side,
/// read AND write. This one is "any business, by id": a different
/// endpoint, no auth at all (`authentication_classes = []` on the real
/// view — confirmed in the backend source, not assumed), and read-only
/// forever. Folding both into one interface would put a method on the
/// owner-facing repository that has nothing to do with the owner.
///
/// ### Why the entity is reused instead of a parallel "public" entity
///
/// `BusinessProfilePublicView` reuses `BusinessProfileSerializer`
/// unchanged (confirmed in `businesses/views.py` + `serializers.py` on
/// `main`), so the public response shape is byte-for-byte the same shape
/// [BusinessProfile] already models. Per this part's own execution
/// prompt ("don't create a redundant parallel entity unless the public
/// endpoint genuinely returns different fields"), it doesn't.
abstract class BusinessProfilePublicRepository {
  /// Fetches the public profile of the business with [id].
  ///
  /// Returns `null` when the business genuinely does not exist (backend
  /// 404) — a valid, expected state this screen must render distinctly
  /// from a generic error, per this part's acceptance criteria. Every
  /// other failure (network, 5xx, anything unexpected) is thrown as a
  /// `DioException` whose `.error` is already a typed `ApiFailure`,
  /// exactly like every other repository in this project.
  Future<BusinessProfile?> fetchPublicProfile(int id);
}
