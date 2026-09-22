import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/public_post_entity.dart';
import 'content_public_providers.dart';
import 'content_stub_action_row.dart';

/// Part P-045 scope: the customer-facing, READ-ONLY Post detail screen
/// behind `/post/:id`. A genuinely new route — P-007's original skeleton
/// never anticipated Posts/Reels as top-level routes, so this is an
/// additive routing change (`route_names.dart` / `app_router.dart`,
/// this part's routing edit), not a placeholder replacement the way
/// `ProductDetailScreen`'s `/product/:id` route was.
///
/// ## States — mirrors `ProductDetailScreen` (Part P-034) exactly
///
/// A non-numeric `:id` resolves to not-found with zero network calls;
/// `AsyncData(null)` (backend 404, or a Post that exists but isn't
/// published) is a not-found empty state with no Retry; a genuine
/// failure shows `ErrorStateWidget` with Retry.
///
/// ## Deliberately NO business name/avatar on this screen
///
/// Same precedent as `ProductDetailScreen`, which shows no business
/// info either. [PublicPost] only carries `businessId`, not a name —
/// showing one here would mean a second network call (fetching the
/// business profile) that neither this part's own spec nor
/// `ProductDetailScreen`'s precedent asks for. `PostCard` (this part,
/// STEP 2) shows a business name only because ITS caller already holds
/// one in memory (the business-profile screen this part will extend,
/// and Phase 10's Feed) — this screen, reached directly by id with
/// nothing else known, does not.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  /// The raw `:id` path parameter, as `go_router` hands it over — a
  /// [String], parsed here rather than by the router.
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a Post — nothing to fetch. Resolve it to not-found here
    // instead of firing a request guaranteed to fail. Same early-exit
    // as ProductDetailScreen.
    final id = int.tryParse(postId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final postAsync = ref.watch(postPublicDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: switch (postAsync) {
        AsyncData(value: final PublicPost post) => _PostDetailView(
          post: post,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// "This post doesn't exist (or is no longer available)" — an
/// [EmptyStateWidget], not [ErrorStateWidget]: nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      message: 'Post not found.\nIt may have been removed.',
      icon: Icons.article_outlined,
    );
  }
}

/// A genuine fetch failure — retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both error shapes are handled on purpose (see
    // `ProductDetailScreen`'s own `_LoadErrorView`): production throws a
    // DioException carrying the typed ApiFailure in `.error`; hand-rolled
    // test fakes throw a bare ApiFailure.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this post.',
    };

    return ErrorStateWidget(
      message: message,
      // Automatic retry is disabled on the provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(postPublicDetailProvider(id)),
    );
  }
}

class _PostDetailView extends StatelessWidget {
  const _PostDetailView({required this.post});

  final PublicPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostDetailImage(imageUrl: post.imageUrl),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.caption.isEmpty ? 'No caption.' : post.caption,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                const ContentStubActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Larger, full-width version of `PostCard`'s `_PostImage` (STEP 2) —
/// same neutral-fallback convention, deliberately duplicated rather
/// than shared (this project's `_ProductThumbnail`/`business_profile_
/// public_screen.dart` precedent for local, per-screen duplication).
/// Uses a 1:1 aspect ratio (vs. the card's 4:3) since this is the
/// primary, full-screen view of the image rather than a compact list
/// thumbnail.
class _PostDetailImage extends StatelessWidget {
  const _PostDetailImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = imageUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 56),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: (url == null || url.isEmpty)
          ? placeholder(Icons.image_outlined)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  placeholder(Icons.broken_image_outlined),
            ),
    );
  }
}