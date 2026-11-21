/// Part BI-04: small building blocks shared by all five dashboard sections:
/// card, heading, skeleton, error view, keep-alive wrapper and the
/// loading / error / data switch with pull-to-refresh.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/widgets/app_shimmer_box.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../analytics_provider.dart' show AnalyticsBusinessUnavailableException;

/// A themed card with the standard dashboard padding.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
  }
}

class AnalyticsSectionHeading extends StatelessWidget {
  const AnalyticsSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Skeleton shown while a section loads (instead of a spinner). The shimmer
/// stops when the OS asks to reduce motion; tests that call `pumpAndSettle`
/// should pass `animate: false` or set `disableAnimations`.
class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget pair() => Row(
      children: <Widget>[
        Expanded(child: AppShimmerBox(height: 96, animate: animate)),
        const SizedBox(width: 12),
        Expanded(child: AppShimmerBox(height: 96, animate: animate)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppShimmerBox(height: 16, animate: animate),
        const SizedBox(height: 16),
        pair(),
        const SizedBox(height: 12),
        pair(),
        const SizedBox(height: 12),
        pair(),
        const SizedBox(height: 16),
        AppShimmerBox(height: 200, animate: animate),
      ],
    );
  }
}

/// A load failure with a Retry button. Messages are localized here; the
/// backend's own text is never shown.
class AnalyticsErrorView extends StatelessWidget {
  const AnalyticsErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String message = switch (error) {
      AnalyticsBusinessUnavailableException() => l10n.biNoBusiness,
      NetworkFailure() => l10n.biErrorNetwork,
      _ => l10n.biLoadFailed,
    };
    return SizedBox(
      height: 360,
      child: ErrorStateWidget(message: message, onRetry: onRetry),
    );
  }
}

/// Keeps a Tab's state (scroll, pages shown) alive while another Tab is
/// visible. The data itself is cached by the (non auto-dispose) providers, so
/// coming back never re-requests.
class AnalyticsKeepAlive extends StatefulWidget {
  const AnalyticsKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<AnalyticsKeepAlive> createState() => _AnalyticsKeepAliveState();
}

class _AnalyticsKeepAliveState extends State<AnalyticsKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The loading / error / data switch of a section, inside a pull-to-refresh
/// list.
///
/// While a reload is in flight the skeleton is shown (never the previous
/// period's numbers under the new period's label). A finished failure shows
/// the error view with Retry. [builder] returns the children of the list.
class AnalyticsAsyncSection<T> extends StatelessWidget {
  const AnalyticsAsyncSection({
    super.key,
    required this.value,
    required this.builder,
    required this.onRefresh,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final List<Widget> Function(BuildContext context, T data) builder;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children;
    if (value.isLoading) {
      children = const <Widget>[
        AnalyticsSkeleton(key: ValueKey<String>('bi-loading')),
      ];
    } else if (value.hasError) {
      children = <Widget>[
        AnalyticsErrorView(
          key: const ValueKey<String>('bi-error'),
          error: value.error,
          onRetry: onRetry,
        ),
      ];
    } else {
      children = builder(context, value.requireValue);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Always scrollable so pull-to-refresh also works on short content
        // and on the loading / error states.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      ),
    );
  }
}
