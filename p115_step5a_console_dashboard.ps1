# =====================================================================
# P-115 STEP 5A - Business Console: shared chip/row, dashboard cards, shell labels, product list
# Run from PowerShell (Windows PowerShell 5.1 or PowerShell 7).
# Repo: D:\Cavallo\social_commerce_app  (branch part-111)
#
# What it does:
#   CREATE  lib\core\widgets\app_status_chip.dart
#   CREATE  lib\features\business_console\presentation\console_row.dart
#   CREATE  lib\features\business_console\presentation\console_dashboard.dart
#   CREATE  test\features\business_console\presentation\console_restyle_test.dart
#   REPLACE lib\features\business_console\presentation\business_console_shell.dart
#   REPLACE lib\features\products\presentation\product_list_screen.dart
#   EDIT    lib\routing\app_router.dart (dashboard passed as product list header)
#   APPEND  20 keys (console*) to lib\l10n\app_en.arb and lib\l10n\app_ar.arb
#   RUN     flutter gen-l10n  +  dart format on the touched Dart files
#
# Safe to run twice: ARB keys are skipped when present; replaced files are
# backed up OUTSIDE the repo ($env:TEMP\p115_step5a_backup).
# This file is ASCII only on purpose (Arabic is written as \uXXXX in the ARB).
# =====================================================================
param(
  [string]$Repo = 'D:\Cavallo\social_commerce_app'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $Repo 'pubspec.yaml'))) {
  throw "pubspec.yaml not found in $Repo - pass -Repo with the right path."
}
Set-Location $Repo

$branch = (git branch --show-current).Trim()
Write-Host "Branch: $branch"
if ($branch -ne 'part-111') {
  throw "Expected branch part-111, found '$branch'. Run: git checkout part-111"
}
foreach ($must in @(
  'lib\core\theme\app_colors.dart',
  'lib\core\widgets\app_shimmer_box.dart',
  'lib\core\l10n\formatters.dart',
  'lib\core\l10n\l10n_context.dart',
  'lib\features\products\presentation\own_products_provider.dart',
  'lib\features\content\presentation\own_content_provider.dart',
  'lib\features\stories\presentation\own_stories_provider.dart',
  'lib\features\business_console\presentation\analytics_provider.dart'
)) {
  if (-not (Test-Path $must)) { throw "Missing prerequisite file: $must" }
}

$backup = Join-Path $env:TEMP 'p115_step5a_backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-DartFile([string]$RelPath, [string]$Content) {
  $full = Join-Path $Repo $RelPath
  $dir = Split-Path $full -Parent
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  if (Test-Path $full) {
    Copy-Item $full (Join-Path $backup ((Split-Path $full -Leaf) + '.bak')) -Force
  }
  # The project's Dart files use CRLF.
  $text = ($Content -replace "`r`n", "`n") -replace "`n", "`r`n"
  [System.IO.File]::WriteAllText($full, $text, $utf8NoBom)
  Write-Host "  wrote $RelPath"
}

function Add-ArbEntries([string]$RelPath, [string]$FirstKey, [string]$Entries) {
  $full = Join-Path $Repo $RelPath
  $raw = [System.IO.File]::ReadAllText($full)
  if ($raw.Contains('"' + $FirstKey + '"')) {
    Write-Host "  $RelPath already has $FirstKey - skipped"
    return
  }
  Copy-Item $full (Join-Path $backup ((Split-Path $full -Leaf) + '.bak')) -Force
  $idx = $raw.LastIndexOf('}')
  if ($idx -lt 0) { throw "$RelPath has no closing brace" }
  $head = $raw.Substring(0, $idx).TrimEnd()
  $body = ($Entries -replace "`r`n", "`n").TrimEnd()
  $new = $head + ",`n" + $body + "`n}`n"
  [System.IO.File]::WriteAllText($full, $new, $utf8NoBom)
  # Fail early if the JSON is broken.
  $null = Get-Content $full -Raw | ConvertFrom-Json
  Write-Host "  appended keys to $RelPath"
}

