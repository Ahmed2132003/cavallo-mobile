# =====================================================================
# P-115 STEP 4 - Notification Center + Notification Preferences restyle
# Run from PowerShell (Windows PowerShell 5.1 or PowerShell 7).
# Repo: D:\Cavallo\social_commerce_app  (branch part-111)
#
# What it does:
#   CREATE  lib\features\notifications\presentation\notification_grouping.dart
#   CREATE  test\features\notifications\presentation\notification_restyle_test.dart
#   REPLACE lib\features\notifications\presentation\notification_center_screen.dart
#   REPLACE lib\features\notifications\presentation\notification_preferences_screen.dart
#   APPEND  20 keys (notif*) to lib\l10n\app_en.arb and lib\l10n\app_ar.arb
#   RUN     flutter gen-l10n  +  dart format on the touched Dart files
#
# Safe to run twice: ARB keys are skipped when present; replaced files are
# backed up OUTSIDE the repo ($env:TEMP\p115_step4_backup).
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
  'lib\features\notifications\presentation\notification_list_provider.dart'
)) {
  if (-not (Test-Path $must)) { throw "Missing prerequisite file: $must" }
}

$backup = Join-Path $env:TEMP 'p115_step4_backup'
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

$notificationgrouping = @'
import '../domain/app_notification.dart';

/// Part P-115 (STEP 4): the three recency sections of the notification
/// center. Presentation only: grouping never changes the list provider, the
/// order of the items, or what a tap does.
enum NotificationSection { today, thisWeek, earlier }

/// One section with its items, in the same order the provider holds them.
class NotificationGroup {
  const NotificationGroup({required this.section, required this.items});

  final NotificationSection section;
  final List<AppNotification> items;
}

/// Number of calendar days (device local time) that separate [createdAt]
/// from [now]. Both are reduced to their local calendar date first, and the
/// difference is taken between two UTC midnights, so a daylight-saving day
/// of 23 or 25 hours can never shift a notification into the wrong section.
int notificationAgeInDays(DateTime createdAt, DateTime now) {
  final DateTime local = createdAt.toLocal();
  final DateTime current = now.toLocal();
  final DateTime day = DateTime.utc(local.year, local.month, local.day);
  final DateTime today = DateTime.utc(current.year, current.month, current.day);
  return today.difference(day).inDays;
}

/// Today = the same calendar day (or a time slightly in the future because
/// of a small clock difference with the server). This week = 1 to 6 days
/// ago. Earlier = 7 days or more.
NotificationSection notificationSectionFor(DateTime createdAt, DateTime now) {
  final int age = notificationAgeInDays(createdAt, now);
  if (age <= 0) {
    return NotificationSection.today;
  }
  if (age < 7) {
    return NotificationSection.thisWeek;
  }
  return NotificationSection.earlier;
}

/// Splits [items] into Today / This week / Earlier. Sections come out in that
/// fixed order, empty sections are left out, and the order of the items
/// inside a section is the order they came in.
List<NotificationGroup> groupNotificationsByRecency(
  List<AppNotification> items,
  DateTime now,
) {
  final Map<NotificationSection, List<AppNotification>> buckets =
      <NotificationSection, List<AppNotification>>{
        for (final NotificationSection section in NotificationSection.values)
          section: <AppNotification>[],
      };
  for (final AppNotification item in items) {
    buckets[notificationSectionFor(item.createdAt, now)]!.add(item);
  }
  return <NotificationGroup>[
    for (final NotificationSection section in NotificationSection.values)
      if (buckets[section]!.isNotEmpty)
        NotificationGroup(section: section, items: buckets[section]!),
  ];
}
'@
Write-DartFile 'lib\features\notifications\presentation\notification_grouping.dart' $notificationgrouping

$notificationcenterscreen = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../domain/app_notification.dart';
import 'notification_grouping.dart';
import 'notification_list_provider.dart';
import 'notification_navigator.dart';

