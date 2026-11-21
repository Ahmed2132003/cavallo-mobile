/// Part BI-04: All / Posts / Reels switch and the ordering chips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../providers/analytics_content_providers.dart';

String contentOrderingLabel(AppLocalizations l10n, ContentOrdering ordering) {
  return switch (ordering) {
    ContentOrdering.mostViewed => l10n.analyticsContentOrderMostViewed,
    ContentOrdering.mostLiked => l10n.analyticsContentOrderMostLiked,
    ContentOrdering.mostSaved => l10n.analyticsContentOrderMostSaved,
    ContentOrdering.mostShared => l10n.analyticsContentOrderMostShared,
    ContentOrdering.highestEngagement =>
      l10n.analyticsContentOrderHighestEngagement,
    ContentOrdering.newest => l10n.analyticsContentOrderNewest,
  };
}

/// Singular label for a wire content type ('post' / 'reel').
String contentTypeLabel(AppLocalizations l10n, String contentType) {
  return switch (contentType) {
    'post' => l10n.analyticsContentTypePost,
    'reel' => l10n.analyticsContentTypeReel,
    _ => contentType,
  };
}

class ContentFilterBar extends ConsumerWidget {
  const ContentFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ContentTypeFilter type = ref.watch(contentTypeFilterProvider);
    final ContentOrdering ordering = ref.watch(contentOrderingProvider);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ContentTypeFilter>(
              key: const Key('analytics-content-type-filter'),
              showSelectedIcon: false,
              segments: <ButtonSegment<ContentTypeFilter>>[
                ButtonSegment<ContentTypeFilter>(
                  value: ContentTypeFilter.all,
                  label: Text(l10n.analyticsContentTypeAll, maxLines: 1),
                ),
                ButtonSegment<ContentTypeFilter>(
                  value: ContentTypeFilter.post,
                  label: Text(l10n.analyticsContentTypePosts, maxLines: 1),
                ),
                ButtonSegment<ContentTypeFilter>(
                  value: ContentTypeFilter.reel,
                  label: Text(l10n.analyticsContentTypeReels, maxLines: 1),
                ),
              ],
              selected: <ContentTypeFilter>{type},
              onSelectionChanged:
                  (Set<ContentTypeFilter> next) => ref
                      .read(contentTypeFilterProvider.notifier)
                      .select(next.first),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: ContentOrdering.tabChoices.length,
            separatorBuilder:
                (BuildContext context, int index) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final ContentOrdering choice = ContentOrdering.tabChoices[index];
              return ChoiceChip(
                key: Key('analytics-content-order-${choice.name}'),
                label: Text(contentOrderingLabel(l10n, choice)),
                selected: choice == ordering,
                onSelected:
                    (bool _) => ref
                        .read(contentOrderingProvider.notifier)
                        .select(choice),
              );
            },
          ),
        ),
      ],
    );
  }
}