$appStatusChip = @'
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-115 (STEP 5): the one status chip of the app.
///
/// Meaning never rides on colour alone: every chip carries an icon AND a
/// text label. The label wraps instead of being cut with "...", so a rejection
/// reason is always fully readable by the business.
enum AppStatusTone { success, warning, danger, neutral }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final (Color background, Color foreground) = switch (tone) {
      AppStatusTone.success => (colors.successSubtle, colors.successText),
      AppStatusTone.warning => (colors.warningSubtle, colors.warningText),
      AppStatusTone.danger => (colors.dangerSubtle, colors.dangerText),
      AppStatusTone.neutral => (colors.surfaceVariant, colors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: foreground),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'@
Write-DartFile 'lib\core\widgets\app_status_chip.dart' $appStatusChip

$consoleRow = @'
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Part P-115 (STEP 5): the single row anatomy of every Business Console list
/// (products, posts/reels, stories).
///
/// thumbnail | title, meta lines, status chip, footer | trailing actions
///
/// Presentation only: it knows nothing about providers or moderation rules.
class ConsoleRow extends StatelessWidget {
  const ConsoleRow({
    super.key,
    required this.leading,
    required this.title,
    this.titleMaxLines = 1,
    this.meta = const <Widget>[],
    this.status,
    this.footer,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final int titleMaxLines;
  final List<Widget> meta;
  final Widget? status;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget? statusWidget = status;
    final Widget? footerWidget = footer;
    final Widget? trailingWidget = trailing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final Widget line in meta)
                  Padding(padding: const EdgeInsets.only(top: 4), child: line),
                if (statusWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: statusWidget,
                  ),
                if (footerWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: footerWidget,
                  ),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}

/// 56 px rounded thumbnail shared by the console rows.
///
/// [url] null or empty shows [placeholderIcon]; a failed load shows a broken
/// image icon. Colours come from the tokens only.
class ConsoleThumbnail extends StatelessWidget {
  const ConsoleThumbnail({
    super.key,
    required this.url,
    required this.placeholderIcon,
  });

  final String? url;
  final IconData placeholderIcon;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget box(IconData icon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.textSecondary),
      );
    }

    final String? value = url;
    if (value == null || value.isEmpty) {
      return box(placeholderIcon);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            box(Icons.broken_image_outlined),
      ),
    );
  }
}
'@
Write-DartFile 'lib\features\business_console\presentation\console_row.dart' $consoleRow

$consoleDashboard = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../routing/route_names.dart';
import '../../content/presentation/own_content_provider.dart';
import '../../products/presentation/own_products_provider.dart';
import '../../stories/domain/own_story_entity.dart';
import '../../stories/presentation/own_stories_provider.dart';
import '../../stories/presentation/story_list_screen.dart'
    show storyListClockProvider;
import 'analytics_provider.dart';
import 'analytics_summary.dart';

/// Part P-115 (STEP 5): the Business Console dashboard - one compact card per
/// console area (products, posts/reels, stories, analytics) with a clear count.
///
/// READ-ONLY: it only watches the providers the four tabs already use and never
/// calls a notifier method. Each card shows a skeleton while loading and a dash
/// when its own data failed, so one failing area never hides the others.
/// Tapping a card jumps to that tab (named routes of the P-083 shell contract;
/// nothing happens when there is no router, e.g. in a plain widget test).
class ConsoleDashboardCards extends ConsumerWidget {
  const ConsoleDashboardCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final AsyncValue<int> products = ref
        .watch(ownProductsProvider)
        .whenData((items) => items.length);
    final AsyncValue<int> content = ref
        .watch(ownContentProvider)
        .whenData((items) => items.length);
    final DateTime now = ref.watch(storyListClockProvider)();
    final AsyncValue<int> stories = ref
        .watch(ownStoriesProvider)
        .whenData(
          (items) =>
              items.where((story) {
                final status = story.displayStatus(now);
                return status == OwnStoryDisplayStatus.published ||
                    status == OwnStoryDisplayStatus.pending;
              }).length,
        );
    final int days = ref.watch(analyticsRangeDaysProvider);
    final AsyncValue<int> followers = ref
        .watch(analyticsStatsProvider)
        .whenData((rows) => sumDailyStats(rows).newFollowers);

