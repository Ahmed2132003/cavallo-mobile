import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/route_names.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/shared_content.dart';
import '../../chat/presentation/share_to_conversation_sheet.dart';
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
/// "Message Business". It was a deliberately DISABLED stub from Part
/// P-034 until Part P-077 activated it: it now starts (or resumes) a
/// real conversation with the business's owner
/// (`ConversationRepository.startConversationWithBusiness`) and opens
/// that conversation's thread. Part P-077 also added the AppBar Share
/// action ("Share to conversation" / native share sheet).
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
    showShareOptionsSheet(
      context,
      contentType: SharedContentType.product,
      objectId: product.id,
      onNativeShare: () async {
        try {
          await SharePlus.instance.share(
            ShareParams(text: 'Check out ${product.name} on Cavallo'),
          );
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a product — nothing to fetch. Resolve it to not-found
    // here instead of firing a request guaranteed to fail.
    final id = int.tryParse(productId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final productAsync = ref.watch(productPublicDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          if (productAsync case AsyncData(value: final Product product))
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => _share(context, product),
            ),
        ],
      ),
      body: switch (productAsync) {
        AsyncData(value: final Product product) => _ProductView(
          product: product,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// "This product doesn't exist (or is no longer available)" — an
/// [EmptyStateWidget], not [ErrorStateWidget]: nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      message: 'Product not found.\nIt may have been removed.',
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
    // hand-rolled test fakes throw a bare ApiFailure. Duplicated here
    // rather than shared — flagged in this part's PROJECT_PROGRESS entry.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this product.',
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
  /// The router and messenger are captured BEFORE the await so they are
  /// still valid afterwards. A second tap while a request is in flight
  /// is ignored, so it can't start two.
  Future<void> _messageBusiness() async {
    if (_isStartingConversation) return;

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isStartingConversation = true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .startConversationWithBusiness(businessId: widget.product.businessId);
      if (!mounted) return;
      setState(() => _isStartingConversation = false);

      if (conversation == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Conversation started. Open it from Messages.'),
          ),
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
            e is ApiFailure
                ? e.message
                : 'Could not start the conversation. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: product.imageUrl),
          const SizedBox(height: 16),
          Text(product.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          // The ONLY place the price is rendered on this screen — always
          // together with its mandatory framing note (Section 20).
          ProductPriceFraming(price: product.price, currency: product.currency),
          const SizedBox(height: 16),
          Text(
            product.description.isEmpty
                ? 'This business hasn\'t added a description yet.'
                : product.description,
            style: theme.textTheme.bodyMedium,
          ),
          if (product.variants.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Variants', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // Read-only info — a customer cannot select or configure a
            // variant (that would imply a purchase flow).
            for (final variant in product.variants)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${variant.name}: ${variant.value}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
          const SizedBox(height: 24),
          // Part P-077: the stub from P-034, now real.
          AppButton(
            label: 'Message Business',
            isLoading: _isStartingConversation,
            onPressed: _messageBusiness,
          ),
        ],
      ),
    );
  }
}
/// The product's single primary image (the backend has one `image`
/// field, not a gallery — Part P-032). Falls back to a neutral
/// placeholder when there is no image or the URL fails to load.
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = imageUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 48),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child:
            (url == null || url.isEmpty)
                ? placeholder(Icons.inventory_2_outlined)
                : Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          placeholder(Icons.broken_image_outlined),
                ),
      ),
    );
  }
}
