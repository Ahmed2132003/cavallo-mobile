/// Part BI-04: the Business Console Analytics tab as a five-section
/// dashboard: Overview, Products, Orders & Sales, Content, External.
///
/// * One shared period bar (`analyticsPeriodProvider`) above the sections.
/// * Each section is its own widget; each keeps its state alive while another
///   Tab is shown, and its data is cached by non auto-dispose providers, so
///   switching Tabs never causes a request.
/// * Owns its own app bar (the console shell has none, decision D1 of P-083).
///
/// The older daily-rollup screen (`AnalyticsScreen`, P-085) and its providers
/// are untouched; this screen replaces it only in the router.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import 'widgets/analytics_common_widgets.dart';
import 'widgets/analytics_period_bar.dart';
import 'widgets/content/analytics_content_section.dart';
import 'widgets/external/analytics_external_section.dart';
import 'widgets/orders/analytics_orders_section.dart';
import 'widgets/overview/analytics_overview_section.dart';
import 'widgets/products/analytics_products_section.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: CavalloAppBar(
          title: Text(l10n.consoleNavAnalytics),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(
                key: const ValueKey<String>('bi-tab-overview'),
                text: l10n.biTabOverview,
              ),
              Tab(
                key: const ValueKey<String>('bi-tab-products'),
                text: l10n.biTabProducts,
              ),
              Tab(
                key: const ValueKey<String>('bi-tab-orders'),
                text: l10n.biTabOrders,
              ),
              Tab(
                key: const ValueKey<String>('bi-tab-content'),
                text: l10n.biTabContent,
              ),
              Tab(
                key: const ValueKey<String>('bi-tab-external'),
                text: l10n.biTabExternal,
              ),
            ],
          ),
        ),
        body: const Column(
          children: <Widget>[
            AnalyticsPeriodBar(),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  AnalyticsKeepAlive(child: AnalyticsOverviewSection()),
                  AnalyticsKeepAlive(child: AnalyticsProductsSection()),
                  AnalyticsKeepAlive(child: AnalyticsOrdersSection()),
                  AnalyticsKeepAlive(child: AnalyticsContentSection()),
                  AnalyticsKeepAlive(child: AnalyticsExternalSection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