    final List<Widget> cards = <Widget>[
      _DashboardCard(
        key: const Key('console-dash-products'),
        icon: Icons.inventory_2_outlined,
        label: l10n.consoleNavProducts,
        value: products,
        routeName: RouteNames.productList,
      ),
      _DashboardCard(
        key: const Key('console-dash-content'),
        icon: Icons.dynamic_feed_outlined,
        label: l10n.consoleNavContent,
        value: content,
        routeName: RouteNames.contentList,
      ),
      _DashboardCard(
        key: const Key('console-dash-stories'),
        icon: Icons.auto_stories_outlined,
        label: l10n.consoleDashStories,
        value: stories,
        routeName: RouteNames.storyList,
      ),
      _DashboardCard(
        key: const Key('console-dash-analytics'),
        icon: Icons.insights_outlined,
        label: l10n.consoleDashFollowers,
        caption: l10n.consoleDashRange(days),
        value: followers,
        routeName: RouteNames.businessAnalytics,
      ),
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.routeName,
    this.caption,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> value;
  final String routeName;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);
    final String? captionText = caption;

    final TextStyle? valueStyle = text.titleLarge?.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final Widget valueWidget = switch (value) {
      AsyncData(value: final int count) => Text(
        formatters.compactCount(count),
        style: valueStyle,
      ),
      AsyncError() => Text(l10n.consoleDashValueUnavailable, style: valueStyle),
      _ => const AppShimmerBox(width: 40, height: 22),
    };

    return SizedBox(
      width: 148,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          onTap: () => GoRouter.maybeOf(context)?.goNamed(routeName),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, size: 18, color: colors.brandText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                valueWidget,
                if (captionText != null)
                  Text(
                    captionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
'@
Write-DartFile 'lib\features\business_console\presentation\console_dashboard.dart' $consoleDashboard

$consoleShell = @'
// lib/features/business_console/presentation/business_console_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../stories/presentation/story_upload_queue_provider.dart';
import '../../stories/presentation/story_upload_status_banner.dart';

/// Part P-083 - the Business Console navigational home.
///
/// Wraps the four branches of the `/business-console`
/// `StatefulShellRoute.indexedStack` (wired in `app_router.dart`):
///
/// | index | label        | destination key                    |
/// |-------|--------------|------------------------------------|
/// | 0     | Products     | `business-console-nav-products`    |
/// | 1     | Posts/Reels  | `business-console-nav-content`     |
/// | 2     | Stories      | `business-console-nav-stories`     |
/// | 3     | Analytics    | `business-console-nav-analytics`   |
///
/// Order and keys are the P-083 shared contract - do not change them.
/// The LABELS are localized since P-115 STEP 5 (English text is unchanged).
///
/// ### Decisions (unchanged since P-083)
///
/// * No AppBar here: each branch root keeps its own AppBar.
/// * The story upload banner lives here, above every tab. While uploads
///   exist it is wrapped in a top SafeArea and the branch content is told the
///   top inset is already consumed.
/// * Stable tree: the Column always has the same two children and the
///   MediaQuery.removePadding wrapper is always present, so the banner
///   appearing never remounts [navigationShell] or discards tab state.
/// * No access control here: the router's redirect owns that.
class BusinessConsoleShell extends ConsumerWidget {
  const BusinessConsoleShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasUploads = ref.watch(
      storyUploadQueueProvider.select((tasks) => tasks.isNotEmpty),
    );

    return Scaffold(
      body: Column(
        children: [
          if (hasUploads)
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StoryUploadStatusBanner(),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: hasUploads,
              child: navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('business-console-nav-bar'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected:
            (index) => navigationShell.goBranch(
              index,
              // Tapping the tab you are already on pops it back to its
              // branch root, the standard bottom-nav behaviour.
              initialLocation: index == navigationShell.currentIndex,
            ),
        destinations: [
          NavigationDestination(
            key: const Key('business-console-nav-products'),
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: l10n.consoleNavProducts,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-content'),
            icon: const Icon(Icons.dynamic_feed_outlined),
            selectedIcon: const Icon(Icons.dynamic_feed),
            label: l10n.consoleNavContent,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-stories'),
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: l10n.consoleNavStories,
          ),
          NavigationDestination(
            key: const Key('business-console-nav-analytics'),
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l10n.consoleNavAnalytics,
          ),
        ],
      ),
    );
  }
}
'@
Write-DartFile 'lib\features\business_console\presentation\business_console_shell.dart' $consoleShell

$productList = @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../business_console/presentation/console_row.dart';
import '../domain/product_entity.dart';
import 'own_products_provider.dart';

/// Part P-033: the signed-in Business account's own products
/// (`ownProductsProvider`), each with Edit/Delete, plus a "Create New" action.
/// (The long design notes of P-033 live in git history.)
///
/// Navigation is injected ([onCreateNew], [onEditProduct]) so the screen is
/// testable without a router - unchanged.
///
/// Part P-115 (STEP 5) restyle, presentation only:
/// * row = the shared `ConsoleRow` anatomy, status as `AppStatusChip`,
///   Delete in the danger colour (the confirmation dialog is kept);
/// * every string is localized;
/// * an optional [header] (the console dashboard cards, passed by the router)
///   sits above the list. It is null in plain tests.
///
/// No provider, notifier call or callback changed.
class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({
    super.key,
    required this.onCreateNew,
    required this.onEditProduct,
    this.header,
  });

  /// Invoked when the user taps the "Create New" action.
  final VoidCallback onCreateNew;

  /// Invoked when the user taps a product's Edit action.
  final void Function(Product product) onEditProduct;

  /// Optional widget shown above the list / empty / error states.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(ownProductsProvider);
    final Widget? headerWidget = header;

    final Widget content = switch (productsAsync) {
      AsyncData(value: final products) when products.isEmpty =>
        EmptyStateWidget(
          message: l10n.consoleProductsEmpty,
          icon: Icons.inventory_2_outlined,
        ),
      AsyncData(value: final products) => _ProductListView(
        products: products,
        onEditProduct: onEditProduct,
      ),
      AsyncError(:final error) => _LoadErrorView(error: error),
      _ => const LoadingIndicator(),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consoleProductsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateNew,
        icon: const Icon(Icons.add),
        label: Text(l10n.consoleProductsCreate),
      ),
      body:
          headerWidget == null
              ? content
              : Column(
                children: [
                  headerWidget,
                  Expanded(child: content),
                ],
              ),
    );
  }
}

/// Extracts a human-readable message from a thrown failure (both the bare
/// [ApiFailure] shape of test fakes and the real DioException shape).
String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: _apiFailureMessage(
        error,
        fallback: context.l10n.consoleProductsLoadFailed,
      ),
      onRetry: () => ref.read(ownProductsProvider.notifier).refreshProducts(),
    );
  }
}

