/// Part BI-04: the "Content" section of the analytics dashboard.
///
/// Same behaviour as the Products tab: kept alive across tab switches, a
/// provider that is not autoDispose (no new request when the tab changes),
/// pull-to-refresh, and page-based pagination.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/formatters.dart';
import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_shimmer_box.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/error_state_widget.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../routing/route_names.dart';
import '../../../../content/presentation/own_content_provider.dart';
import '../../analytics_provider.dart'
    show AnalyticsBusinessUnavailableException;
import '../../providers/analytics_content_providers.dart';
import '../products/product_analytics_format.dart';
import '../products/product_coverage_notice.dart';
import 'content_analytics_card.dart';
import 'content_filter_bar.dart';

class AnalyticsContentTab extends ConsumerStatefulWidget {
  const AnalyticsContentTab({super.key, this.onOpenContent});

  /// Test seam. By default a tap pushes the content analytics route.
  final void Function(String contentType, int contentId)? onOpenContent;

  @override
  ConsumerState<AnalyticsContentTab> createState() =>
      _AnalyticsContentTabState();
}

class _AnalyticsContentTabState extends ConsumerState<AnalyticsContentTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(ref.read(contentTabListProvider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ownContentProvider);
    ref.invalidate(contentTabListProvider);
    try {
      await ref.read(contentTabListProvider.future);
    } on Object {
      // The error state of the provider is what the user sees.
    }
  }

  void _open(String contentType, int contentId) {
    final void Function(String contentType, int contentId)? override =
        widget.onOpenContent;
    if (override != null) {
      override(contentType, contentId);
      return;
    }
    context.pushNamed(
      RouteNames.businessAnalyticsContent,
      pathParameters: <String, String>{
        RouteNames.analyticsContentTypeParam: contentType,
        RouteNames.idParam: '$contentId',
      },
    );
  }

  String _errorText(AppLocalizations l10n, Object error) {
    return error is AnalyticsBusinessUnavailableException
        ? l10n.analyticsProdNoBusiness
        : l10n.analyticsContentLoadError;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final AsyncValue<ContentListState> async = ref.watch(
      contentTabListProvider,
    );
    return async.when(
      loading: () => const ContentListSkeleton(),
      error:
          (Object error, StackTrace stackTrace) => ErrorStateWidget(
            message: _errorText(l10n, error),
            onRetry: () => ref.invalidate(contentTabListProvider),
          ),
      data: (ContentListState state) => _buildData(context, state),
    );
  }

  Widget _buildData(BuildContext context, ContentListState state) {
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters.of(context);
    final AppColors colors = context.appColors;
    final DateTime? updatedAt = state.dataUpdatedAt;
    final String updated =
        updatedAt == null
            ? kProductMissing
            : formatters.absoluteDateTime(updatedAt);

    return Column(
      children: <Widget>[
        const ContentFilterBar(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.analyticsProdUpdatedAt(updated),
              key: const Key('analytics-content-updated-at'),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        ProductCoverageNotice(coverage: state.coverage),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child:
                state.items.isEmpty
                    ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        SizedBox(
                          height: 320,
                          child: EmptyStateWidget(
                            message: l10n.analyticsContentEmpty,
                            icon: Icons.dynamic_feed_outlined,
                          ),
                        ),
                      ],
                    )
                    : ListView.builder(
                      key: const Key('analytics-content-list'),
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: state.items.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == state.items.length) {
                          return _buildFooter(context, state);
                        }
                        final row = state.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ContentAnalyticsCard(
                            row: row,
                            onTap: () => _open(row.contentType, row.contentId),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, ContentListState state) {
    final l10n = context.l10n;
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreFailed) {
      return Center(
        child: TextButton(
          key: const Key('analytics-content-load-more-retry'),
          onPressed:
              () => unawaited(
                ref.read(contentTabListProvider.notifier).loadMore(),
              ),
          child: Text(l10n.commonRetry),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('analytics-content-load-more'),
          onPressed:
              () => unawaited(
                ref.read(contentTabListProvider.notifier).loadMore(),
              ),
          child: Text(l10n.analyticsProdLoadMore),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

/// Skeleton shown while the first page loads (also used by the External tab).
class ContentListSkeleton extends StatelessWidget {
  const ContentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return ListView.separated(
      key: const Key('analytics-content-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 4,
      separatorBuilder:
          (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder:
          (BuildContext context, int index) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppShimmerBox(width: 72, height: 72, borderRadius: 8),
                    SizedBox(width: 12),
                    Expanded(child: AppShimmerBox(height: 48)),
                  ],
                ),
                SizedBox(height: 12),
                AppShimmerBox(height: 56),
              ],
            ),
          ),
    );
  }
}
