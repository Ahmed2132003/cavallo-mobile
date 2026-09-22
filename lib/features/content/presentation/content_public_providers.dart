import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_public_repository.dart';
import '../data/reel_public_repository.dart';
import '../domain/public_post_entity.dart';
import '../domain/public_reel_entity.dart';

/// Part P-045 scope: the public, by-id Post/Reel a Customer sees at
/// `/post/:id` and `/reel/:id`. Same contract, `autoDispose` + disabled
/// retry, and states as `productPublicDetailProvider`
/// (`product_public_providers.dart`, Part P-034):
///
/// * `AsyncLoading` — the request is in flight.
/// * `AsyncData(non-null)` — published (and, for a Reel, fully
///   processed) — see `PostPublicRepositoryImpl.fetchPublicPost` /
///   `ReelPublicRepositoryImpl.fetchPublicReel` (this part, STEP 1) for
///   exactly what "published" means for each.
/// * `AsyncData(null)` — not found: backend 404, OR exists but isn't
///   publicly visible yet. A real, renderable state, NOT an error — the
///   screen shows a "not found" empty state with no Retry button.
/// * `AsyncError` — a genuine failure. The screen shows
///   `ErrorStateWidget` with Retry.
///
/// The family argument is an `int`, not the raw `:id` route string —
/// same reasoning as `productPublicDetailProvider`: both backend routes
/// are `<int:pk>/`, so a non-numeric id can never identify anything.
/// `PostDetailScreen`/`ReelDetailScreen` (this part, STEP 4/5) parse it
/// before ever reading these providers.
///
/// Business-list providers (`businessPostsProvider`/
/// `businessReelsProvider`, mirroring `businessProductsProvider` — the
/// second provider in `product_public_providers.dart`, right below
/// `productPublicDetailProvider`) are deliberately NOT added here yet:
/// STEP 4/5 only need these two by-id providers for the detail screens.
/// They belong in this same file once the business-profile-screen
/// Posts/Reels section (this part's remaining scope) is built.
final postPublicDetailProvider = FutureProvider.autoDispose
    .family<PublicPost?, int>((ref, id) {
      return ref.watch(postPublicRepositoryProvider).fetchPublicPost(id);
    }, retry: (retryCount, error) => null);

/// See [postPublicDetailProvider]'s doc — identical contract, for Reel.
final reelPublicDetailProvider = FutureProvider.autoDispose
    .family<PublicReel?, int>((ref, id) {
      return ref.watch(reelPublicRepositoryProvider).fetchPublicReel(id);
    }, retry: (retryCount, error) => null);