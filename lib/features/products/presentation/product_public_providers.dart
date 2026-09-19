import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_public_repository.dart';
import '../domain/product_entity.dart';

/// Part P-034 scope: the public, by-id product a Customer sees at
/// `/product/:id`.
///
/// ### The states this provider can settle into
///
/// * `AsyncLoading` — the request is in flight.
/// * `AsyncData(non-null)` — the product exists and is active.
/// * `AsyncData(null)` — not found: the backend returned 404, OR the
///   product exists but is inactive (see
///   `ProductPublicRepository.fetchPublicProduct`). A real, renderable
///   state, NOT an error — the screen shows a "not found" empty state
///   with no Retry button. Mirrors `businessProfilePublicProvider`'s
///   (Part P-029) contract exactly.
/// * `AsyncError` — a genuine failure (no connectivity, 5xx, an
///   unexpected payload). The screen shows `ErrorStateWidget` with Retry.
///
/// ### Why `autoDispose` and why retry is disabled
///
/// Same two reasons documented in `business_profile_public_provider.dart`
/// (Part P-029): this is a family keyed by an unbounded id space, so
/// cached entries are dropped once no screen watches them; and Riverpod
/// 3.x's automatic exponential-backoff retry would only delay the visible
/// error state and hang widget tests, while an explicit Retry button
/// already exists (`ref.invalidate(productPublicDetailProvider(id))`).
///
/// ### Argument type
///
/// The family argument is an `int`, not the raw `:id` route string: the
/// backend route is `<int:pk>/`, so a non-numeric id can never identify a
/// product. The screen parses it before ever reading this provider.
///
/// Deliberately does NOT reuse `ownProductsProvider` (Part P-033): that
/// provider is scoped to "my own products" only.
final productPublicDetailProvider = FutureProvider.autoDispose
    .family<Product?, int>((ref, id) {
      return ref.watch(productPublicRepositoryProvider).fetchPublicProduct(id);
    }, retry: (retryCount, error) => null);

/// Part P-034 scope: the FIRST page of one business's public, active
/// products (`GET /api/v1/products/public/?business_id=...`), shown as
/// the products section of the public business profile screen (Part
/// P-029's screen, extended by this part).
///
/// Returns a plain `List<Product>` — the cursor metadata
/// (`next`/`previous`) is intentionally dropped: this part has no "load
/// more" UI, same scope decision as Part P-033's own list. An empty list
/// is a valid, renderable state (the business has no active products
/// yet), not an error.
///
/// `autoDispose` + disabled retry, for the same reasons as
/// [productPublicDetailProvider].
final businessProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, int>((ref, businessId) async {
      final page = await ref
          .watch(productPublicRepositoryProvider)
          .fetchBusinessProducts(businessId);
      return page.results;
    }, retry: (retryCount, error) => null);
