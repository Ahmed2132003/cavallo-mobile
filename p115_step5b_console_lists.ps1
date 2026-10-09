# =====================================================================
# P-115 STEP 5B - Business Console: posts/reels list + stories list + moderation chips
# Run from PowerShell (Windows PowerShell 5.1 or PowerShell 7).
# Repo: D:\Cavallo\social_commerce_app  (branch part-111)
#
# What it does:
#   REPLACE lib\features\content\presentation\content_list_screen.dart
#   REPLACE lib\features\stories\presentation\story_list_screen.dart
#   CREATE  test\features\business_console\presentation\console_lists_restyle_test.dart
#   APPEND  26 keys (console*) to lib\l10n\app_en.arb and lib\l10n\app_ar.arb
#   RUN     flutter gen-l10n  +  dart format on the touched Dart files
# REQUIRES: p115_step5a_console_dashboard.ps1 already ran (shared chip + row).
#
# Safe to run twice: ARB keys are skipped when present; replaced files are
# backed up OUTSIDE the repo ($env:TEMP\p115_step5b_backup).
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
  'lib\core\widgets\app_status_chip.dart',
  'lib\features\business_console\presentation\console_row.dart',
  'lib\core\l10n\l10n_context.dart',
  'lib\features\content\presentation\content_list_screen.dart',
  'lib\features\stories\presentation\story_list_screen.dart'
)) {
  if (-not (Test-Path $must)) { throw "Missing prerequisite file: $must" }
}

$backup = Join-Path $env:TEMP 'p115_step5b_backup'
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

$contentList = @'
/// Part P-044: the signed-in Business account's own Posts and Reels together
/// (`ownContentProvider`), tagged by type, each with an honest status chip.
/// (The long design notes of P-044 live in git history; the rules below are
/// unchanged.)
///
/// ### Architecture Rule (P-044, preserved exactly)
///
/// A business owner's UI must never imply content is live before its status
/// genuinely equals `published`:
/// * A Post always shows a real moderation chip (Under review / Live /
///   Rejected: reason).
/// * A Reel shows a DISTINCT "Processing video..." chip while
///   `ReelProcessingStatus.isBeforeModeration` is true, and a red "Video
///   processing failed" chip when processing failed. Once processing is
///   `ready`, the real moderation chip takes over.
/// * The rejection reason is ALWAYS visible to the business: the chip wraps
///   its text instead of cutting it.
///
/// Polling (a 5-second Timer owned by this State while a Reel is still
/// processing) is unchanged. Navigation is injected ([onCreatePost],
/// [onCreateReel]) as before.
///
/// Part P-115 (STEP 5) restyle, presentation only: shared `ConsoleRow`
/// anatomy, shared `AppStatusChip`, localized strings. No provider, polling or
/// callback changed.
library;

import 'dart:async';

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
import '../domain/content_item_entity.dart';
import '../domain/moderation_status.dart';
import '../domain/reel_entity.dart';
import 'own_content_provider.dart';

class ContentListScreen extends ConsumerStatefulWidget {
  const ContentListScreen({
    super.key,
    required this.onCreatePost,
    required this.onCreateReel,
  });

  /// Invoked when the user taps "New Post".
  final VoidCallback onCreatePost;

  /// Invoked when the user taps "New Reel".
  final VoidCallback onCreateReel;