/// Part P-082 (STEP 4): the notification center (`/notifications`),
/// replacing the P-007 placeholder.
///
/// * Paginated list (scroll past 80% loads the next page, same pattern as
///   `HomeFeedScreen`) with pull-to-refresh.
/// * Unread rows are visually distinct: bold title, a dot and a tinted
///   background.
/// * Tapping a row starts `markAsRead` (not awaited, so navigation is
///   never delayed by a network round trip; a failed mark-read never
///   blocks navigation) and then navigates through
///   [NotificationNavigator.openNotification], the single navigation
///   point shared with the foreground banner and push taps. This screen
///   never builds a route itself.
///
/// Part P-115 (STEP 4): restyle only. Rows are grouped into Today / This
/// week / Earlier ([groupNotificationsByRecency]), use the design tokens
/// (`context.appColors`), hairline dividers, a skeleton loader and
/// localized text. The provider, the paging, the mark-read call and the
/// navigation call are exactly the P-082 ones.
///
/// The backend notification carries no actor avatar and no thumbnail
/// (`AppNotification` has exactly the eight serializer fields), so the
/// leading circle is the notification-type icon. Adding an avatar or a
/// thumbnail needs a backend field and is out of scope for P-115.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent * 0.8) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(notificationListProvider.notifier).loadMore();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.notifLoadMoreFailed)),
        );
    }
  }

  void _onTapNotification(AppNotification notification) {
    final navigator = ref.read(notificationNavigatorProvider);
    if (!notification.isRead) {
      // Never throws; returns false on failure, which must not block
      // navigation.
      unawaited(
        ref.read(notificationListProvider.notifier).markAsRead(notification.id),
      );
    }
    unawaited(navigator.openNotification(notification));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifTitle),
        actions: [
          IconButton(
            key: const ValueKey('notification-preferences-button'),
            tooltip: context.l10n.notifSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed:
                () => unawaited(
                  context.pushNamed<void>(RouteNames.notificationPreferences),
                ),
          ),
        ],
      ),
      body: switch (listAsync) {
        AsyncData(value: final state) => _NotificationListBody(
          state: state,
          scrollController: _scrollController,
          onTap: _onTapNotification,
        ),
        AsyncError() => ErrorStateWidget(
          message: context.l10n.notifLoadFailed,
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        _ => const _NotificationSkeleton(),
      },
    );
  }
}

/// One line of the grouped list: a section header or a notification.
sealed class _Row {
  const _Row();
}

final class _HeaderRow extends _Row {
  const _HeaderRow(this.section);

  final NotificationSection section;
}

final class _ItemRow extends _Row {
  const _ItemRow(this.notification);

  final AppNotification notification;
}

class _NotificationListBody extends ConsumerWidget {
  const _NotificationListBody({
    required this.state,
    required this.scrollController,
    required this.onTap,
  });

