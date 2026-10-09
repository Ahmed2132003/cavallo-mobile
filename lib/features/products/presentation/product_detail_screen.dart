import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../core/widgets/media_carousel.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/shared_content.dart';
import '../../chat/presentation/share_to_conversation_sheet.dart';
import '../../social/presentation/content_interaction_key.dart';
import '../../social/presentation/social_error_message.dart';
import '../../social/presentation/social_interaction_provider.dart';
import '../domain/product_entity.dart';
import 'product_price_framing.dart';
import 'product_public_providers.dart';

/// Part P-034 scope: the customer-facing, READ-ONLY product detail
/// screen behind `/product/:id`. Replaces Part P-007's placeholder for
/// the same route — the constructor is unchanged, so `app_router.dart`
/// needed no edit.
///
/// ## ⚠️ Price framing is a REQUIREMENT, not styling
///
/// Architecture Section 20 mandates that the price is shown as
/// approximate / negotiable with the business, never as a transactional
/// price. The price is therefore only ever rendered through
/// [ProductPriceFraming] (`product_price_framing.dart`) — never as a
/// bare number.
///
/// ## ⚠️ No transactional UI, by rule
///
/// Nothing on this screen may resemble a purchase flow: no cart icon, no
/// "Buy Now" button, no quantity selector. The only body action is
/// "Message Business" (Part P-077): it starts (or resumes) a real
/// conversation with the business's owner
/// (`ConversationRepository.startConversationWithBusiness`) and opens
/// that conversation's thread. The AppBar carries Save and Share.
///
/// ## Part P-114 STEP 4A (presentation only)
///
/// Instagram-style layout: a full-width 1:1 image, then name (with the
/// read-only [FeaturedBadge] when the product is featured), price framing,
/// description, variants as read-only pills and the primary
/// "Message Business" button. Loading shows a skeleton instead of a
/// spinner. Every string comes from the ARB files and every color from
/// `context.appColors`. No provider, repository, route or callback was
/// changed. Save reuses the existing `contentInteractionProvider` with
/// content type `product` (the same toggle the Saved tab already relies
/// on); see the STEP 4A notes about its initial state.
///
/// ## States
///
/// Mirrors `BusinessProfilePublicScreen` (Part P-029): a non-numeric
/// `:id` resolves to not-found with zero network calls; `AsyncData(null)`
/// (backend 404, or an inactive product) is a not-found empty state with
/// no Retry; a genuine failure shows `ErrorStateWidget` with Retry.
///
/// Phase 11's Search results link into this same screen — do not create
/// a second product detail screen.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  /// The raw `:id` path parameter, as `go_router` hands it over — a
  /// [String], parsed here rather than by the router.
  final String productId;

  /// Part P-077: the Share icon's two options — native share sheet
  /// (unchanged style, no share tracking: P-056's endpoint covers only
  /// Post/Reel) or "Share to conversation".
  void _share(BuildContext context, Product product) {
    final String shareText = context.l10n.productShareText(product.name);
    showShareOptionsSheet(
      context,
      contentType: SharedContentType.product,
      objectId: product.id,
      onNativeShare: () async {
        try {
          await SharePlus.instance.share(ShareParams(text: shareText));
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a product — nothing to fetch. Resolve it to not-found
    // here instead of firing a request guaranteed to fail.
    final id = int.tryParse(productId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.productDetailTitle)),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final productAsync = ref.watch(productPublicDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productDetailTitle),
        actions: [
          if (productAsync case AsyncData(value: final Product product)) ...[
            _SaveAction(productId: product.id),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.actionShare,
              onPressed: () => _share(context, product),
            ),
          ],
        ],
      ),
      body: switch (productAsync) {
        AsyncData(value: final Product product) => _ProductView(
          product: product,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const _ProductSkeleton(),
      },
    );
  }
}

/// Save (bookmark) for the product, through the existing
/// `contentInteractionProvider` (content type `product`). The bookmark is
/// not mirrored in RTL. A failed toggle is rolled back by the notifier and
/// explained in a SnackBar.
///
/// KNOWN GAP: the product endpoint does not say whether the viewer already
/// saved this product, so the icon starts as "not saved". Saving is
/// idempotent on the server, so tapping always ends in the right state.
class _SaveAction extends ConsumerWidget {
  const _SaveAction({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContentInteractionKey key = (
      contentType: 'product',
      objectId: productId,
    );
    final bool saved = ref.watch(
      contentInteractionProvider(key).select((state) => state.isSaved),
    );
    final l10n = context.l10n;

    return IconButton(
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      tooltip: saved ? l10n.savedUnsave : l10n.actionSave,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(contentInteractionProvider(key).notifier).toggleSave();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(socialErrorMessage(e))),
          );
        }
      },
    );
  }
}