  @override
  ConsumerState<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends ConsumerState<ContentListScreen> {
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Arms a 5-second poll if [items] contains a still-processing Reel,
  /// cancels any existing timer otherwise. Idempotent.
  void _syncPolling(List<ContentItem> items) {
    final stillProcessing = items.any(
      (item) =>
          item is ReelContentItem &&
          item.reel.processingStatus.isBeforeModeration,
    );

    if (!stillProcessing) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }

    if (_pollTimer != null) {
      return; // already polling
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(ownContentProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final contentAsync = ref.watch(ownContentProvider);

    contentAsync.whenData(_syncPolling);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consoleContentTitle)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create-post',
            onPressed: widget.onCreatePost,
            icon: const Icon(Icons.image_outlined),
            label: Text(l10n.consoleContentNewPost),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create-reel',
            onPressed: widget.onCreateReel,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(l10n.consoleContentNewReel),
          ),
        ],
      ),
      body: switch (contentAsync) {
        AsyncData(value: final items) when items.isEmpty => EmptyStateWidget(
          message: l10n.consoleContentEmpty,
          icon: Icons.dynamic_feed_outlined,
        ),
        AsyncData(value: final items) => _ContentListView(items: items),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Extracts a human-readable message from a thrown failure (both shapes).
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
        fallback: context.l10n.consoleContentLoadFailed,
      ),
      onRetry: () => ref.read(ownContentProvider.notifier).refresh(),
    );
  }
}

class _ContentListView extends ConsumerWidget {
  const _ContentListView({required this.items});

  final List<ContentItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownContentProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _ContentListItem(item: items[index]),
      ),
    );
  }
}

/// One Post or Reel row: thumbnail, caption, type, and exactly one status chip
/// - either the Reel processing chip or the real moderation chip.
class _ContentListItem extends StatelessWidget {
  const _ContentListItem({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final reelItem = item is ReelContentItem ? item as ReelContentItem : null;
    final isReel = reelItem != null;
    final isReelBeforeModeration =
        reelItem != null && reelItem.reel.processingStatus.isBeforeModeration;
    final isReelFailed =
        reelItem != null &&
        reelItem.reel.processingStatus == ReelProcessingStatus.failed;

    final Widget status;
    if (isReelBeforeModeration) {
      status = AppStatusChip(
        label: l10n.consoleStatusProcessing,
        icon: Icons.hourglass_top,
        tone: AppStatusTone.neutral,
      );
    } else if (isReelFailed) {
      status = AppStatusChip(
        label: l10n.consoleStatusProcessingFailed,
        icon: Icons.error_outline,
        tone: AppStatusTone.danger,
      );
    } else {
      status = _moderationChip(context, item.moderationStatus);
    }

    return ConsoleRow(
      leading: ConsoleThumbnail(
        url: item.thumbnailUrl,
        placeholderIcon:
            isReel ? Icons.movie_creation_outlined : Icons.image_outlined,
      ),
      title: item.caption,
      titleMaxLines: 2,
      meta: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReel ? Icons.movie_creation_outlined : Icons.image_outlined,
              size: 16,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              isReel ? l10n.consoleTypeReel : l10n.consoleTypePost,
              style: text.labelSmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
      status: status,
    );
  }

  /// Under review (amber) / Live (green) / Rejected: reason (red).
  Widget _moderationChip(BuildContext context, ModerationStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      ModerationStatus.pendingReview => AppStatusChip(
        label: l10n.consoleStatusUnderReview,
        icon: Icons.hourglass_bottom,
        tone: AppStatusTone.warning,
      ),
      ModerationStatus.published => AppStatusChip(
        label: l10n.consoleStatusLive,
        icon: Icons.check_circle_outline,
        tone: AppStatusTone.success,
      ),
      ModerationStatus.rejected => AppStatusChip(
        // Defensive fallback: rejectionReason should always be non-null once
        // status == rejected, but the chip must never show a blank reason.
        label: l10n.consoleStatusRejectedWithReason(
          item.rejectionReason ?? l10n.consoleStatusNoReasonGiven,
        ),
        icon: Icons.cancel_outlined,
        tone: AppStatusTone.danger,
      ),
    };
  }
}
'@
Write-DartFile 'lib\features\content\presentation\content_list_screen.dart' $contentList

$storyList = @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../business_console/presentation/console_row.dart';
import '../domain/own_story_entity.dart';
import 'own_stories_provider.dart';

