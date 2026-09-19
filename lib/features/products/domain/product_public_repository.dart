import '../../../core/network/paginated_response.dart';
import 'product_entity.dart';

/// Part P-034 scope: the domain-facing contract for PUBLIC, read-only
/// product reads — what a Customer sees while browsing. Deliberately a
/// separate contract from `ProductRepository` (Part P-033), which is
/// "my own products" CRUD resolved from `request.user`: this one has no
/// ownership concerns at all, and must never be merged with it.
///
/// Mirrors `BusinessProfilePublicRepository`'s (Part P-029) exact split:
/// interface here in `domain/`, implementation in `data/`.
abstract class ProductPublicRepository {
  /// Calls `GET /api/v1/products/{id}/` (public, no auth required by the
  /// backend — Part P-032's `ProductDetailView`).
  ///
  /// Returns `null` — a real, renderable "not found" state, never an
  /// error — when the product does not exist (backend 404) OR when it
  /// exists but is not active (`isActive == false`). The second case
  /// exists because P-032's `ProductDetailView` uses
  /// `Product.objects.all()` and therefore serves hidden products by id;
  /// a public reader must not see them (see this part's PROJECT_PROGRESS
  /// entry, "Known issues").
  Future<Product?> fetchPublicProduct(int id);

  /// Calls `GET /api/v1/products/public/?business_id={businessId}`
  /// (public; only `is_active=True`, non-deleted products — Part P-032's
  /// `ProductPublicListView`). Cursor-paginated: this part only consumes
  /// the first page, exactly like Part P-033's own list — no "load more".
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId);
}