/// Loading placeholder with the same proportions as the real screen (a 1:1
/// image block, then text lines and a button), so nothing jumps when the
/// product arrives. Replaces the spinner.
class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.productLoadingLabel,
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: AppShimmerBox(borderRadius: 0)),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(width: 220, height: 24),
                  SizedBox(height: 12),
                  AppShimmerBox(width: 160, height: 20),
                  SizedBox(height: 8),
                  AppShimmerBox(height: 14),
                  SizedBox(height: 16),
                  AppShimmerBox(height: 14),
                  SizedBox(height: 8),
                  AppShimmerBox(width: 200, height: 14),
                  SizedBox(height: 24),
                  AppShimmerBox(height: 48, borderRadius: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This product doesn't exist (or is no longer available)" — an
/// [EmptyStateWidget], not [ErrorStateWidget]: nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.productNotFoundMessage,
      icon: Icons.inventory_2_outlined,
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
    // `business_profile_public_screen.dart`'s `_LoadErrorView` and
    // `product_list_screen.dart`'s `_apiFailureMessage`): production
    // throws a DioException carrying the typed ApiFailure in `.error`;
    // hand-rolled test fakes throw a bare ApiFailure.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => context.l10n.productLoadFailed,
    };

    return ErrorStateWidget(
      message: message,
      // Automatic retry is disabled on the provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(productPublicDetailProvider(id)),
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  bool _isStartingConversation = false;

  /// Part P-077: "Message Business". Starts (or resumes) the
  /// conversation with this product's business, then opens its thread.
  ///
  /// The router, messenger and localizations are captured BEFORE the await
  /// so they are still valid afterwards. A second tap while a request is in
  /// flight is ignored, so it can't start two.
  Future<void> _messageBusiness() async {
    if (_isStartingConversation) return;

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _isStartingConversation = true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .startConversationWithBusiness(businessId: widget.product.businessId);
      if (!mounted) return;
      setState(() => _isStartingConversation = false);

      if (conversation == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileMessageStarted)),
        );
        return;
      }

      router.pushNamed(
        RouteNames.chatThread,
        pathParameters: {RouteNames.idParam: conversation.id.toString()},
        extra: conversation,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingConversation = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiFailure ? e.message : l10n.profileMessageFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final l10n = context.l10n;
    final product = widget.product;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: product.imageUrl, label: product.name),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (product.isFeatured) ...[
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsetsDirectional.only(top: 6),
                        child: FeaturedBadge(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // The ONLY place the price is rendered on this screen —
                // always together with its mandatory framing note
                // (Section 20).
                ProductPriceFraming(
                  price: product.price,
                  currency: product.currency,
                ),
                const SizedBox(height: 16),
                Divider(height: 1, thickness: 0.5, color: colors.outline),
                const SizedBox(height: 16),
                Text(
                  product.description.isEmpty
                      ? l10n.productNoDescription
                      : product.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (product.variants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.productVariantsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Read-only info — a customer cannot select or configure
                  // a variant (that would imply a purchase flow). Plain
                  // containers, deliberately not chips or buttons.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variant in product.variants)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colors.outline,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${variant.name}: ${variant.value}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Part P-077: the primary action. Its ancestor stays the
                // scroll view, which tests rely on.
                AppButton(
                  label: l10n.productMessageBusiness,
                  isLoading: _isStartingConversation,
                  onPressed: _messageBusiness,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The product's single primary image (the backend has one `image`
/// field, not a gallery — Part P-032), full width in a fixed 1:1 frame so
/// the page never jumps while it loads. Falls back to a neutral
/// placeholder when there is no image; [MediaCarousel] handles load and
/// error states for a real URL and shows page dots only for 2+ images.
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl, required this.label});

  final String? imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: colors.surfaceVariant,
          alignment: Alignment.center,
          child: Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return MediaCarousel(
      imageUrls: [url],
      aspectRatio: 1,
      semanticLabel: label,
    );
  }
}