/// The Business Console "Stories" tab: the signed-in business's own stories
/// (`ownStoriesProvider`) with an honest status per story.
/// (The long design notes of P-051/P-083 live in git history.)
///
/// Rules preserved exactly: the status shown is
/// `OwnStory.displayStatus(now)` (a story past `expiresAt` is Expired even if
/// the server still says published); a rejected story always shows its
/// reason; the FAB keeps its explicit hero tag (two default-tag FABs inside
/// the console IndexedStack make Flutter assert on push).
///
/// Part P-115 (STEP 5) restyle, presentation only: shared `ConsoleRow`
/// anatomy, shared `AppStatusChip` (icon + label, never colour alone),
/// localized strings. No provider, clock or navigation call changed.
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final storiesAsync = ref.watch(ownStoriesProvider);
    final now = ref.watch(storyListClockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consoleNavStories)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('story-list-create-button'),
        heroTag: 'story-list-create',
        onPressed: () {
          context.pushNamed(RouteNames.storyForm);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.consoleStoriesCreate),
      ),
      body: switch (storiesAsync) {
        AsyncData(value: final stories) when stories.isEmpty =>
          const _EmptyView(),
        AsyncData(value: final stories) => _StoryListView(
          stories: stories,
          now: now,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Clock used to derive "Expired" and the time left. Overridable in tests.
final storyListClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

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
      key: const Key('story-list-error'),
      message: _apiFailureMessage(
        error,
        fallback: context.l10n.consoleStoriesLoadFailed,
      ),
      onRetry: () => ref.read(ownStoriesProvider.notifier).refresh(),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder:
            (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: EmptyStateWidget(
                    key: const Key('story-list-empty'),
                    message: l10n.consoleStoriesEmpty,
                    icon: Icons.auto_stories_outlined,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _StoryListView extends ConsumerWidget {
  const _StoryListView({required this.stories, required this.now});

  final List<OwnStory> stories;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding keeps the last row clear of the extended FAB.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder:
            (context, index) => _StoryListItem(story: stories[index], now: now),
      ),
    );
  }
}

class _StoryListItem extends StatelessWidget {
  const _StoryListItem({required this.story, required this.now});

  final OwnStory story;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final displayStatus = story.displayStatus(now);
    final remaining = story.remaining(now);
    final reason = story.rejectionReason;
    final isVideo = _isVideoUrl(story.mediaUrl);

    return ConsoleRow(
      key: Key('story-list-item-${story.id}'),
      leading: ConsoleThumbnail(
        url: isVideo ? null : story.mediaUrl,
        placeholderIcon: Icons.videocam_outlined,
      ),
      title: l10n.consoleStoryNumber(story.id),
      meta: [
        if (remaining != null)
          Text(
            _formatRemaining(l10n, remaining),
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
      ],
      status: _StoryStatusChip(
        key: Key('story-status-${story.id}'),
        status: displayStatus,
      ),
      // The rejection reason is always visible to the business.
      footer:
          displayStatus == OwnStoryDisplayStatus.rejected && reason != null
              ? Text(
                l10n.consoleStoryReason(reason),
                style: text.bodySmall?.copyWith(color: colors.dangerText),
              )
              : null,
    );
  }
}

String _formatRemaining(AppLocalizations l10n, Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours >= 1) return l10n.consoleStoryTimeLeftHM(hours, minutes);
  if (minutes >= 1) return l10n.consoleStoryTimeLeftM(minutes);
  return l10n.consoleStoryTimeLeftLess;
}

class _StoryStatusChip extends StatelessWidget {
  const _StoryStatusChip({super.key, required this.status});

  final OwnStoryDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String label, IconData icon, AppStatusTone tone) = switch (status) {
      OwnStoryDisplayStatus.published => (
        l10n.consoleStoryPublished,
        Icons.check_circle_outline,
        AppStatusTone.success,
      ),
      OwnStoryDisplayStatus.pending => (
        l10n.consoleStoryPending,
        Icons.hourglass_bottom,
        AppStatusTone.warning,
      ),
      OwnStoryDisplayStatus.rejected => (
        l10n.consoleStoryRejected,
        Icons.cancel_outlined,
        AppStatusTone.danger,
      ),
      OwnStoryDisplayStatus.expired => (
        l10n.consoleStoryExpired,
        Icons.timer_off_outlined,
        AppStatusTone.neutral,
      ),
      OwnStoryDisplayStatus.unknown => (
        l10n.consoleStoryUnknown,
        Icons.help_outline,
        AppStatusTone.neutral,
      ),
    };
    return AppStatusChip(label: label, icon: icon, tone: tone);
  }
}