class _ProductListView extends ConsumerWidget {
  const _ProductListView({
    required this.products,
    required this.onEditProduct,
  });

  final List<Product> products;
  final void Function(Product product) onEditProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownProductsProvider.notifier).refreshProducts(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return _ProductListItem(
            product: product,
            onEdit: () => onEditProduct(product),
          );
        },
      ),
    );
  }
}

class _ProductListItem extends ConsumerWidget {
  const _ProductListItem({required this.product, required this.onEdit});

  final Product product;
  final VoidCallback onEdit;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final danger = context.appColors.danger;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.consoleProductsDeleteTitle),
            content: Text(l10n.consoleProductsDeleteBody(product.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.consoleCancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: danger),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.consoleDelete),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(ownProductsProvider.notifier).deleteProduct(product.id);
    } catch (error) {
      if (!context.mounted) return;
      final message = _apiFailureMessage(
        error,
        fallback: l10n.consoleProductsDeleteFailed,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final variantCount = product.variants.length;

    return ConsoleRow(
      leading: ConsoleThumbnail(
        url: product.imageUrl,
        placeholderIcon: Icons.inventory_2_outlined,
      ),
      title: product.name,
      meta: [
        Text(
          '${product.price} ${product.currency.toWire()}',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        if (variantCount > 0)
          Text(
            l10n.consoleProductVariants(variantCount),
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
      ],
      status:
          product.isActive
              ? null
              : AppStatusChip(
                label: l10n.consoleProductInactive,
                icon: Icons.visibility_off_outlined,
                tone: AppStatusTone.neutral,
              ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: colors.textSecondary,
            tooltip: l10n.consoleEdit,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: colors.danger,
            tooltip: l10n.consoleDelete,
            onPressed: () => _confirmAndDelete(context, ref),
          ),
        ],
      ),
    );
  }
}
'@
Write-DartFile 'lib\features\products\presentation\product_list_screen.dart' $productList