  final NotificationListState state;
  final ScrollController scrollController;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() =>
        ref.read(notificationListProvider.notifier).refresh();

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 96),
            EmptyStateWidget(
              message: context.l10n.notifEmpty,
              icon: Icons.notifications_none_outlined,
            ),
          ],
        ),
      );
    }

    final List<_Row> rows = <_Row>[
      for (final NotificationGroup group in groupNotificationsByRecency(
        state.items,
        DateTime.now(),
      )) ...<_Row>[
        _HeaderRow(group.section),
        for (final AppNotification item in group.items) _ItemRow(item),
      ],
    ];
    final itemCount = rows.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          return switch (rows[index]) {
            _HeaderRow(:final section) => _SectionHeader(section: section),
            _ItemRow(:final notification) => _NotificationTile(
              key: ValueKey('notification-item-${notification.id}'),
              notification: notification,
              onTap: () => onTap(notification),
            ),
          };
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final NotificationSection section;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String label = switch (section) {
      NotificationSection.today => context.l10n.notifSectionToday,
      NotificationSection.thisWeek => context.l10n.notifSectionThisWeek,
      NotificationSection.earlier => context.l10n.notifSectionEarlier,
    };
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
        child: Text(
          label,
          key: ValueKey('notification-section-${section.name}'),
          style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  static const double _leadingSize = 44;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final bool unread = !notification.isRead;
    final AppFormatters formatters = AppFormatters(context.l10n);

    // Unread is carried by THREE signals, never by colour alone: the tinted
    // row, the bold title and the dot (which also has a semantic label).
    return Material(
      color: unread ? colors.brandSubtle : Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _leadingSize,
                    height: _leadingSize,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconFor(notification.notificationType),
                      size: 22,
                      color: unread ? colors.brandText : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (theme.textTheme.titleSmall ??
                                  const TextStyle())
                              .copyWith(
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w400,
                                color: colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatters.relativeTime(notification.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (unread)
                        Semantics(
                          label: context.l10n.notifUnreadLabel,
                          child: Container(
                            key: ValueKey(
                              'notification-unread-dot-${notification.id}',
                            ),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16 + _leadingSize + 12,
            color: colors.outline,
          ),
        ],
      ),
    );
  }
}

/// Skeleton shown while the first page loads (instead of a spinner).
class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.notifLoadingLabel,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder:
            (context, index) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              child: Row(
                children: [
                  const AppShimmerBox.circle(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmerBox(height: 14, width: 160),
                        SizedBox(height: 8),
                        AppShimmerBox(height: 12, width: double.infinity),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// Icon by the backend's `notification_type` (WHY the notification
/// exists). Unknown types get the generic bell.
IconData _iconFor(String notificationType) {
  if (notificationType.contains('follow')) return Icons.person_add_outlined;
  if (notificationType.contains('chat') ||
      notificationType.contains('message')) {
    return Icons.chat_bubble_outline;
  }
  if (notificationType.contains('comment')) {
    return Icons.mode_comment_outlined;
  }
  if (notificationType.contains('moderation')) {
    return Icons.shield_outlined;
  }
  return Icons.notifications_outlined;
}
'@
Write-DartFile 'lib\features\notifications\presentation\notification_center_screen.dart' $notificationcenterscreen

$notificationpreferencesscreen = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../domain/notification_preferences.dart';
import 'notification_preferences_provider.dart';

/// Part P-082 (STEP 5): the notification preferences screen.
///
/// Three switches, one per [NotificationCategory]. Each change goes
/// through [NotificationPreferencesNotifier.setEnabled], which flips the
/// switch immediately, sends ONE PATCH for that category only, and puts
/// that category back (then rethrows) if the request fails. This screen
/// only shows a message in that case.
///
/// `system_announcement` has no switch: it is always delivered, and the
/// footer says so.
///
/// Part P-115 (STEP 4): restyle only. The three switches sit in one rounded
/// group with hairline dividers, all colours come from the design tokens and
/// all text from the ARB files. The provider and the toggle logic are
/// unchanged, and each switch keeps its `notification-preference-<name>` key.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  static const List<({NotificationCategory category, IconData icon})> _tiles =
      <({NotificationCategory category, IconData icon})>[
        (category: NotificationCategory.chat, icon: Icons.chat_bubble_outline),
        (category: NotificationCategory.moderation, icon: Icons.shield_outlined),
        (category: NotificationCategory.social, icon: Icons.favorite_border),
      ];

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
    bool enabled,
  ) async {
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setEnabled(category, enabled);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.notifPrefsSaveFailed)),
        );
    }
  }

  String _titleFor(BuildContext context, NotificationCategory category) =>
      switch (category) {
        NotificationCategory.chat => context.l10n.notifPrefChatTitle,
        NotificationCategory.moderation =>
          context.l10n.notifPrefModerationTitle,
        NotificationCategory.social => context.l10n.notifPrefSocialTitle,
      };

  String _subtitleFor(BuildContext context, NotificationCategory category) =>
      switch (category) {
        NotificationCategory.chat => context.l10n.notifPrefChatSubtitle,
        NotificationCategory.moderation =>
          context.l10n.notifPrefModerationSubtitle,
        NotificationCategory.social => context.l10n.notifPrefSocialSubtitle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final AppColors colors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notifSettingsTitle)),
      body: switch (preferencesAsync) {
        AsyncData(value: final preferences) => ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
              child: Text(
                context.l10n.notifPrefsSectionHeader,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outline),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _tiles.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colors.outline,
                      ),
                    SwitchListTile(
                      key: ValueKey(
                        'notification-preference-${_tiles[i].category.name}',
                      ),
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        16,
                        4,
                      ),
                      secondary: Icon(
                        _tiles[i].icon,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        _titleFor(context, _tiles[i].category),
                        style: (textTheme.titleSmall ?? const TextStyle())
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                      subtitle: Text(
                        _subtitleFor(context, _tiles[i].category),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      value: preferences.isEnabled(_tiles[i].category),
                      onChanged:
                          (value) => unawaited(
                            _toggle(context, ref, _tiles[i].category, value),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
              child: Text(
                context.l10n.notifPrefsSystemFooter,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        AsyncError() => ErrorStateWidget(
          message: context.l10n.notifPrefsLoadFailed,
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        _ => const _PreferencesSkeleton(),
      },
    );
  }
}

/// Skeleton for the preferences group while the server values load.
class _PreferencesSkeleton extends StatelessWidget {
  const _PreferencesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.notifLoadingLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
        children: const [
          AppShimmerBox(height: 72, borderRadius: 16),
          SizedBox(height: 12),
          AppShimmerBox(height: 72, borderRadius: 16),
          SizedBox(height: 12),
          AppShimmerBox(height: 72, borderRadius: 16),
        ],
      ),
    );
  }
}
'@
Write-DartFile 'lib\features\notifications\presentation\notification_preferences_screen.dart' $notificationpreferencesscreen

