import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../domain/saved_item.dart';
import 'saved_list_provider.dart';

/// Part P-113 (STEP 3B): the Saved screen - tab 3 of the Customer bottom bar
/// and a Profile hub row for every account type. It replaces the STEP 1
/// placeholder.
///
/// ## What it shows
/// Three tabs (Posts, Reels, Products) over ONE list from
/// `GET /api/v1/saves/me/` ([savedListProvider]). Every row has a thumbnail,
/// the preview text and a filled bookmark button that unsaves it in place.
/// Tapping a row opens the existing Post / Reel / Product detail route, the
/// same way a shared chat card does. A row whose target no longer exists
/// reads "no longer available" and opens nothing (it can still be removed).
///
/// ## States
/// * loading: spinner; error: the shared error state with Retry;
/// * a tab with no items: its own empty message (pull down to refresh);
/// * more pages: loaded when the user scrolls near the end, and also
///   automatically while a tab has fewer than [minRowsPerTab] rows (the
///   endpoint cannot filter by type, so a tab can be short on page one);
/// * a failed page load shows a retry row and is never retried in a loop.
///
/// ## Staying fresh
/// The shell keeps this screen alive while another tab is showing. When the
/// tab becomes active again the list is refreshed silently (the branch's
/// `TickerMode` flips from disabled to enabled), so something saved from Home
/// in the meantime appears without a manual refresh.
///
/// Texts come from the ARB files, colours from the theme tokens, and layout
/// uses directional widgets only.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  /// Pages are loaded automatically until a tab has at least this many rows.
  static const int minRowsPerTab = 6;

  static const Key tabBarKey = Key('saved-tab-bar');

  static Key tabKey(SavedContentType type) => Key('saved-tab-${type.name}');

  static Key emptyKey(SavedContentType type) => Key('saved-empty-${type.name}');

  static Key itemKey(SavedContentType type, int objectId) =>
      Key('saved-item-${type.name}-$objectId');

  static Key unsaveKey(SavedContentType type, int objectId) =>
      Key('saved-unsave-${type.name}-$objectId');

  static const Key retryMoreKey = Key('saved-retry-more');

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  bool? _wasActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `TickerMode` is disabled by the shell for a tab that is not showing.
    final bool active = TickerMode.of(context);
    if (_wasActive == false && active) {
      // Not during build: providers must not change while the tree builds.
      Future<void>.microtask(() {
        if (mounted) {
          unawaited(ref.read(savedListProvider.notifier).refreshSilently());
        }
      });
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SavedListState> async = ref.watch(savedListProvider);

    final Widget body = switch (async) {
      AsyncData(:final value) => TabBarView(
        children: <Widget>[
          for (final SavedContentType type in SavedContentType.values)
            _SavedTab(type: type, state: value),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: localizedApiError(l10n, error),
        onRetry: () => unawaited(ref.read(savedListProvider.notifier).refresh()),
      ),
      _ => const LoadingIndicator(),
    };

    return DefaultTabController(
      length: SavedContentType.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hubSaved),
          bottom: TabBar(
            key: SavedScreen.tabBarKey,
            tabs: <Widget>[
              Tab(
                key: SavedScreen.tabKey(SavedContentType.post),
                text: l10n.savedTabPosts,
              ),
              Tab(
                key: SavedScreen.tabKey(SavedContentType.reel),
                text: l10n.savedTabReels,
              ),
              Tab(
                key: SavedScreen.tabKey(SavedContentType.product),
                text: l10n.savedTabProducts,
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

void _loadMoreQuietly(WidgetRef ref) {
  unawaited(
    ref.read(savedListProvider.notifier).loadMore().catchError((Object _) {}),
  );
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab({required this.type, required this.state});

  final SavedContentType type;
  final SavedListState state;

  String _emptyMessage(AppLocalizations l10n) => switch (type) {
    SavedContentType.post => l10n.savedEmptyPosts,
    SavedContentType.reel => l10n.savedEmptyReels,
    SavedContentType.product => l10n.savedEmptyProducts,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<SavedItem> items = state.itemsOf(type);

    final bool canAutoLoad =
        state.hasMore && !state.isLoadingMore && !state.loadMoreFailed;
    if (canAutoLoad && items.length < SavedScreen.minRowsPerTab) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (context.mounted) {
          _loadMoreQuietly(ref);
        }
      });
    }

    Future<void> refresh() =>
        ref.read(savedListProvider.notifier).refreshSilently();

    if (items.isEmpty) {
      if (state.hasMore) {
        // Other pages may still hold items of this type.
        if (state.loadMoreFailed) {
          return ErrorStateWidget(
            message: l10n.savedLoadMoreFailed,
            onRetry: () => _loadMoreQuietly(ref),
          );
        }
        return const LoadingIndicator();
      }
      return RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                SizedBox(
                  height: constraints.maxHeight,
                  child: EmptyStateWidget(
                    key: SavedScreen.emptyKey(type),
                    icon: Icons.bookmark_border,
                    message: _emptyMessage(l10n),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bool showFooter = state.isLoadingMore || state.loadMoreFailed;

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          final ScrollMetrics metrics = notification.metrics;
          if (metrics.axis == Axis.vertical &&
              metrics.extentAfter < 300 &&
              state.hasMore &&
              !state.isLoadingMore &&
              !state.loadMoreFailed) {
            _loadMoreQuietly(ref);
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (showFooter ? 1 : 0),
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            if (index >= items.length) {
              return _LoadMoreFooter(
                failed: state.loadMoreFailed,
                onRetry: () => _loadMoreQuietly(ref),
              );
            }
            return _SavedItemTile(item: items[index]);
          },
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (!failed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 24, child: LoadingIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.savedLoadMoreFailed,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            key: SavedScreen.retryMoreKey,
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _SavedItemTile extends ConsumerWidget {
  const _SavedItemTile({required this.item});

  final SavedItem item;

  void _open(BuildContext context) {
    final Map<String, String> params = <String, String>{
      RouteNames.idParam: '${item.objectId}',
    };
    switch (item.contentType) {
      case SavedContentType.post:
        context.pushNamed(RouteNames.postDetail, pathParameters: params);
      case SavedContentType.reel:
        context.pushNamed(RouteNames.reelDetail, pathParameters: params);
      case SavedContentType.product:
        context.pushNamed(RouteNames.productDetail, pathParameters: params);
    }
  }

  Future<void> _unsave(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    try {
      await ref.read(savedListProvider.notifier).unsave(item);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.savedUnsaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final bool unavailable = item.isUnavailable;
    final String preview = item.previewText ?? '';

    return ListTile(
      key: SavedScreen.itemKey(item.contentType, item.objectId),
      leading: _SavedThumbnail(
        url: item.previewImageUrl,
        type: item.contentType,
      ),
      title: Text(
        unavailable
            ? l10n.savedUnavailable
            : (preview.isEmpty ? l10n.savedNoPreviewText : preview),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: unavailable ? TextStyle(color: colors.textSecondary) : null,
      ),
      trailing: IconButton(
        key: SavedScreen.unsaveKey(item.contentType, item.objectId),
        icon: Icon(Icons.bookmark, color: colors.brand),
        tooltip: l10n.savedUnsave,
        onPressed: () => unawaited(_unsave(context, ref)),
      ),
      onTap: unavailable ? null : () => _open(context),
    );
  }
}

class _SavedThumbnail extends StatelessWidget {
  const _SavedThumbnail({required this.url, required this.type});

  final String? url;
  final SavedContentType type;

  static const double size = 56;

  IconData get _icon => switch (type) {
    SavedContentType.post => Icons.image_outlined,
    SavedContentType.reel => Icons.play_circle_outline,
    SavedContentType.product => Icons.shopping_bag_outlined,
  };

  /// The backend may return a path (`/media/...`) when the file storage is
  /// local; make it absolute against the API host.
  static String _absolute(String raw) {
    final Uri uri = Uri.parse(raw);
    if (uri.hasScheme) {
      return raw;
    }
    return Uri.parse(AppConfig.apiBaseUrl).resolve(raw).toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final BorderRadius radius = BorderRadius.circular(8);

    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: radius),
      child: Icon(_icon, color: colors.textSecondary),
    );

    final String? imageUrl = url;
    if (imageUrl == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        _absolute(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                placeholder,
      ),
    );
  }
}