$restyleTest = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_status_chip.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_console/presentation/console_dashboard.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/presentation/own_products_provider.dart';
import 'package:social_commerce_app/features/products/presentation/product_list_screen.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 5A): restyle checks for the Business Console dashboard,
/// the shared status chip and the product list header.
///
/// The behaviour tests (create, edit, delete, retry) stay in the P-033 test
/// files, which are unchanged. This file is ASCII only: Arabic text is read
/// from the generated localizations, never typed here.

class _FakeProducts extends OwnProductsNotifier {
  @override
  Future<List<Product>> build() async => const <Product>[];
}

class _FakeContent extends OwnContentNotifier {
  @override
  Future<List<ContentItem>> build() async => const <ContentItem>[];
}

class _FakeStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => const <OwnStory>[];
}

class _FailingStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => throw StateError('boom');
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool failingStories = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ownProductsProvider.overrideWith(_FakeProducts.new),
        ownContentProvider.overrideWith(_FakeContent.new),
        ownStoriesProvider.overrideWith(
          failingStories ? _FailingStories.new : _FakeStories.new,
        ),
        analyticsStatsProvider.overrideWith((ref) async => <DailyStats>[]),
      ],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppStatusChip', () {
    testWidgets('always shows an icon and a text label (not colour alone)', (
      tester,
    ) async {
      for (final tone in AppStatusTone.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: AppStatusChip(
                label: 'label-${tone.name}',
                icon: Icons.info_outline,
                tone: tone,
              ),
            ),
          ),
        );
        expect(find.text('label-${tone.name}'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      }
    });

    testWidgets('a long reason wraps instead of being cut off', (tester) async {
      const reason =
          'Rejected: the picture is blurry and the price is missing from '
          'the caption, please fix both and send it again';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 200,
              child: AppStatusChip(
                label: reason,
                icon: Icons.cancel_outlined,
                tone: AppStatusTone.danger,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(reason));
      expect(text.overflow, isNull);
      expect(tester.getSize(find.text(reason)).height, greaterThan(30));
    });
  });

  group('ConsoleDashboardCards', () {
    testWidgets('shows the four areas with their counts (English, light)', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: ConsoleDashboardCards()));
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('console-dash-products')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-content')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-stories')), findsOneWidget);
      expect(find.byKey(const Key('console-dash-analytics')), findsOneWidget);
      expect(find.text(l10n.consoleNavProducts), findsOneWidget);
      expect(find.text(l10n.consoleDashFollowers), findsOneWidget);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('localized in Arabic and dark theme', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ConsoleDashboardCards()),
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );
      final l10n = lookupAppLocalizations(const Locale('ar'));

      expect(find.text(l10n.consoleNavProducts), findsOneWidget);
      expect(find.text(l10n.consoleDashStories), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one failing area shows a dash and the others still show', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: ConsoleDashboardCards()),
        failingStories: true,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text(l10n.consoleDashValueUnavailable), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });
  });

  group('ProductListScreen header', () {
    testWidgets('renders the optional header above the empty state', (
      tester,
    ) async {
      await _pump(
        tester,
        ProductListScreen(
          onCreateNew: () {},
          onEditProduct: (_) {},
          header: const Text('header-probe'),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text('header-probe'), findsOneWidget);
      expect(find.text(l10n.consoleProductsEmpty), findsOneWidget);
    });

    testWidgets('Arabic title and create label', (tester) async {
      await _pump(
        tester,
        ProductListScreen(onCreateNew: () {}, onEditProduct: (_) {}),
        locale: const Locale('ar'),
      );
      final l10n = lookupAppLocalizations(const Locale('ar'));

      expect(find.text(l10n.consoleProductsTitle), findsOneWidget);
      expect(find.text(l10n.consoleProductsCreate), findsOneWidget);
    });
  });
}
'@
Write-DartFile 'test\features\business_console\presentation\console_restyle_test.dart' $restyleTest