$notificationrestyletest = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/notifications/data/notification_repository_impl.dart';
import 'package:social_commerce_app/features/notifications/domain/app_notification.dart';
import 'package:social_commerce_app/features/notifications/domain/notification_preferences.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_center_screen.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_grouping.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_preferences_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../fake_notification_repository.dart';

/// Part P-115 (STEP 4): restyle checks for the notification center and the
/// notification preferences. The behaviour tests (tap, mark-read, paging,
/// toggling) stay in the P-082 test files, which are unchanged.
///
/// This file is ASCII only: Arabic text is read from the generated
/// localizations, never typed here.

AppNotification _at(int id, DateTime createdAt, {bool isRead = false}) {
  return AppNotification(
    id: id,
    notificationType: 'new_follower',
    title: 'Title $id',
    body: 'Body $id',
    deepLinkType: 'business_profile',
    targetId: 7,
    isRead: isRead,
    createdAt: createdAt,
  );
}

Future<void> _pumpCenter(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationCenterScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreferences(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationPreferencesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _section(String name) =>
    find.byKey(ValueKey<String>('notification-section-$name'));

void main() {
  group('recency grouping', () {
    final DateTime now = DateTime(2026, 10, 9, 15, 0);

    test('section boundaries are calendar days, not 24-hour windows', () {
      expect(
        notificationSectionFor(DateTime(2026, 10, 9, 0, 1), now),
        NotificationSection.today,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 8, 23, 59), now),
        NotificationSection.thisWeek,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 3, 8, 0), now),
        NotificationSection.thisWeek,
      );
      expect(
        notificationSectionFor(DateTime(2026, 10, 2, 23, 0), now),
        NotificationSection.earlier,
      );
    });

    test('a time slightly in the future still counts as today', () {
      expect(
        notificationSectionFor(DateTime(2026, 10, 9, 15, 5), now),
        NotificationSection.today,
      );
    });

    test('sections are ordered, empty ones are left out, order is kept', () {
      final List<AppNotification> items = <AppNotification>[
        _at(1, DateTime(2026, 9, 1)),
        _at(2, DateTime(2026, 10, 9, 14)),
        _at(3, DateTime(2026, 10, 8, 10)),
        _at(4, DateTime(2026, 10, 9, 9)),
      ];

      final List<NotificationGroup> groups = groupNotificationsByRecency(
        items,
        now,
      );

      expect(groups.map((NotificationGroup g) => g.section), <NotificationSection>[
        NotificationSection.today,
        NotificationSection.thisWeek,
        NotificationSection.earlier,
      ]);
      expect(
        groups[0].items.map((AppNotification n) => n.id).toList(),
        <int>[2, 4],
      );
      expect(groups[1].items.single.id, 3);
      expect(groups[2].items.single.id, 1);

      final List<NotificationGroup> onlyToday = groupNotificationsByRecency(
        <AppNotification>[_at(5, DateTime(2026, 10, 9, 1))],
        now,
      );
      expect(onlyToday, hasLength(1));
      expect(onlyToday.single.section, NotificationSection.today);
    });

    test('an empty list gives no groups', () {
      expect(groupNotificationsByRecency(<AppNotification>[], now), isEmpty);
    });
  });

  group('notification center', () {
    testWidgets('shows Today / This week / Earlier headers in English', (
      tester,
    ) async {
      final DateTime now = DateTime.now();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[
            _at(1, now),
            _at(2, now.subtract(const Duration(days: 3))),
            _at(3, now.subtract(const Duration(days: 30))),
          ]),
        },
      );

      await _pumpCenter(tester, repository);

      expect(_section('today'), findsOneWidget);
      expect(_section('thisWeek'), findsOneWidget);
      expect(_section('earlier'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('notification-item-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('notification-item-3')), findsOneWidget);
    });

    testWidgets('a section with no items has no header', (tester) async {
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[_at(1, DateTime.now())]),
        },
      );

      await _pumpCenter(tester, repository);

      expect(_section('today'), findsOneWidget);
      expect(_section('thisWeek'), findsNothing);
      expect(_section('earlier'), findsNothing);
    });

    testWidgets('Arabic dark: RTL and localized headers, no errors', (
      tester,
    ) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[
            _at(1, DateTime.now()),
            _at(
              2,
              DateTime.now().subtract(const Duration(days: 40)),
              isRead: true,
            ),
          ]),
        },
      );

      await _pumpCenter(
        tester,
        repository,
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(
        Directionality.of(
          tester.element(find.byType(NotificationCenterScreen)),
        ),
        TextDirection.rtl,
      );
      expect(find.text(ar.notifSectionToday), findsOneWidget);
      expect(find.text(ar.notifSectionEarlier), findsOneWidget);
      expect(find.text(ar.notifTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic dark: localized empty state', (tester) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

      await _pumpCenter(
        tester,
        FakeNotificationRepository(
          pages: {null: fakePage(<AppNotification>[])},
        ),
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(find.text(ar.notifEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the unread dot carries a semantic label', (tester) async {
      final FakeNotificationRepository repository = FakeNotificationRepository(
        pages: {
          null: fakePage(<AppNotification>[_at(1, DateTime.now())]),
        },
      );

      await _pumpCenter(tester, repository);

      final Semantics wrapper = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('notification-unread-dot-1'),
              ),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(wrapper.properties.label, 'Unread');
    });
  });

  group('notification preferences', () {
    testWidgets('three switches in one group, English light', (tester) async {
      await _pumpPreferences(tester, FakeNotificationRepository());

      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('Chat messages'), findsOneWidget);
      expect(find.text('Content review'), findsOneWidget);
      expect(find.text('Social activity'), findsOneWidget);
      expect(
        find.text('Important system announcements are always delivered.'),
        findsOneWidget,
      );
    });

    testWidgets('Arabic dark: RTL, localized, and a toggle still saves', (
      tester,
    ) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final FakeNotificationRepository repository = FakeNotificationRepository();

      await _pumpPreferences(
        tester,
        repository,
        locale: const Locale('ar'),
        theme: AppTheme.dark,
      );

      expect(
        Directionality.of(
          tester.element(find.byType(NotificationPreferencesScreen)),
        ),
        TextDirection.rtl,
      );
      expect(find.text(ar.notifPrefChatTitle), findsOneWidget);
      expect(find.text(ar.notifPrefsSystemFooter), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('notification-preference-chat')),
      );
      await tester.pumpAndSettle();

      expect(repository.updateCalls, <({NotificationCategory category, bool enabled})>[
        (category: NotificationCategory.chat, enabled: false),
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}
'@
Write-DartFile 'test\features\notifications\presentation\notification_restyle_test.dart' $notificationrestyletest

$arbEn = @'
  "notifTitle": "Notifications",
  "@notifTitle": {
    "description": "Title of the notification center screen (app bar)."
  },
  "notifSettingsTitle": "Notification settings",
  "@notifSettingsTitle": {
    "description": "Title of the notification preferences screen and tooltip of the settings button in the notification center."
  },
  "notifLoadMoreFailed": "Could not load more notifications.",
  "@notifLoadMoreFailed": {
    "description": "Snackbar shown when the next page of notifications fails to load."
  },
  "notifLoadFailed": "Could not load your notifications.",
  "@notifLoadFailed": {
    "description": "Error message of the notification center when the first page fails to load."
  },
  "notifEmpty": "No notifications yet.",
  "@notifEmpty": {
    "description": "Empty state of the notification center."
  },
  "notifSectionToday": "Today",
  "@notifSectionToday": {
    "description": "Notification center section header for notifications received today."
  },
  "notifSectionThisWeek": "This week",
  "@notifSectionThisWeek": {
    "description": "Notification center section header for notifications from the previous 6 days."
  },
  "notifSectionEarlier": "Earlier",
  "@notifSectionEarlier": {
    "description": "Notification center section header for notifications older than a week."
  },
  "notifUnreadLabel": "Unread",
  "@notifUnreadLabel": {
    "description": "Screen reader label of the unread dot on a notification row."
  },
  "notifLoadingLabel": "Loading notifications",
  "@notifLoadingLabel": {
    "description": "Screen reader label of the notification skeleton loaders."
  },
  "notifPrefsSectionHeader": "Notify me about",
  "@notifPrefsSectionHeader": {
    "description": "Small header above the group of notification switches."
  },
  "notifPrefChatTitle": "Chat messages",
  "@notifPrefChatTitle": {
    "description": "Notification preference title: chat."
  },
  "notifPrefChatSubtitle": "New messages in your conversations.",
  "@notifPrefChatSubtitle": {
    "description": "Notification preference description: chat."
  },
  "notifPrefModerationTitle": "Content review",
  "@notifPrefModerationTitle": {
    "description": "Notification preference title: moderation."
  },
  "notifPrefModerationSubtitle": "When your content is approved or rejected.",
  "@notifPrefModerationSubtitle": {
    "description": "Notification preference description: moderation."
  },
  "notifPrefSocialTitle": "Social activity",
  "@notifPrefSocialTitle": {
    "description": "Notification preference title: social."
  },
  "notifPrefSocialSubtitle": "New followers, comments, likes, shares and ratings.",
  "@notifPrefSocialSubtitle": {
    "description": "Notification preference description: social."
  },
  "notifPrefsSaveFailed": "Could not save your preference. Please try again.",
  "@notifPrefsSaveFailed": {
    "description": "Snackbar shown when saving a notification preference fails."
  },
  "notifPrefsLoadFailed": "Could not load your notification settings.",
  "@notifPrefsLoadFailed": {
    "description": "Error message of the notification preferences screen."
  },
  "notifPrefsSystemFooter": "Important system announcements are always delivered.",
  "@notifPrefsSystemFooter": {
    "description": "Footer under the switches: system announcements cannot be turned off."
  }
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'notifTitle' $arbEn

$arbAr = @'
  "notifTitle": "\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a",
  "notifSettingsTitle": "\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a",
  "notifLoadMoreFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0632\u064a\u062f \u0645\u0646 \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a.",
  "notifLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0625\u0634\u0639\u0627\u0631\u0627\u062a\u0643.",
  "notifEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0625\u0634\u0639\u0627\u0631\u0627\u062a \u0628\u0639\u062f",
  "notifSectionToday": "\u0627\u0644\u064a\u0648\u0645",
  "notifSectionThisWeek": "\u0647\u0630\u0627 \u0627\u0644\u0623\u0633\u0628\u0648\u0639",
  "notifSectionEarlier": "\u0633\u0627\u0628\u0642\u064b\u0627",
  "notifUnreadLabel": "\u063a\u064a\u0631 \u0645\u0642\u0631\u0648\u0621",
  "notifLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a",
  "notifPrefsSectionHeader": "\u0623\u062e\u0637\u0631\u0646\u064a \u0628\u0634\u0623\u0646",
  "notifPrefChatTitle": "\u0631\u0633\u0627\u0626\u0644 \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0627\u062a",
  "notifPrefChatSubtitle": "\u0631\u0633\u0627\u0626\u0644 \u062c\u062f\u064a\u062f\u0629 \u0641\u064a \u0645\u062d\u0627\u062f\u062b\u0627\u062a\u0643.",
  "notifPrefModerationTitle": "\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u062a\u0648\u0649",
  "notifPrefModerationSubtitle": "\u0639\u0646\u062f \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0645\u062d\u062a\u0648\u0627\u0643 \u0623\u0648 \u0631\u0641\u0636\u0647.",
  "notifPrefSocialTitle": "\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u062c\u062a\u0645\u0627\u0639\u064a",
  "notifPrefSocialSubtitle": "\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0648\u062a\u0639\u0644\u064a\u0642\u0627\u062a \u0648\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0648\u0645\u0634\u0627\u0631\u0643\u0627\u062a \u0648\u062a\u0642\u064a\u064a\u0645\u0627\u062a \u062c\u062f\u064a\u062f\u0629.",
  "notifPrefsSaveFailed": "\u062a\u0639\u0630\u0651\u0631 \u062d\u0641\u0638 \u062a\u0641\u0636\u064a\u0644\u0643. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "notifPrefsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a.",
  "notifPrefsSystemFooter": "\u0625\u0639\u0644\u0627\u0646\u0627\u062a \u0627\u0644\u0646\u0638\u0627\u0645 \u0627\u0644\u0645\u0647\u0645\u0629 \u062a\u0635\u0644\u0643 \u062f\u0627\u0626\u0645\u064b\u0627."
'@
Add-ArbEntries 'lib\l10n\app_ar.arb' 'notifTitle' $arbAr

Write-Host ''
Write-Host 'Generating localizations (flutter gen-l10n) ...'
flutter gen-l10n
if ($LASTEXITCODE -ne 0) { throw 'flutter gen-l10n failed' }

Write-Host 'Formatting touched Dart files ...'
dart format `
  lib\features\notifications\presentation\notification_grouping.dart `
  lib\features\notifications\presentation\notification_center_screen.dart `
  lib\features\notifications\presentation\notification_preferences_screen.dart `
  test\features\notifications\presentation\notification_restyle_test.dart
if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }

Write-Host ''
Write-Host 'git status:'
git status --short
Write-Host ''
Write-Host 'DONE. Backups: ' $backup
Write-Host 'Next: run the tests from the instructions (flutter analyze, then flutter test).'