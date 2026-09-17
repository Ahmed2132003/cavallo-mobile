import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository_impl.dart';
import '../domain/category_entity.dart';

/// New feature scope (Part P-033, STEP 6): the category tree a future
/// step's picker widget (product create/edit form) reads.
///
/// Not `autoDispose`: unlike `businessProfilePublicProvider`
/// (Part P-029), which is a family keyed by many different business
/// ids and would otherwise leak one cached entry per id ever viewed,
/// this provider has exactly one instance for the whole app — the
/// category tree is global, not per-anything. Keeping it alive for the
/// whole session means opening the product form a second time (even
/// after the widget that first read it was disposed) is still an
/// instant, cached read, matching `CategoryRepositoryImpl`'s own 1h
/// client-side cache in spirit.
///
/// Automatic retry is disabled (`retry: (retryCount, error) => null`),
/// matching every other `FutureProvider` in this project
/// (`businessProfilePublicProvider`) for the same documented reason:
/// Riverpod 3.x's built-in retry uses real exponential backoff, which
/// previously hung a widget test for its full timeout
/// (`session_provider_test`, per `PROJECT_PROGRESS.md`). A future
/// step's picker widget is expected to show its own explicit Retry
/// affordance and call `ref.invalidate(categoryTreeProvider)`, exactly
/// like the public business-profile screen already does.
final categoryTreeProvider = FutureProvider<List<CategoryNode>>((ref) async {
  final repository = await ref.watch(categoryRepositoryProvider.future);
  return repository.fetchCategoryTree();
}, retry: (retryCount, error) => null);