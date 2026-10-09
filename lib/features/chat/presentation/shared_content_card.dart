import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../content/domain/public_post_entity.dart';
import '../../content/domain/public_reel_entity.dart';
import '../../content/presentation/content_public_providers.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
import '../domain/shared_content.dart';

/// Part P-077 STEP 3 â€” renders the platform content a chat message
/// shares (Post / Reel / Product) as a tappable card.
///
/// ### Reuse, zero modification elsewhere
/// - Post  -> the existing [PostCard], fed by `postPublicDetailProvider`.
/// - Reel  -> the existing [ReelCard], fed by `reelPublicDetailProvider`.
/// - Product -> a compact preview card ([_PreviewCard]). No dedicated
///   `ProductCard` exists in this project, and the part spec explicitly
///   allows "a lightweight product-card" in that case.
/// Neither `post_card.dart` nor `reel_card.dart` is touched.
///
/// ### Why the live entity is fetched here
/// The message's `shared_content` payload is viewer-INDEPENDENT (see
/// `build_shared_content_payload()` in the backend's `chat/serializers.py`):
/// it has no is_liked / is_saved. `PostCard`/`ReelCard` need the live,
/// per-viewer entity, so it is fetched by id through the same public
/// providers the detail screens use.
///
/// ### States (Post / Reel)
/// - `shared.available == false` -> [_UnavailableCard], NO network call.
/// - loading or fetch error -> [_PreviewCard] built from the payload's
///   own preview (never a blank bubble; still tappable).
/// - fetched `null` (taken down since the payload was built) ->
///   [_UnavailableCard].
/// - fetched entity -> the real card.
///
/// Tapping opens the content's existing detail screen via
/// `context.pushNamed(...)`, the same convention as `HomeFeedScreen`.
class SharedContentCard extends ConsumerWidget {
  const SharedContentCard({super.key, required this.sharedContent});

  final SharedContent sharedContent;

  void _open(BuildContext context) {
    final params = {RouteNames.idParam: '${sharedContent.objectId}'};
    switch (sharedContent.type) {
      case SharedContentType.post:
        context.pushNamed(RouteNames.postDetail, pathParameters: params);
      case SharedContentType.reel:
        context.pushNamed(RouteNames.reelDetail, pathParameters: params);
      case SharedContentType.product:
        context.pushNamed(RouteNames.productDetail, pathParameters: params);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = sharedContent;
    if (!shared.available) return const _UnavailableCard();

    final businessName = shared.businessName ?? '';
    Widget preview() =>
        _PreviewCard(shared: shared, onTap: () => _open(context));

    switch (shared.type) {
      case SharedContentType.post:
        final async = ref.watch(postPublicDetailProvider(shared.objectId));
        return switch (async) {
          AsyncData(value: final PublicPost post) => PostCard(
            post: post,
            businessName: businessName,
            onTap: () => _open(context),
          ),
          AsyncData(value: null) => const _UnavailableCard(),
          _ => preview(),
        };
      case SharedContentType.reel:
        final async = ref.watch(reelPublicDetailProvider(shared.objectId));
        return switch (async) {
          AsyncData(value: final PublicReel reel) => ReelCard(
            reel: reel,
            businessName: businessName,
            onTap: () => _open(context),
          ),
          AsyncData(value: null) => const _UnavailableCard(),
          _ => preview(),
        };
      case SharedContentType.product:
        return preview();
    }
  }
}

String _typeLabel(AppLocalizations l10n, SharedContentType type) {
  switch (type) {
    case SharedContentType.post:
      return l10n.sharedContentTypePost;
    case SharedContentType.reel:
      return l10n.sharedContentTypeReel;
    case SharedContentType.product:
      return l10n.sharedContentTypeProduct;
  }
}

IconData _typeIcon(SharedContentType type) {
  switch (type) {
    case SharedContentType.post:
      return Icons.image_outlined;
    case SharedContentType.reel:
      return Icons.play_circle_outline;
    case SharedContentType.product:
      return Icons.inventory_2_outlined;
  }
}

/// Compact tappable card built ONLY from the message payload's own
/// preview (image + text + business name). Used for Products, and as
/// the loading / error fallback for Posts and Reels.
///
/// Root key: `sharedContent_preview_<post|reel|product>`.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.shared, required this.onTap});

  final SharedContent shared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = shared.previewText;
    final title =
        (previewText != null && previewText.isNotEmpty)
            ? previewText
            : _typeLabel(context.l10n, shared.type);
    final businessName = shared.businessName;

    return Card(
      key: ValueKey('sharedContent_preview_${shared.type.name}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: _PreviewThumbnail(
                url: shared.previewImageUrl,
                icon: _typeIcon(shared.type),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _typeIcon(shared.type),
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _typeLabel(context.l10n, shared.type),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    if (businessName != null && businessName.isNotEmpty)
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Neutral placeholder for "no image" and for a URL that fails to load
/// (same convention as `PostCard`'s `_PostImage`).
class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({required this.url, required this.icon});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget placeholder(IconData data) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(data, size: 28),
    );

    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return placeholder(icon);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) =>
              placeholder(Icons.broken_image_outlined),
    );
  }
}

/// Shown when the shared content was unpublished / deactivated /
/// deleted after being shared. Not tappable: there is nothing to open,
/// and no details of the taken-down item are shown.
///
/// Root key: `sharedContent_unavailable`.
class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('sharedContent_unavailable'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.block_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.sharedContentUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
