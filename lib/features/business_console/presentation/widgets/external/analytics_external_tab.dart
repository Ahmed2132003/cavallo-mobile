/// Part BI-04: the "External" section of the analytics dashboard.
///
/// The contract has no business-wide external endpoint: external numbers
/// exist per content item. So this tab lists the merchant's content (newest
/// first, paged) and loads an item's external numbers only when it is opened.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_shimmer_box.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/error_state_widget.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../routing/route_names.dart';
import '../../../../content/presentation/own_content_provider.dart';
import '../../../domain/analytics_content.dart';
import '../../analytics_provider.dart'
    show AnalyticsBusinessUnavailableException;
import '../../providers/analytics_content_providers.dart';
import '../content/analytics_content_tab.dart' show ContentListSkeleton;
import '../content/content_analytics_card.dart';
import '../content/content_filter_bar.dart';
import 'external_metric_form_sheet.dart';
import 'external_metrics_panel.dart';

class AnalyticsExternalTab extends ConsumerStatefulWidget {
  const AnalyticsExternalTab({super.key});

  @override
  ConsumerState<AnalyticsExternalTab> createState() =>
      _AnalyticsExternalTabState();
}

class _AnalyticsExternalTabState extends ConsumerState<AnalyticsExternalTab>
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
      unawaited(ref.read(externalContentListProvider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ownContentProvider);
    ref.invalidate(contentExternalMetricsProvider);
    ref.invalidate(externalContentListProvider);
    try {
      await ref.read(externalContentListProvider.future);
    } on Object {
      // The error state of the provider is what the user sees.
    }
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
    final AppColors colors = context.appColors;
    final AsyncValue<ContentListState> async = ref.watch(
      externalContentListProvider,
    );
    return async.when(
      loading: () => const ContentListSkeleton(),
      error:
          (Object error, StackTrace stackTrace) => ErrorStateWidget(
            message: _errorText(l10n, error),
            onRetry: () => ref.invalidate(externalContentListProvider),
          ),
      data:
          (ContentListState state) => Column(
            children: <Widget>[
              Container(
                key: const Key('analytics-external-intro'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.public, size: 20, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.analyticsExternalIntro,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                                  icon: Icons.public,
                                ),
                              ),
                            ],
                          )
                          : ListView.builder(
                            key: const Key('analytics-external-list'),
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: state.items.length + 1,
                            itemBuilder: (BuildContext context, int index) {
                              if (index == state.items.length) {
                                return _buildFooter(context, state);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExternalContentTile(
                                  row: state.items[index],
                                ),
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
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
          key: const Key('analytics-external-load-more-retry'),
          onPressed:
              () => unawaited(
                ref.read(externalContentListProvider.notifier).loadMore(),
              ),
          child: Text(l10n.commonRetry),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('analytics-external-load-more'),
          onPressed:
              () => unawaited(
                ref.read(externalContentListProvider.notifier).loadMore(),
              ),
          child: Text(l10n.analyticsProdLoadMore),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

/// One content item whose external numbers load when it is opened.
class ExternalContentTile extends ConsumerStatefulWidget {
  const ExternalContentTile({super.key, required this.row});

  final ContentAnalyticsRow row;

  @override
  ConsumerState<ExternalContentTile> createState() =>
      _ExternalContentTileState();
}

class _ExternalContentTileState extends ConsumerState<ExternalContentTile> {
  bool _expanded = false;

  (String, int) get _key => (widget.row.contentType, widget.row.contentId);

  Future<void> _edit() async {
    final bool? saved = await showExternalMetricSheet(
      context,
      contentType: widget.row.contentType,
      contentId: widget.row.contentId,
    );
    if (saved != true) {
      return;
    }
    ref.invalidate(contentExternalMetricsProvider(_key));
    ref.invalidate(contentAnalyticsDetailProvider(_key));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.analyticsExternalSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final ContentAnalyticsRow row = widget.row;
    final String? thumb = ref.watch(
      analyticsContentThumbProvider((row.contentType, row.contentId)),
    );
    final String caption =
        row.captionPreview.trim().isEmpty
            ? l10n.analyticsContentNoCaption
            : row.captionPreview;

    return Container(
      key: Key('analytics-external-tile-${row.contentType}-${row.contentId}'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  ContentThumb(
                    imageUrl: thumb,
                    contentType: row.contentType,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          contentTypeLabel(l10n, row.contentType),
                          style: text.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildExternal(context),
            ),
        ],
      ),
    );
  }

  Widget _buildExternal(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<ExternalMetricsResponse> async = ref.watch(
      contentExternalMetricsProvider(_key),
    );
    return async.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: AppShimmerBox(
              key: Key('analytics-external-tile-loading'),
              height: 72,
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.analyticsExternalLoadError),
              TextButton(
                key: const Key('analytics-external-tile-retry'),
                onPressed:
                    () => ref.invalidate(contentExternalMetricsProvider(_key)),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
      data:
          (ExternalMetricsResponse result) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExternalMetricsPanel(metrics: result.metrics, onEdit: _edit),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('analytics-external-open-details'),
                  onPressed:
                      () => context.pushNamed(
                        RouteNames.businessAnalyticsContent,
                        pathParameters: <String, String>{
                          RouteNames.analyticsContentTypeParam:
                              widget.row.contentType,
                          RouteNames.idParam: '${widget.row.contentId}',
                        },
                      ),
                  child: Text(l10n.analyticsContentOpenDetails),
                ),
              ),
            ],
          ),
    );
  }
}