bool _isVideoUrl(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.webm');
}
'@
Write-DartFile 'lib\features\stories\presentation\story_list_screen.dart' $storyList

$listsTest = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/presentation/content_list_screen.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_list_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 5B): restyle checks for the content and stories tabs of
/// the Business Console. The behaviour tests (status rules, polling, retry,
/// refresh, navigation) stay in the P-044 / P-051 / P-083 test files, which
/// are unchanged. ASCII only: Arabic is read from the generated localizations.

class _EmptyContent extends OwnContentNotifier {
  @override
  Future<List<ContentItem>> build() async => const <ContentItem>[];
}

class _EmptyStories extends OwnStoriesNotifier {
  @override
  Future<List<OwnStory>> build() async => const <OwnStory>[];
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<dynamic> overrides, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
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
  testWidgets('content tab: empty state and create buttons in Arabic', (
    tester,
  ) async {
    await _pump(
      tester,
      ContentListScreen(onCreatePost: () {}, onCreateReel: () {}),
      [ownContentProvider.overrideWith(_EmptyContent.new)],
      locale: const Locale('ar'),
      theme: AppTheme.dark,
    );
    final l10n = lookupAppLocalizations(const Locale('ar'));

    expect(find.text(l10n.consoleContentTitle), findsOneWidget);
    expect(find.text(l10n.consoleContentNewPost), findsOneWidget);
    expect(find.text(l10n.consoleContentNewReel), findsOneWidget);
    expect(find.text(l10n.consoleContentEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stories tab: empty state and create button in Arabic', (
    tester,
  ) async {
    await _pump(
      tester,
      const StoryListScreen(),
      [ownStoriesProvider.overrideWith(_EmptyStories.new)],
      locale: const Locale('ar'),
    );
    final l10n = lookupAppLocalizations(const Locale('ar'));

    expect(find.text(l10n.consoleNavStories), findsOneWidget);
    expect(find.text(l10n.consoleStoriesCreate), findsOneWidget);
    expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stories tab: empty state in English, light theme', (
    tester,
  ) async {
    await _pump(tester, const StoryListScreen(), [
      ownStoriesProvider.overrideWith(_EmptyStories.new),
    ]);
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(find.text(l10n.consoleStoriesEmpty), findsOneWidget);
  });
}
'@
Write-DartFile 'test\features\business_console\presentation\console_lists_restyle_test.dart' $listsTest


$arbEn = @'
  "consoleContentTitle": "My Content",
  "@consoleContentTitle": {
    "description": "App bar title of the business posts and reels list."
  },
  "consoleContentNewPost": "New Post",
  "@consoleContentNewPost": {
    "description": "Extended button: create a post."
  },
  "consoleContentNewReel": "New Reel",
  "@consoleContentNewReel": {
    "description": "Extended button: create a reel."
  },
  "consoleContentEmpty": "No posts or reels yet.\nTap \"New Post\" or \"New Reel\" to share your first one.",
  "@consoleContentEmpty": {
    "description": "Empty state of the posts and reels list."
  },
  "consoleContentLoadFailed": "Could not load your content.",
  "@consoleContentLoadFailed": {
    "description": "Fallback error of the posts and reels list."
  },
  "consoleTypePost": "Post",
  "@consoleTypePost": {
    "description": "Type label of a post row."
  },
  "consoleTypeReel": "Reel",
  "@consoleTypeReel": {
    "description": "Type label of a reel row."
  },
  "consoleStatusUnderReview": "Under review",
  "@consoleStatusUnderReview": {
    "description": "Moderation chip: waiting for review (Pending)."
  },
  "consoleStatusLive": "Live",
  "@consoleStatusLive": {
    "description": "Moderation chip: approved and published (Approved)."
  },
  "consoleStatusRejectedWithReason": "Rejected: {reason}",
  "@consoleStatusRejectedWithReason": {
    "description": "Moderation chip: rejected, always followed by the reason.",
    "placeholders": {
      "reason": {
        "type": "String"
      }
    }
  },
  "consoleStatusNoReasonGiven": "no reason given",
  "@consoleStatusNoReasonGiven": {
    "description": "Fallback shown when a rejected item has no reason."
  },
  "consoleStatusProcessing": "Processing video\u2026",
  "@consoleStatusProcessing": {
    "description": "Chip of a reel that has not reached moderation yet."
  },
  "consoleStatusProcessingFailed": "Video processing failed",
  "@consoleStatusProcessingFailed": {
    "description": "Chip of a reel whose processing failed."
  },
  "consoleStoriesCreate": "Create Story",
  "@consoleStoriesCreate": {
    "description": "Extended button on the stories list."
  },
  "consoleStoriesEmpty": "No stories yet.\nTap \"Create Story\" to share your first one.",
  "@consoleStoriesEmpty": {
    "description": "Empty state of the stories list."
  },
  "consoleStoriesLoadFailed": "Could not load your stories.",
  "@consoleStoriesLoadFailed": {
    "description": "Fallback error of the stories list."
  },
  "consoleStoryNumber": "Story #{id}",
  "@consoleStoryNumber": {
    "description": "Title of a story row. id is the story number.",
    "placeholders": {
      "id": {
        "type": "int"
      }
    }
  },
  "consoleStoryPublished": "Published",
  "@consoleStoryPublished": {
    "description": "Story status chip: published."
  },
  "consoleStoryPending": "Pending",
  "@consoleStoryPending": {
    "description": "Story status chip: pending review."
  },
  "consoleStoryRejected": "Rejected",
  "@consoleStoryRejected": {
    "description": "Story status chip: rejected."
  },
  "consoleStoryExpired": "Expired",
  "@consoleStoryExpired": {
    "description": "Story status chip: expired."
  },
  "consoleStoryUnknown": "Unknown",
  "@consoleStoryUnknown": {
    "description": "Story status chip: status not recognised."
  },
  "consoleStoryReason": "Reason: {reason}",
  "@consoleStoryReason": {
    "description": "Rejection reason line under a rejected story.",
    "placeholders": {
      "reason": {
        "type": "String"
      }
    }
  },
  "consoleStoryTimeLeftHM": "{hours}h {minutes}m left",
  "@consoleStoryTimeLeftHM": {
    "description": "Time left of a story: hours and minutes.",
    "placeholders": {
      "hours": {
        "type": "int"
      },
      "minutes": {
        "type": "int"
      }
    }
  },
  "consoleStoryTimeLeftM": "{minutes}m left",
  "@consoleStoryTimeLeftM": {
    "description": "Time left of a story: minutes only.",
    "placeholders": {
      "minutes": {
        "type": "int"
      }
    }
  },
  "consoleStoryTimeLeftLess": "Less than 1m left",
  "@consoleStoryTimeLeftLess": {
    "description": "Time left of a story: under one minute."
  }
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'consoleContentTitle' $arbEn

$arbAr = @'
  "consoleContentTitle": "\u0645\u062d\u062a\u0648\u0627\u064a",
  "consoleContentNewPost": "\u0645\u0646\u0634\u0648\u0631 \u062c\u062f\u064a\u062f",
  "consoleContentNewReel": "\u0631\u064a\u0644 \u062c\u062f\u064a\u062f",
  "consoleContentEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0623\u0648 \u0631\u064a\u0644\u0632 \u0628\u0639\u062f.\n\u0627\u0636\u063a\u0637 \u00ab\u0645\u0646\u0634\u0648\u0631 \u062c\u062f\u064a\u062f\u00bb \u0623\u0648 \u00ab\u0631\u064a\u0644 \u062c\u062f\u064a\u062f\u00bb \u0644\u0645\u0634\u0627\u0631\u0643\u0629 \u0623\u0648\u0644 \u0645\u062d\u062a\u0648\u0649 \u0644\u0643.",
  "consoleContentLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0645\u062d\u062a\u0648\u0627\u0643.",
  "consoleTypePost": "\u0645\u0646\u0634\u0648\u0631",
  "consoleTypeReel": "\u0631\u064a\u0644",
  "consoleStatusUnderReview": "\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "consoleStatusLive": "\u062a\u0645 \u0627\u0644\u0646\u0634\u0631",
  "consoleStatusRejectedWithReason": "\u0645\u0631\u0641\u0648\u0636: {reason}",
  "consoleStatusNoReasonGiven": "\u0644\u0645 \u064a\u064f\u0630\u0643\u0631 \u0633\u0628\u0628",
  "consoleStatusProcessing": "\u062c\u0627\u0631\u064d \u0645\u0639\u0627\u0644\u062c\u0629 \u0627\u0644\u0641\u064a\u062f\u064a\u0648\u2026",
  "consoleStatusProcessingFailed": "\u062a\u0639\u0630\u0651\u0631\u062a \u0645\u0639\u0627\u0644\u062c\u0629 \u0627\u0644\u0641\u064a\u062f\u064a\u0648",
  "consoleStoriesCreate": "\u0625\u0646\u0634\u0627\u0621 \u0642\u0635\u0629",
  "consoleStoriesEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0642\u0635\u0635 \u0628\u0639\u062f.\n\u0627\u0636\u063a\u0637 \u00ab\u0625\u0646\u0634\u0627\u0621 \u0642\u0635\u0629\u00bb \u0644\u0645\u0634\u0627\u0631\u0643\u0629 \u0623\u0648\u0644 \u0642\u0635\u0629 \u0644\u0643.",
  "consoleStoriesLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0642\u0635\u0635\u0643.",
  "consoleStoryNumber": "\u0642\u0635\u0629 \u0631\u0642\u0645 {id}",
  "consoleStoryPublished": "\u062a\u0645 \u0627\u0644\u0646\u0634\u0631",
  "consoleStoryPending": "\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631",
  "consoleStoryRejected": "\u0645\u0631\u0641\u0648\u0636\u0629",
  "consoleStoryExpired": "\u0645\u0646\u062a\u0647\u064a\u0629",
  "consoleStoryUnknown": "\u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641\u0629",
  "consoleStoryReason": "\u0627\u0644\u0633\u0628\u0628: {reason}",
  "consoleStoryTimeLeftHM": "\u0645\u062a\u0628\u0642\u0651\u064a {hours} \u0633 {minutes} \u062f",
  "consoleStoryTimeLeftM": "\u0645\u062a\u0628\u0642\u0651\u064a {minutes} \u062f",
  "consoleStoryTimeLeftLess": "\u0645\u062a\u0628\u0642\u0651\u064a \u0623\u0642\u0644 \u0645\u0646 \u062f\u0642\u064a\u0642\u0629"
'@
Add-ArbEntries 'lib\l10n\app_ar.arb' 'consoleContentTitle' $arbAr

Write-Host ''
Write-Host 'Generating localizations (flutter gen-l10n) ...'
flutter gen-l10n
if ($LASTEXITCODE -ne 0) { throw 'flutter gen-l10n failed' }

Write-Host 'Formatting touched Dart files ...'
dart format `
  lib\features\content\presentation\content_list_screen.dart `
  lib\features\stories\presentation\story_list_screen.dart `
  test\features\business_console\presentation\console_lists_restyle_test.dart
if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }

Write-Host ''
Write-Host 'git status:'
git status --short
Write-Host ''
Write-Host 'DONE. Backups: ' $backup
Write-Host 'Next: run the tests from the instructions (flutter analyze, then flutter test).'