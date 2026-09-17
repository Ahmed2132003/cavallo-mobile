import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repository_impl.dart';
import '../domain/product_entity.dart';

/// Part P-033 scope: `ownProductsProvider` — the single source of truth
/// for "what does the signed-in Business account's own product list
/// look like right now." Plain, non-code-gen Riverpod (`AsyncNotifier`,
/// no `@riverpod`), same convention as `BusinessProfileNotifier`
/// (Part P-028A) and `SessionNotifier` (Part P-021a) — confirmed
/// against the real `pubspec.yaml` (`flutter_riverpod: 3.3.2`, no
/// `riverpod_generator`/`riverpod_annotation`) before writing this
/// file, not assumed.
///
/// State is `AsyncValue<List<Product>>`:
/// * `AsyncData([...])` — the business's own products (first page
///   only — see `ProductRepository.fetchOwnProducts`'s own docstring
///   for why: this part's Acceptance Criteria has no "load more" UI).
///   An empty list is a valid, expected state (a brand-new business
///   with no products yet), never an error.
/// * `AsyncError` — a genuine failure fetching the list (network, 5xx,
///   an actual `ApiFailure`, Part P-004).
///
/// ### Why mutations don't touch `state` until they succeed
///
/// Unlike `BusinessProfileNotifier.createProfile`/`updateProfile`
/// (Part P-028A/C2), which set `state = AsyncValue.loading()` the
/// instant the call starts, the methods below leave `state` completely
/// untouched while a create/update/delete call is in flight. This
/// difference is deliberate, not an oversight: `BusinessProfileNotifier`
/// mutates a SINGLETON — the profile IS the whole state, so there's
/// nothing meaningful left to show while it's being replaced. Here, one
/// create/update/delete call only ever affects ONE item in a LIST —
/// wiping the whole list to `AsyncValue.loading()` while, say, editing a
/// single product's price would make every other, still-unaffected
/// product flicker out of a future list screen for no reason. The list
/// is only actually refetched (and only then briefly shows
/// `AsyncValue.loading()`, via [refreshProducts]) once the mutating call
/// has already succeeded — exactly the "refresh the list on success"
/// behavior this part's own spec asks for.
///
/// On failure, none of the methods below touch `state` at all — the
/// original exception (already a `DioException` whose `.error` is a
/// typed `ApiFailure`) propagates straight to the caller (a future
/// step's product form screen), which reads it directly for inline
/// validation errors, exactly like `BusinessProfileEditScreen` already
/// does with `BusinessProfileNotifier.updateProfile`. The
/// previously-loaded list stays exactly as it was — a failed edit must
/// never make a business's existing products vanish from its own list
/// screen.
class OwnProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final page = await ref
        .watch(productRepositoryProvider)
        .fetchOwnProducts();
    return page.results;
  }

  /// Calls `ProductRepository.createProduct` (`POST /api/v1/products/`,
  /// Part P-032) and, only once that call has actually succeeded, calls
  /// [refreshProducts] so the new product appears in [state]. Returns
  /// the newly created [Product] — a future step's form screen needs
  /// its `id` immediately afterward, to attach any variants the user
  /// added in the same form via `ProductVariantRepository`
  /// (Part P-032B), which requires an already-existing `productId`.
  ///
  /// Parameters mirror `ProductRepository.createProduct` exactly.
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required Currency currency,
    File? imageFile,
    bool isActive = true,
  }) async {
    final product = await ref
        .read(productRepositoryProvider)
        .createProduct(
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          currency: currency,
          imageFile: imageFile,
          isActive: isActive,
        );
    await refreshProducts();
    return product;
  }

  /// Calls `ProductRepository.updateProduct`
  /// (`PATCH /api/v1/products/<pk>/`, Part P-032) and, only once that
  /// call has actually succeeded, calls [refreshProducts]. Returns the
  /// backend's own updated [Product] (not a locally-patched guess) —
  /// same reasoning as `BusinessProfileNotifier.updateProfile`: the
  /// backend is the source of truth for what a partial update actually
  /// produced.
  ///
  /// Parameters mirror `ProductRepository.updateProduct` exactly —
  /// every field but [productId] is optional, and only the ones
  /// actually passed are sent to the backend (see
  /// `ProductRepositoryImpl`'s own docstring).
  Future<Product> updateProduct({
    required int productId,
    int? categoryId,
    String? name,
    String? description,
    String? price,
    Currency? currency,
    File? imageFile,
    bool? isActive,
  }) async {
    final product = await ref
        .read(productRepositoryProvider)
        .updateProduct(
          productId: productId,
          categoryId: categoryId,
          name: name,
          description: description,
          price: price,
          currency: currency,
          imageFile: imageFile,
          isActive: isActive,
        );
    await refreshProducts();
    return product;
  }

  /// Calls `ProductRepository.deleteProduct`
  /// (`DELETE /api/v1/products/<pk>/`, Part P-032 — a soft delete
  /// server-side, see that method's own docstring) and, only once that
  /// call has actually succeeded, calls [refreshProducts] so the
  /// deleted product disappears from [state]. A future step's list
  /// screen is responsible for showing its own confirmation dialog
  /// BEFORE calling this — this method itself performs no confirmation
  /// and no undo.
  Future<void> deleteProduct(int productId) async {
    await ref.read(productRepositoryProvider).deleteProduct(productId);
    await refreshProducts();
  }

  /// Re-runs the same `GET /api/v1/products/` call [build] makes and
  /// assigns the result to [state], without disposing/rebuilding this
  /// notifier — the pull-to-refresh action on a future step's list
  /// screen, and the shared "reload after a successful mutation" step
  /// every method above ends with.
  ///
  /// Uses [AsyncValue.guard], exactly like
  /// `BusinessProfileNotifier.refreshProfile` — a failed refresh
  /// settles into [AsyncError] without rethrowing, since it's a
  /// non-destructive, retryable read, distinct from
  /// [createProduct]/[updateProduct]/[deleteProduct]'s own "rethrow the
  /// original failure to the caller" contract for the mutation itself.
  Future<void> refreshProducts() async {
    state = const AsyncValue<List<Product>>.loading();
    state = await AsyncValue.guard<List<Product>>(() async {
      final page = await ref
          .read(productRepositoryProvider)
          .fetchOwnProducts();
      return page.results;
    });
  }
}

/// Exposes [OwnProductsNotifier] to the rest of the app, per this
/// project's established Riverpod pattern (`businessProfileProvider`,
/// `sessionProvider`) — a plain `AsyncNotifierProvider`, no code-gen.
/// NOT `.autoDispose`, matching `businessProfileProvider`'s own choice
/// for the same reason: a signed-in Business account's own product
/// list is meant to live for the session, not be silently disposed and
/// re-fetched every time a future list screen is navigated away from
/// and back to.
final ownProductsProvider =
    AsyncNotifierProvider<OwnProductsNotifier, List<Product>>(
      OwnProductsNotifier.new,
    );