import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';

/// Part P-114 STEP 2: a post-shaped skeleton (header, square media, action
/// icons, two caption lines) built from [AppShimmerBox]. It has the same fixed
/// proportions as `PostCard` (1:1 media), so the list does not jump when the
/// real cards replace it.
///
/// Presentation only: no data, no provider. Colours come from the tokens, so
/// it works in Light and Dark, and the sweep follows the reading direction.
/// Pass `animate: false` in tests that use `pumpAndSettle`, because a
/// repeating animation never settles.
class FeedPostSkeleton extends StatelessWidget {
  const FeedPostSkeleton({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
            child: Row(
              children: <Widget>[
                AppShimmerBox.circle(size: 32, animate: animate),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppShimmerBox(
                      width: 120,
                      height: 12,
                      borderRadius: 6,
                      animate: animate,
                    ),
                    const SizedBox(height: 6),
                    AppShimmerBox(
                      width: 72,
                      height: 10,
                      borderRadius: 5,
                      animate: animate,
                    ),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: SizedBox.expand(
              child: AppShimmerBox(borderRadius: 0, animate: animate),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
            child: Row(
              children: <Widget>[
                AppShimmerBox.circle(size: 24, animate: animate),
                const SizedBox(width: 16),
                AppShimmerBox.circle(size: 24, animate: animate),
                const SizedBox(width: 16),
                AppShimmerBox.circle(size: 24, animate: animate),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppShimmerBox(
                  width: 220,
                  height: 12,
                  borderRadius: 6,
                  animate: animate,
                ),
                const SizedBox(height: 8),
                AppShimmerBox(
                  width: 150,
                  height: 12,
                  borderRadius: 6,
                  animate: animate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Part P-114 STEP 2: the Home feed's first-load state: [count] post
/// skeletons instead of a spinner. It does not scroll (the real list takes
/// over as soon as the first page arrives) and carries one localized
/// "loading" label for screen readers (the shimmer boxes themselves are
/// hidden from them).
class FeedSkeletonList extends StatelessWidget {
  const FeedSkeletonList({super.key, this.count = 2, this.animate = true});

  final int count;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.feedLoadingLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (int i = 0; i < count; i++) FeedPostSkeleton(animate: animate),
        ],
      ),
    );
  }
}