# --- app_router.dart: pass the dashboard as the product list header ---------
$routerPath = Join-Path $Repo 'lib\routing\app_router.dart'
$router = [System.IO.File]::ReadAllText($routerPath)
if ($router.Contains('ConsoleDashboardCards')) {
  Write-Host '  app_router.dart already wired - skipped'
} else {
  $nl = if ($router.Contains("`r`n")) { "`r`n" } else { "`n" }
  $anchor = "import '../features/business_console/presentation/business_console_shell.dart';"
  if (-not $router.Contains($anchor)) { throw 'router import anchor not found' }
  $pattern = '(ProductListScreen\()(\r?\n)(\s+)(onCreateNew:)'
  if ([regex]::Matches($router, $pattern).Count -ne 1) {
    throw 'Expected exactly one "ProductListScreen(" call in app_router.dart - stop and send me the file.'
  }
  Copy-Item $routerPath (Join-Path $backup 'app_router.dart.bak') -Force
  $router = $router.Replace($anchor, $anchor + $nl + "import '../features/business_console/presentation/console_dashboard.dart';")
  $router = [regex]::Replace($router, $pattern, '$1$2$3header: const ConsoleDashboardCards(),$2$3$4')
  [System.IO.File]::WriteAllText($routerPath, $router, $utf8NoBom)
  Write-Host '  wired ConsoleDashboardCards into lib\routing\app_router.dart'
}

