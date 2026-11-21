/// Part BI-04: the two UI actions that touch the shared dashboard state.
///
/// * [refreshAnalytics]: Refresh button and pull-to-refresh. Re-resolves a
///   rolling / month period against the clock (an app left open past midnight
///   UTC moves its window), then bumps the refresh epoch. Every section
///   provider watches the epoch, so the sections that are on screen reload
///   at once; the others reload the next time they are shown.
/// * [retryAnalytics]: the Retry button of an error state. If the business id
///   itself failed to load (own profile fetch), that failure is cached, so it
///   is invalidated first; otherwise only the failed section is invalidated.
///
/// Switching a Tab calls neither, so it never causes a request.
library;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../business_profile/presentation/business_profile_provider.dart';
import 'analytics_dashboard_providers.dart';
import 'analytics_period_provider.dart';

/// Reloads the dashboard. [waitFor] (optional) is awaited so a
/// `RefreshIndicator` stays visible until the section has its new data; its
/// failure is swallowed here because the section renders the error itself.
Future<void> refreshAnalytics(
  WidgetRef ref, {
  Future<Object?> Function()? waitFor,
}) async {
  _clearCachedBusinessFailure(ref);
  ref.read(analyticsPeriodProvider.notifier).reresolve();
  ref.read(analyticsRefreshEpochProvider.notifier).bump();
  if (waitFor == null) return;
  try {
    await waitFor();
  } catch (_) {
    // The error state of the section shows the failure.
  }
}

/// Retry of one failed section: [invalidateSection] invalidates its provider.
void retryAnalytics(WidgetRef ref, VoidCallback invalidateSection) {
  _clearCachedBusinessFailure(ref);
  invalidateSection();
}

void _clearCachedBusinessFailure(WidgetRef ref) {
  if (ref.read(analyticsBusinessIdProvider).hasError) {
    ref.invalidate(businessProfileProvider);
    ref.invalidate(analyticsBusinessIdProvider);
  }
}