$arbEn = @'
  "consoleNavProducts": "Products",
  "@consoleNavProducts": {
    "description": "Business console tab / dashboard card: products."
  },
  "consoleNavContent": "Posts/Reels",
  "@consoleNavContent": {
    "description": "Business console tab / dashboard card: posts and reels."
  },
  "consoleNavStories": "Stories",
  "@consoleNavStories": {
    "description": "Business console tab and screen title: stories."
  },
  "consoleNavAnalytics": "Analytics",
  "@consoleNavAnalytics": {
    "description": "Business console tab: analytics."
  },
  "consoleDashStories": "Active stories",
  "@consoleDashStories": {
    "description": "Dashboard card label: stories that are published or pending review."
  },
  "consoleDashFollowers": "New followers",
  "@consoleDashFollowers": {
    "description": "Dashboard card label: new followers in the selected analytics range."
  },
  "consoleDashRange": "{days, plural, one{last day} other{last {days} days}}",
  "@consoleDashRange": {
    "description": "Dashboard card caption: the analytics range. days is the exact number (it picks the plural form).",
    "placeholders": {
      "days": {
        "type": "int"
      }
    }
  },
  "consoleDashValueUnavailable": "\u2013",
  "@consoleDashValueUnavailable": {
    "description": "Dashboard card value shown when that area failed to load."
  },
  "consoleProductsTitle": "My Products",
  "@consoleProductsTitle": {
    "description": "App bar title of the business product list."
  },
  "consoleProductsCreate": "Create New",
  "@consoleProductsCreate": {
    "description": "Extended button on the product list."
  },
  "consoleProductsEmpty": "No products yet.\nTap \"Create New\" to add your first product.",
  "@consoleProductsEmpty": {
    "description": "Empty state of the product list."
  },
  "consoleProductsLoadFailed": "Could not load your products.",
  "@consoleProductsLoadFailed": {
    "description": "Fallback error of the product list."
  },
  "consoleProductsDeleteTitle": "Delete product?",
  "@consoleProductsDeleteTitle": {
    "description": "Title of the delete product confirmation dialog."
  },
  "consoleProductsDeleteBody": "This will remove \"{name}\" from your products. This cannot be undone.",
  "@consoleProductsDeleteBody": {
    "description": "Body of the delete product dialog. name is the product name.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "consoleProductsDeleteFailed": "Could not delete this product.",
  "@consoleProductsDeleteFailed": {
    "description": "Snackbar when deleting a product fails."
  },
  "consoleProductVariants": "{count, plural, one{{count} variant} other{{count} variants}}",
  "@consoleProductVariants": {
    "description": "Variant count under a product row. count is the exact number.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "consoleProductInactive": "Inactive",
  "@consoleProductInactive": {
    "description": "Status chip of a hidden product."
  },
  "consoleEdit": "Edit",
  "@consoleEdit": {
    "description": "Tooltip of an edit icon in console rows."
  },
  "consoleDelete": "Delete",
  "@consoleDelete": {
    "description": "Tooltip and confirm button of a delete action in the console."
  },
  "consoleCancel": "Cancel",
  "@consoleCancel": {
    "description": "Cancel button of console dialogs."
  }
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'consoleNavProducts' $arbEn

$arbAr = @'
  "consoleNavProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a",
  "consoleNavContent": "\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0648\u0627\u0644\u0631\u064a\u0644\u0632",
  "consoleNavStories": "\u0627\u0644\u0642\u0635\u0635",
  "consoleNavAnalytics": "\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a",
  "consoleDashStories": "\u0627\u0644\u0642\u0635\u0635 \u0627\u0644\u0646\u0634\u0637\u0629",
  "consoleDashFollowers": "\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u062c\u062f\u062f",
  "consoleDashRange": "{days, plural, zero{\u0622\u062e\u0631 {days} \u064a\u0648\u0645} one{\u0622\u062e\u0631 \u064a\u0648\u0645} two{\u0622\u062e\u0631 \u064a\u0648\u0645\u064a\u0646} few{\u0622\u062e\u0631 {days} \u0623\u064a\u0627\u0645} many{\u0622\u062e\u0631 {days} \u064a\u0648\u0645\u064b\u0627} other{\u0622\u062e\u0631 {days} \u064a\u0648\u0645}}",
  "consoleDashValueUnavailable": "\u2013",
  "consoleProductsTitle": "\u0645\u0646\u062a\u062c\u0627\u062a\u064a",
  "consoleProductsCreate": "\u0625\u0646\u0634\u0627\u0621 \u062c\u062f\u064a\u062f",
  "consoleProductsEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0628\u0639\u062f.\n\u0627\u0636\u063a\u0637 \u00ab\u0625\u0646\u0634\u0627\u0621 \u062c\u062f\u064a\u062f\u00bb \u0644\u0625\u0636\u0627\u0641\u0629 \u0623\u0648\u0644 \u0645\u0646\u062a\u062c \u0644\u0643.",
  "consoleProductsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u0646\u062a\u062c\u0627\u062a\u0643.",
  "consoleProductsDeleteTitle": "\u062d\u0630\u0641 \u0627\u0644\u0645\u0646\u062a\u062c\u061f",
  "consoleProductsDeleteBody": "\u0633\u064a\u062a\u0645 \u0625\u0632\u0627\u0644\u0629 \u00ab{name}\u00bb \u0645\u0646 \u0645\u0646\u062a\u062c\u0627\u062a\u0643. \u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u062a\u0631\u0627\u062c\u0639 \u0639\u0646 \u0647\u0630\u0627 \u0627\u0644\u0625\u062c\u0631\u0627\u0621.",
  "consoleProductsDeleteFailed": "\u062a\u0639\u0630\u0651\u0631 \u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062a\u062c.",
  "consoleProductVariants": "{count, plural, zero{{count} \u062e\u064a\u0627\u0631} one{\u062e\u064a\u0627\u0631 \u0648\u0627\u062d\u062f} two{\u062e\u064a\u0627\u0631\u0627\u0646} few{{count} \u062e\u064a\u0627\u0631\u0627\u062a} many{{count} \u062e\u064a\u0627\u0631\u064b\u0627} other{{count} \u062e\u064a\u0627\u0631}}",
  "consoleProductInactive": "\u063a\u064a\u0631 \u0646\u0634\u0637",
  "consoleEdit": "\u062a\u0639\u062f\u064a\u0644",
  "consoleDelete": "\u062d\u0630\u0641",
  "consoleCancel": "\u0625\u0644\u063a\u0627\u0621"
'@
Add-ArbEntries 'lib\l10n\app_ar.arb' 'consoleNavProducts' $arbAr

Write-Host ''
Write-Host 'Generating localizations (flutter gen-l10n) ...'
flutter gen-l10n
if ($LASTEXITCODE -ne 0) { throw 'flutter gen-l10n failed' }

Write-Host 'Formatting touched Dart files ...'
dart format `
  lib\core\widgets\app_status_chip.dart `
  lib\features\business_console\presentation\console_row.dart `
  lib\features\business_console\presentation\console_dashboard.dart `
  lib\features\business_console\presentation\business_console_shell.dart `
  lib\features\products\presentation\product_list_screen.dart `
  test\features\business_console\presentation\console_restyle_test.dart
if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }

Write-Host ''
Write-Host 'git status:'
git status --short
Write-Host ''
Write-Host 'DONE. Backups: ' $backup
Write-Host 'Next: run the tests from the instructions (flutter analyze, then flutter test).'