<#
  P114-Step1.ps1
  PART P-114, STEP 1 of 4 (shared presentation widgets + story tray, ring, viewer).

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  in Windows PowerShell or PowerShell 7, on branch part-111:

      powershell -ExecutionPolicy Bypass -File .\P114-Step1.ps1

  What it does:
    1. Checks you are in the right repo.
    2. CREATES 5 shared widgets, 4 test files.
    3. REPLACES story_ring_widget.dart, story_viewer_screen.dart, stories_bar_widget.dart.
    4. PATCHES home_feed_screen.dart (passes showOwnStoryTile for Business accounts).
    5. APPENDS 11 new keys to app_en.arb and app_ar.arb.
    6. Runs flutter gen-l10n.
  It is safe to run twice (it overwrites its own files and skips ARB keys that exist).
  Nothing is committed: undo everything with  git checkout -- .  and  git clean -fd lib test
#>
param([switch]$SkipGenL10n)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Get-Location).Path

function Fail([string]$Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }

if (-not (Test-Path (Join-Path $RepoRoot 'pubspec.yaml'))) { Fail 'pubspec.yaml not found. Run this script from the cavallo-mobile repo root.' }
if (-not (Select-String -Path (Join-Path $RepoRoot 'pubspec.yaml') -Pattern 'name: social_commerce_app' -Quiet)) { Fail 'This is not the social_commerce_app repo.' }
foreach ($required in @('lib\core\widgets\app_avatar.dart','lib\core\widgets\app_shimmer_box.dart','lib\core\l10n\rtl_helpers.dart','lib\features\stories\presentation\story_viewer_screen.dart','lib\features\feed\presentation\home_feed_screen.dart','lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot $required))) { Fail "Missing $required. Are you on branch part-111 with P-111..P-113 in place?" }
}
try { $branch = (git rev-parse --abbrev-ref HEAD).Trim(); Write-Host "Git branch: $branch" } catch { Write-Host 'WARNING: git not available.' -ForegroundColor Yellow }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function ToCrLf([string]$Text) { return ($Text -replace "`r?`n", "`r`n") }

function Write-RepoFile([string]$RelPath, [string]$Content) {
  $full = Join-Path $RepoRoot $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $existed = Test-Path $full
  [System.IO.File]::WriteAllText($full, (ToCrLf $Content), $Utf8NoBom)
  if ($existed) { Write-Host "  UPDATED  $RelPath" } else { Write-Host "  CREATED  $RelPath" }
}

function Add-ArbEntries([string]$RelPath, [string]$MarkerKey, [string]$EntriesText) {
  $full = Join-Path $RepoRoot $RelPath
  $raw = [System.IO.File]::ReadAllText($full)
  if ($raw.Contains('"' + $MarkerKey + '"')) { Write-Host "  SKIPPED  $RelPath (already contains $MarkerKey)"; return }
  $idx = $raw.LastIndexOf('}')
  if ($idx -lt 0) { Fail "$RelPath has no closing brace." }
  $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $head = $raw.Substring(0, $idx).TrimEnd()
  $tail = $raw.Substring($idx + 1)
  $body = $EntriesText -replace "`r?`n", $nl
  $new = $head + ',' + $nl + $body + $nl + '}' + $tail
  try { $null = $new | ConvertFrom-Json } catch { Fail "Generated JSON for $RelPath is invalid: $($_.Exception.Message)" }
  [System.IO.File]::WriteAllText($full, $new, $Utf8NoBom)
  Write-Host "  UPDATED  $RelPath (+11 keys)"
}

function Patch-Once([string]$RelPath, [string]$Old, [string]$New, [string]$DoneMarker) {
  $full = Join-Path $RepoRoot $RelPath
  $raw = [System.IO.File]::ReadAllText($full)
  $text = $raw -replace "`r`n", "`n"
  $Old = $Old -replace "`r`n", "`n"
  $New = $New -replace "`r`n", "`n"
  if ($text.Contains($DoneMarker)) { Write-Host "  SKIPPED  $RelPath (already patched)"; return }
  $pos = $text.IndexOf($Old)
  if ($pos -lt 0) { Fail "Could not find the expected block in $RelPath. Send me lines 280-310 of that file." }
  if ($text.IndexOf($Old, $pos + 1) -ge 0) { Fail "The expected block appears twice in $RelPath." }
  $text = $text.Substring(0, $pos) + $New + $text.Substring($pos + $Old.Length)
  [System.IO.File]::WriteAllText($full, (ToCrLf $text), $Utf8NoBom)
  Write-Host "  PATCHED  $RelPath"
}

Write-Host ''
Write-Host '== 1/4 Dart files ==' -ForegroundColor Cyan

Write-RepoFile 'lib\core\widgets\stat_item.dart' @'
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-114 STEP 1: one number-over-label cell of the Instagram-style
/// stats row (Posts, Followers, Products, Rating) on a business profile.
///
/// Presentation only. The caller passes the already formatted [value]
/// (use `AppFormatters.compactCount`) and the localized [label]; this widget
/// never formats or translates anything itself.
///
/// With [onTap] the whole cell is a button with a touch target of at least
/// 44 logical pixels. Without it the cell is plain text.
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  static const double minTapTarget = 44;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );

    Widget result = content;
    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTapTarget,
            minHeight: minTapTarget,
          ),
          child: Center(child: content),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '$value $label',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: result,
    );
  }
}
'@

Write-RepoFile 'lib\core\widgets\profile_tab_bar.dart' @'
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One icon tab of [ProfileTabBar].
class ProfileTabItem {
  const ProfileTabItem({required this.icon, required this.label});

  /// Icon shown in the tab. Non-directional icons only (grid, play, bag,
  /// info): they are never mirrored.
  final IconData icon;

  /// Localized label: tooltip and screen-reader label of the icon-only tab.
  final String label;
}

/// Part P-114 STEP 1: the icon tab bar of a business profile (Posts grid,
/// Reels grid, Products grid, Info).
///
/// A thin wrapper over [TabBar]: the caller owns the [TabController], so the
/// existing tab content and providers are untouched. Colours come from
/// `context.appColors`. Tabs follow the reading direction (the first tab is at
/// the start side: right in Arabic).
class ProfileTabBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.items,
    this.onTap,
  });

  final TabController controller;
  final List<ProfileTabItem> items;
  final ValueChanged<int>? onTap;

  static const double height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        labelColor: colors.brandText,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.brand,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: <Widget>[
          for (final ProfileTabItem item in items)
            Tab(
              height: height,
              child: Tooltip(message: item.label, child: Icon(item.icon)),
            ),
        ],
      ),
    );
  }
}
'@

Write-RepoFile 'lib\core\widgets\media_carousel.dart' @'
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_shimmer_box.dart';

/// Part P-114 STEP 1: swipeable media with dots, in a FIXED aspect ratio so a
/// list never jumps while images load (1:1 or 4:5 for posts, 9:16 for reels).
///
/// Presentation only: it receives the image URLs and shows them with
/// `Image.network` (the app's existing image loader). While an image loads it
/// shows an [AppShimmerBox] skeleton. Pages follow the reading direction, so
/// the carousel swipes the other way in Arabic. The dots are hidden when there
/// is a single image.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 1,
    this.onPageChanged,
    this.onTap,
    this.semanticLabel,
  });

  final List<String> imageUrls;

  /// Width divided by height. 1 (square), 4 / 5 (portrait post), 9 / 16 (reel).
  final double aspectRatio;

  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> urls = widget.imageUrls;

    final Widget body;
    if (urls.isEmpty) {
      body = ColoredBox(
        color: colors.surfaceVariant,
        child: Center(
          child: Icon(Icons.image_outlined, color: colors.textSecondary),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: _onPageChanged,
            itemBuilder:
                (BuildContext context, int index) =>
                    _CarouselImage(url: urls[index]),
          ),
          if (urls.length > 1)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 8,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _Dots(count: urls.length, index: _index),
                ),
              ),
            ),
        ],
      );
    }

    Widget result = AspectRatio(aspectRatio: widget.aspectRatio, child: body);
    if (widget.onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: result,
      );
    }
    return Semantics(label: widget.semanticLabel, image: true, child: result);
  }
}

class _CarouselImage extends StatelessWidget {
  const _CarouselImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder:
          (BuildContext _, Widget child, ImageChunkEvent? progress) =>
              progress == null
                  ? child
                  : const SizedBox.expand(
                    child: AppShimmerBox(borderRadius: 0),
                  ),
      errorBuilder:
          (BuildContext _, Object error, StackTrace? stack) => ColoredBox(
            color: colors.surfaceVariant,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.textSecondary,
              ),
            ),
          ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Container(
            key: ValueKey<String>('media_carousel_dot_$i'),
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i == index
                      ? colors.brand
                      : colors.surface.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}
'@

Write-RepoFile 'lib\core\widgets\expandable_caption.dart' @'
import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// Part P-114 STEP 1: Instagram-style caption: the author name in bold, then
/// the text, cut after [collapsedMaxLines] lines with a localized "more"
/// button that expands it in place.
///
/// Presentation only. When the text fits, there is no "more" button. Once
/// expanded it stays expanded (like Instagram).
class ExpandableCaption extends StatefulWidget {
  const ExpandableCaption({
    super.key,
    required this.text,
    this.authorName,
    this.collapsedMaxLines = 2,
  });

  final String text;

  /// Shown in bold before the text when not null or empty.
  final String? authorName;

  final int collapsedMaxLines;

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle base = (Theme.of(context).textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(color: colors.textPrimary);
    final String author = widget.authorName ?? '';

    final TextSpan span = TextSpan(
      style: base,
      children: <InlineSpan>[
        if (author.isNotEmpty)
          TextSpan(
            text: '$author ',
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        TextSpan(text: widget.text),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        bool overflows = false;
        if (!_expanded && constraints.maxWidth.isFinite) {
          final TextPainter painter = TextPainter(
            text: span,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: widget.collapsedMaxLines,
          )..layout(maxWidth: constraints.maxWidth);
          overflows = painter.didExceedMaxLines;
          painter.dispose();
        }
        final bool collapsed = overflows && !_expanded;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              span,
              maxLines: collapsed ? widget.collapsedMaxLines : null,
              overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.clip,
            ),
            if (collapsed)
              TextButton(
                onPressed: () => setState(() => _expanded = true),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  alignment: AlignmentDirectional.centerStart,
                ),
                child: Text(context.l10n.captionMore),
              ),
          ],
        );
      },
    );
  }
}
'@

Write-RepoFile 'lib\core\widgets\grid_tile_media.dart' @'
import 'package:flutter/material.dart';

import '../l10n/rtl_helpers.dart';
import '../theme/app_colors.dart';
import 'app_shimmer_box.dart';

/// Small icon drawn in the top corner (end side) of a [GridTileMedia].
enum GridTileBadge {
  /// Nothing.
  none,

  /// A video / reel.
  video,

  /// A post with several images.
  carousel,
}

/// Part P-114 STEP 1: one tile of the 3-column grids (profile Posts / Reels /
/// Products, Explore). Fixed aspect ratio, image cropped to fill, skeleton
/// while loading, optional corner badge. Presentation only.
class GridTileMedia extends StatelessWidget {
  const GridTileMedia({
    super.key,
    this.imageUrl,
    this.aspectRatio = 1,
    this.badge = GridTileBadge.none,
    this.onTap,
    this.semanticLabel,
  });

  final String? imageUrl;

  /// Width divided by height. 1 for posts and products, 9 / 16 for reels.
  final double aspectRatio;

  final GridTileBadge badge;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? url = imageUrl;

    final Widget placeholder = ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(Icons.image_outlined, color: colors.textSecondary),
      ),
    );

    final Widget media =
        (url == null || url.isEmpty)
            ? placeholder
            : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 400,
              loadingBuilder:
                  (BuildContext _, Widget child, ImageChunkEvent? progress) =>
                      progress == null
                          ? child
                          : const SizedBox.expand(
                            child: AppShimmerBox(borderRadius: 0),
                          ),
              errorBuilder:
                  (BuildContext _, Object error, StackTrace? stack) =>
                      placeholder,
            );

    final Widget tile = AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          media,
          if (badge != GridTileBadge.none)
            PositionedDirectional(
              top: 6,
              end: 6,
              child: _BadgeIcon(badge: badge),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      button: onTap != null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge});

  final GridTileBadge badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget icon = switch (badge) {
      GridTileBadge.video => DirectionalIcon(
        Icons.play_arrow,
        size: 16,
        color: colors.textPrimary,
      ),
      GridTileBadge.carousel => Icon(
        Icons.collections,
        size: 16,
        color: colors.textPrimary,
      ),
      GridTileBadge.none => const SizedBox.shrink(),
    };
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface.withValues(alpha: 0.8),
        ),
        child: Center(child: icon),
      ),
    );
  }
}
'@

Write-RepoFile 'lib\features\stories\presentation\story_ring_widget.dart' @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../routing/route_names.dart';
import 'story_public_provider.dart';

/// Part P-050 scope: the small circular avatar-with-ring indicator of one
/// business that currently has stories. Used by the Home and Discover stories
/// tray ([StoriesBarWidget]) and on a business profile. Tapping it opens
/// `StoryViewerScreen` for this one business's current story sequence.
///
/// Part P-114 STEP 1 (presentation only): the ring is drawn by the shared
/// [AppAvatar] -- the blue gradient ring while at least one story is unseen,
/// the outline-colour ring once every story has been seen. The data flow is
/// exactly the one of P-050: [businessStoriesProvider] decides whether
/// anything is drawn, [viewedStoriesProvider] decides seen / unseen, and a tap
/// pushes [RouteNames.storyViewer] with the business name as `extra`.
///
/// Renders NOTHING (`SizedBox.shrink()`) when the business has no
/// currently-visible stories, or while that first fetch is loading or failed:
/// it is a small discovery affordance, not primary content.
///
/// `BusinessProfile` still has no logo field, so the avatar shows the initials
/// of [businessName] (the shared [AppAvatar] fallback).
class StoryRingWidget extends ConsumerWidget {
  const StoryRingWidget({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final int businessId;
  final String businessName;

  /// Diameter of the photo inside the ring.
  static const double avatarSize = 62;

  /// Width of one tile of the tray (ring + label).
  static const double tileWidth = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(businessStoriesProvider(businessId));
    final viewedIds = ref.watch(viewedStoriesProvider(businessId));

    // Pattern-matched rather than `.valueOrNull` -- that getter isn't
    // available on this project's pinned flutter_riverpod version (3.3.2).
    final stories = switch (storiesAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (stories == null || stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool hasUnviewed = stories.any(
      (story) => !viewedIds.contains(story.id),
    );
    final AppColors colors = context.appColors;
    final String semanticLabel =
        hasUnviewed
            ? context.l10n.storyRingNewLabel(businessName)
            : context.l10n.storyRingSeenLabel(businessName);

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            () => context.pushNamed(
              RouteNames.storyViewer,
              pathParameters: {RouteNames.idParam: businessId.toString()},
              extra: businessName,
            ),
        child: SizedBox(
          width: tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                name: businessName,
                size: avatarSize,
                ring: hasUnviewed ? AppAvatarRing.unseen : AppAvatarRing.seen,
              ),
              const SizedBox(height: 4),
              Text(
                businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hasUnviewed ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'@

Write-RepoFile 'lib\features\stories\presentation\story_viewer_screen.dart' @'
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/story_public_repository.dart';
import '../domain/public_story_entity.dart';
import 'story_public_provider.dart';

/// Part P-050 scope: the full-screen, tap-to-advance Story viewer behind
/// `/stories/:id` -- the customer-facing payoff of the story pipeline.
///
/// ## Architecture Section 13 -- the one rule this whole file exists to satisfy
///
/// ALL timer/progress/current-index state lives as plain fields on
/// `_StoryPlayerState` -- never as a Riverpod provider. A fresh state object is
/// built every time `StoryViewerScreen` is pushed, and `dispose()` tears its
/// `AnimationController` down on close.
///
/// `viewedStoriesProvider` IS a provider this screen writes to -- a
/// deliberately separate, narrower concern (a per-business "seen" set for
/// `StoryRingWidget` styling).
///
/// ## Part P-114 STEP 1 (presentation only)
///
/// * The screen stays full-screen BLACK in Light and Dark. Black and white are
///   the only fixed (non-token) colours of this file, on purpose: this is
///   theme-independent media chrome over a photo, not themed UI.
/// * Segmented progress bars grow from the reading START (right in Arabic).
/// * Header: shared [AppAvatar], business name, relative time of the current
///   story, close button with a localized tooltip.
/// * Tap zones follow the reading direction: see [storyTapAdvances]. In LTR a
///   tap on the right half goes forward and the left half goes back; in RTL it
///   is the other way round (the reading-start side always goes back).
/// * Hold (long press) pauses the timer; releasing resumes it.
/// * Swipe down closes (unchanged).
/// * Every text comes from the localization files.
///
/// NOT part of this step: a reply field, a Like button and a product/link chip.
/// The story data model and `StoryPublicRepository` have no like / reply /
/// product-link capability, and P-114 may not change repositories or DTOs.
class StoryViewerScreen extends ConsumerWidget {
  const StoryViewerScreen({
    super.key,
    required this.businessId,
    this.businessName,
  });

  /// The raw `:id` path parameter -- a business id -- parsed here rather than
  /// by the router, same convention as `PostDetailScreen.postId`.
  final String businessId;

  /// Passed via `context.pushNamed(..., extra: businessName)` from
  /// `StoryRingWidget`. `null` when this route is reached without it (a deep
  /// link, a restored location) -- falls back to a generic label.
  final String? businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(businessId);
    final l10n = context.l10n;

    final Widget body;
    if (id == null) {
      body = _EdgeStateView(
        child: EmptyStateWidget(
          message: l10n.storyViewerNotFound,
          icon: Icons.error_outline,
        ),
      );
    } else {
      final storiesAsync = ref.watch(businessStoriesProvider(id));
      body = switch (storiesAsync) {
        AsyncData(:final value) when value.isNotEmpty => _StoryPlayer(
          businessId: id,
          businessName: businessName ?? l10n.storyViewerDefaultName,
          stories: value,
        ),
        AsyncData() => _EdgeStateView(
          child: EmptyStateWidget(
            message: l10n.storyViewerEmpty,
            icon: Icons.auto_stories_outlined,
          ),
        ),
        AsyncError(:final error) => _EdgeStateView(
          child: _LoadErrorView(error: error, businessId: id),
        ),
        _ => const _EdgeStateView(child: LoadingIndicator()),
      };
    }

    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: body));
  }
}

/// True when a tap at horizontal position [dx] (0 .. [width]) must go to the
/// NEXT story, false when it must go to the PREVIOUS one.
///
/// LTR: right half forward, left half back (the P-050 behaviour).
/// RTL: left half forward, right half back -- the reading-START side always
/// goes back.
@visibleForTesting
bool storyTapAdvances({
  required double dx,
  required double width,
  required TextDirection direction,
}) {
  if (direction == TextDirection.rtl) {
    return dx < width / 2;
  }
  return dx > width / 2;
}

/// Forces a dark [Theme] for any non-player state, so the shared empty / error
/// widgets stay legible against this screen's black background.
class _EdgeStateView extends StatelessWidget {
  const _EdgeStateView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: ThemeData.dark(useMaterial3: true), child: child);
  }
}

/// A genuine fetch failure -- retryable.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => localizedApiError(
        l10n,
        failure,
      ),
      ApiFailure() => localizedApiError(l10n, error),
      _ => l10n.storyViewerLoadFailed,
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessStoriesProvider(businessId)),
    );
  }
}

/// The actual tap / auto-advance / hold / swipe-dismiss player -- built only
/// once [StoryViewerScreen] confirms a non-empty story list.
class _StoryPlayer extends ConsumerStatefulWidget {
  const _StoryPlayer({
    required this.businessId,
    required this.businessName,
    required this.stories,
  });

  final int businessId;
  final String businessName;
  final List<PublicStory> stories;

  @override
  ConsumerState<_StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends ConsumerState<_StoryPlayer>
    with SingleTickerProviderStateMixin {
  /// Fixed duration for every Story (image or video).
  static const _storyDuration = Duration(seconds: 5);

  // --- Everything below is Architecture-Section-13-protected local state:
  // plain fields on this State object, never a Riverpod provider. ---
  late final AnimationController _controller;
  int _currentIndex = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener(_onAnimationStatus)
      ..forward();
    _recordCurrentView();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _advance();
    }
  }

  void _recordCurrentView() {
    final story = widget.stories[_currentIndex];

    // Fire-and-forget: `StoryPublicRepositoryImpl.recordView` already swallows
    // its own failures via reportError.
    unawaited(ref.read(storyPublicRepositoryProvider).recordView(story.id));

    // Local-only "seen" bookkeeping for StoryRingWidget's styling, deferred to
    // a microtask because the first call happens from initState() (Riverpod
    // rejects provider writes while the widget tree is building).
    Future.microtask(() {
      if (!mounted) return;
      final notifier = ref.read(
        viewedStoriesProvider(widget.businessId).notifier,
      );
      notifier.state = {...notifier.state, story.id};
    });
  }

  void _restartTimer() {
    _paused = false;
    _controller
      ..reset()
      ..forward();
  }

  void _advance() {
    if (_currentIndex >= widget.stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentIndex++);
    _restartTimer();
    _recordCurrentView();
  }

  void _goToPrevious() {
    if (_currentIndex == 0) {
      // Nothing before the first story: silently restart its timer.
      _restartTimer();
      return;
    }
    setState(() => _currentIndex--);
    _restartTimer();
    _recordCurrentView();
  }

  void _handleTapUp(TapUpDetails details, double width, TextDirection dir) {
    final bool forward = storyTapAdvances(
      dx: details.localPosition.dx,
      width: width,
      direction: dir,
    );
    if (forward) {
      _advance();
    } else {
      _goToPrevious();
    }
  }

  /// Hold: stop the timer where it is.
  void _pause() {
    if (_paused) return;
    _paused = true;
    _controller.stop();
  }

  /// Release: continue from where the timer stopped.
  void _resume() {
    if (!_paused) return;
    _paused = false;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final TextDirection direction = Directionality.of(context);
    final AppFormatters formatters = AppFormatters(context.l10n);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) {
          Navigator.of(context).pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp:
                (details) =>
                    _handleTapUp(details, constraints.maxWidth, direction),
            onLongPressStart: (_) => _pause(),
            onLongPressEnd: (_) => _resume(),
            onLongPressCancel: _resume,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  story.mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder:
                      (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: LoadingIndicator()),
                  errorBuilder:
                      (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 56,
                        ),
                      ),
                ),
                // Soft dark scrim under the header so white text stays legible
                // on bright photos. Ignores touches.
                const PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: 96,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  end: 8,
                  child: _ProgressBars(
                    count: widget.stories.length,
                    currentIndex: _currentIndex,
                    controller: _controller,
                  ),
                ),
                PositionedDirectional(
                  top: 20,
                  start: 12,
                  end: 4,
                  child: Row(
                    children: [
                      AppAvatar(name: widget.businessName, size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.businessName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatters.relativeTime(story.publishedAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: context.l10n.storyViewerClose,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The row of per-story progress segments. `AnimatedWidget` rebuilds only
/// itself on every animation tick, listening directly to the player's
/// [AnimationController]. Segments fill from the reading START.
class _ProgressBars extends AnimatedWidget {
  const _ProgressBars({
    required this.count,
    required this.currentIndex,
    required AnimationController controller,
  }) : super(listenable: controller);

  final int count;
  final int currentIndex;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final fillFraction =
            index < currentIndex
                ? 1.0
                : index == currentIndex
                ? _animation.value
                : 0.0;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fillFraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
'@

Write-RepoFile 'lib\features\discover\presentation\stories_bar_widget.dart' @'
/// Part P-062 scope: `StoriesBarWidget` -- the horizontally-scrolling row of
/// `StoryRingWidget` at the top of the Home feed and the Discover screen, one
/// ring per business that currently has an active Story.
///
/// ### businessName resolution -- per ring, non-blocking
///
/// `activeStoryGroupsProvider` only carries a `businessId` per group, so each
/// ring resolves its own display name through the EXISTING
/// `businessProfilePublicProvider` (Part P-029) -- one slow/failed name lookup
/// never blocks the rest of the bar from rendering.
///
/// Renders nothing (`SizedBox.shrink()`) while loading, on error, or when
/// there are no active story groups -- unless [showOwnStoryTile] is true.
///
/// ### Part P-114 STEP 1 (presentation only)
///
/// * Directional padding (`EdgeInsetsDirectional`), so the tray starts at the
///   right edge in Arabic.
/// * [showOwnStoryTile]: Business accounts see their own "+" tile FIRST. The
///   caller (Home) decides from the session whether the account is a Business;
///   this widget reads no new provider. The tile opens the EXISTING story
///   creation route ([RouteNames.storyForm]); it adds no new capability.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../routing/route_names.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../stories/presentation/story_ring_widget.dart';
import 'discover_provider.dart';

class StoriesBarWidget extends ConsumerWidget {
  const StoriesBarWidget({super.key, this.showOwnStoryTile = false});

  /// Business accounts: show the "+" tile (your story) before every ring.
  final bool showOwnStoryTile;

  static const double height = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(activeStoryGroupsProvider);

    // Pattern-matched rather than `.valueOrNull` -- same flutter_riverpod
    // 3.3.2 constraint `StoryRingWidget` documents.
    final groups = switch (groupsAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final int groupCount = groups?.length ?? 0;
    if (groupCount == 0 && !showOwnStoryTile) {
      return const SizedBox.shrink();
    }

    final int offset = showOwnStoryTile ? 1 : 0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        itemCount: groupCount + offset,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (showOwnStoryTile && index == 0) {
            return const _OwnStoryTile();
          }
          return _StoryRingByBusinessId(
            businessId: groups![index - offset].businessId,
          );
        },
      ),
    );
  }
}

/// One ring, resolving its own `businessName` independently of every other
/// ring in the bar -- see this file's own doc above for why.
class _StoryRingByBusinessId extends ConsumerWidget {
  const _StoryRingByBusinessId({required this.businessId});

  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfilePublicProvider(businessId));
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? context.l10n.businessUnknownName,
      _ => '',
    };

    return StoryRingWidget(businessId: businessId, businessName: businessName);
  }
}

/// "Your story" tile for Business accounts: avatar with a blue "+" badge.
/// Opens the existing story creation form.
class _OwnStoryTile extends StatelessWidget {
  const _OwnStoryTile();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String label = context.l10n.storyYourStory;

    return Semantics(
      button: true,
      label: context.l10n.storyAddTooltip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pushNamed(RouteNames.storyForm),
        child: SizedBox(
          width: StoryRingWidget.tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Same outer size as a ringed avatar, so the labels of all
                  // tiles line up.
                  const Padding(
                    padding: EdgeInsets.all(
                      AppAvatar.ringWidth + AppAvatar.ringGap,
                    ),
                    child: AppAvatar(size: StoryRingWidget.avatarSize),
                  ),
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.brand,
                        border: Border.all(
                          color: colors.background,
                          width: 2,
                        ),
                      ),
                      child: Icon(Icons.add, size: 16, color: colors.onBrand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'@

Write-RepoFile 'test\core\widgets\p114_shared_widgets_test.dart' @'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/expandable_caption.dart';
import 'package:social_commerce_app/core/widgets/grid_tile_media.dart';
import 'package:social_commerce_app/core/widgets/media_carousel.dart';
import 'package:social_commerce_app/core/widgets/profile_tab_bar.dart';
import 'package:social_commerce_app/core/widgets/stat_item.dart';

/// Part P-114 STEP 1: widget tests of the five shared presentation widgets,
/// each in left-to-right and right-to-left.
Widget _wrap(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    builder:
        (BuildContext context, Widget? app) =>
            Directionality(textDirection: direction, child: app!),
    home: Scaffold(body: Center(child: child)),
  );
}

class _TabHost extends StatefulWidget {
  const _TabHost({required this.onController});

  final void Function(TabController controller) onController;

  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileTabBar(
      controller: _controller,
      items: const <ProfileTabItem>[
        ProfileTabItem(icon: Icons.grid_on, label: 'Posts'),
        ProfileTabItem(icon: Icons.movie_outlined, label: 'Reels'),
        ProfileTabItem(icon: Icons.shopping_bag_outlined, label: 'Products'),
        ProfileTabItem(icon: Icons.info_outline, label: 'Info'),
      ],
    );
  }
}

void main() {
  group('P-114 STEP 1: StatItem', () {
    testWidgets('shows the value over the label', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const StatItem(value: '12.4K', label: 'Followers')),
      );
      expect(find.text('12.4K'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(
        tester.getCenter(find.text('12.4K')).dy,
        lessThan(tester.getCenter(find.text('Followers')).dy),
      );
    });

    testWidgets('with onTap: callback fires and target is at least 44', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(StatItem(value: '3', label: 'Posts', onTap: () => taps++)),
      );
      final Size size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Posts'));
      expect(taps, 1);
    });

    testWidgets('works in right-to-left and dark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatItem(value: '5', label: 'Products'),
          direction: TextDirection.rtl,
          theme: AppTheme.dark,
        ),
      );
      expect(find.text('Products'), findsOneWidget);
    });
  });

  group('P-114 STEP 1: ProfileTabBar', () {
    testWidgets('four icon tabs; tapping one changes the controller', (
      WidgetTester tester,
    ) async {
      late TabController controller;
      await tester.pumpWidget(
        _wrap(_TabHost(onController: (TabController c) => controller = c)),
      );
      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(controller.index, 0);

      await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('RTL: the first tab sits at the right (start) side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _TabHost(onController: (TabController c) {}),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.grid_on)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.info_outline)).dx),
      );
    });

    testWidgets('LTR: the first tab sits at the left (start) side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_TabHost(onController: (TabController c) {})),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.grid_on)).dx,
        lessThan(tester.getCenter(find.byIcon(Icons.info_outline)).dx),
      );
    });
  });

  group('P-114 STEP 1: MediaCarousel', () {
    const List<String> urls = <String>[
      'https://example.com/a.jpg',
      'https://example.com/b.jpg',
      'https://example.com/c.jpg',
    ];

    testWidgets('keeps a fixed 4:5 aspect ratio and shows one dot per image', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, aspectRatio: 4 / 5),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MediaCarousel)), const Size(200, 250));
      for (int i = 0; i < 3; i++) {
        expect(
          find.byKey(ValueKey<String>('media_carousel_dot_$i')),
          findsOneWidget,
        );
      }
    });

    testWidgets('a single image has no dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: <String>['https://example.com/a']),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('media_carousel_dot_0')),
        findsNothing,
      );
    });

    testWidgets('LTR: swiping towards the left shows the next image', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, onPageChanged: pages.add),
          ),
        ),
      );
      await tester.drag(find.byType(PageView), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(pages, <int>[1]);
    });

    testWidgets('RTL: swiping towards the right shows the next image', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, onPageChanged: pages.add),
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.drag(find.byType(PageView), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(pages, <int>[1]);
    });
  });

  group('P-114 STEP 1: ExpandableCaption', () {
    testWidgets('a short caption has no "more" button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: ExpandableCaption(text: 'Short text', authorName: 'Shop'),
          ),
        ),
      );
      expect(find.text('more'), findsNothing);
    });

    testWidgets('a long caption is cut and "more" expands it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: ExpandableCaption(
              text: List<String>.filled(60, 'word').join(' '),
              authorName: 'Shop',
            ),
          ),
        ),
      );
      expect(find.text('more'), findsOneWidget);
      final double collapsedHeight = tester.getSize(find.byType(ExpandableCaption)).height;

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(find.text('more'), findsNothing);
      expect(
        tester.getSize(find.byType(ExpandableCaption)).height,
        greaterThan(collapsedHeight),
      );
    });

    testWidgets('works in right-to-left', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: ExpandableCaption(
              text: List<String>.filled(60, 'word').join(' '),
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.text('more'), findsOneWidget);
    });
  });

  group('P-114 STEP 1: GridTileMedia', () {
    testWidgets('square by default, 9:16 for reels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 90, child: GridTileMedia())),
      );
      expect(tester.getSize(find.byType(GridTileMedia)), const Size(90, 90));

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 90,
            child: GridTileMedia(aspectRatio: 9 / 16),
          ),
        ),
      );
      expect(tester.getSize(find.byType(GridTileMedia)), const Size(90, 160));
    });

    testWidgets('badge icons and tap callback', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 90,
            child: GridTileMedia(
              badge: GridTileBadge.video,
              onTap: () => taps++,
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await tester.tap(find.byType(GridTileMedia));
      expect(taps, 1);

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 90,
            child: GridTileMedia(badge: GridTileBadge.carousel),
          ),
        ),
      );
      expect(find.byIcon(Icons.collections), findsOneWidget);
    });
  });
}
'@

Write-RepoFile 'test\features\stories\presentation\story_viewer_rtl_and_hold_test.dart' @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_viewer_screen.dart';

/// Part P-114 STEP 1: story viewer tap zones in LTR and RTL, hold-to-pause,
/// and the header. Same fake-repository convention as the P-050 tests, and the
/// same rule: no `pumpAndSettle()` while a story timer is running.
class _FakeRepository implements StoryPublicRepository {
  _FakeRepository(this.stories);

  final List<PublicStory> stories;
  final List<int> recordedViewIds = <int>[];

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: stories,
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {
    recordedViewIds.add(storyId);
  }
}

PublicStory _story(int id) => PublicStory(
  id: id,
  businessId: 1,
  mediaUrl: 'https://example.com/story-$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository,
  TextDirection direction,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storyPublicRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        builder:
            (BuildContext context, Widget? app) =>
                Directionality(textDirection: direction, child: app!),
        home: const StoryViewerScreen(
          businessId: '1',
          businessName: 'Alpha Traders',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapQuarter(WidgetTester tester, {required bool rightSide}) async {
  final Size size = tester.getSize(find.byType(LayoutBuilder));
  final Offset center = tester.getCenter(find.byType(LayoutBuilder));
  final double dx = rightSide ? size.width / 4 : -size.width / 4;
  await tester.tapAt(Offset(center.dx + dx, center.dy));
  await tester.pump();
}

void main() {
  group('P-114 STEP 1: storyTapAdvances', () {
    test('LTR: right half forward, left half back', () {
      expect(
        storyTapAdvances(dx: 300, width: 400, direction: TextDirection.ltr),
        isTrue,
      );
      expect(
        storyTapAdvances(dx: 100, width: 400, direction: TextDirection.ltr),
        isFalse,
      );
    });

    test('RTL: left half forward, right half back', () {
      expect(
        storyTapAdvances(dx: 100, width: 400, direction: TextDirection.rtl),
        isTrue,
      );
      expect(
        storyTapAdvances(dx: 300, width: 400, direction: TextDirection.rtl),
        isFalse,
      );
    });
  });

  group('P-114 STEP 1: StoryViewerScreen tap zones', () {
    testWidgets('LTR: right goes forward, left goes back', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(201), _story(202), _story(203)],
      );
      await _pump(tester, repository, TextDirection.ltr);
      expect(repository.recordedViewIds, <int>[201]);

      await _tapQuarter(tester, rightSide: true);
      expect(repository.recordedViewIds, <int>[201, 202]);

      await _tapQuarter(tester, rightSide: false);
      expect(repository.recordedViewIds, <int>[201, 202, 201]);
    });

    testWidgets('RTL: left goes forward, right (reading start) goes back', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(211), _story(212), _story(213)],
      );
      await _pump(tester, repository, TextDirection.rtl);
      expect(repository.recordedViewIds, <int>[211]);

      // Left half = reading END = forward.
      await _tapQuarter(tester, rightSide: false);
      expect(repository.recordedViewIds, <int>[211, 212]);

      // Right half = reading START = back.
      await _tapQuarter(tester, rightSide: true);
      expect(repository.recordedViewIds, <int>[211, 212, 211]);
    });
  });

  group('P-114 STEP 1: StoryViewerScreen header and hold', () {
    testWidgets('header shows the business name and a close button', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(221), _story(222)],
      );
      await _pump(tester, repository, TextDirection.ltr);

      expect(find.text('Alpha Traders'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('holding pauses the timer, releasing resumes it', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repository = _FakeRepository(
        <PublicStory>[_story(231), _story(232), _story(233)],
      );
      await _pump(tester, repository, TextDirection.ltr);
      expect(repository.recordedViewIds, <int>[231]);

      final Offset center = tester.getCenter(find.byType(LayoutBuilder));
      final TestGesture gesture = await tester.startGesture(center);
      // Long-press is recognised after 500 ms.
      await tester.pump(const Duration(milliseconds: 600));

      // 6 s of holding: far past the 5 s story duration, still on story 1.
      await tester.pump(const Duration(seconds: 6));
      expect(repository.recordedViewIds, <int>[231]);

      await gesture.up();
      await tester.pump();

      // Resumed: the remaining ~4.4 s run, then it advances.
      await tester.pump(const Duration(seconds: 5, milliseconds: 200));
      await tester.pump();
      expect(repository.recordedViewIds, <int>[231, 232]);
    });
  });
}
'@

Write-RepoFile 'test\features\stories\presentation\story_ring_widget_p114_test.dart' @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/presentation/story_public_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_ring_widget.dart';

/// Part P-114 STEP 1: the story ring is the shared AppAvatar with the blue
/// gradient ring while unseen and the outline ring once seen.
class _FakeRepository implements StoryPublicRepository {
  _FakeRepository(this.stories);

  final List<PublicStory> stories;

  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: stories,
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

PublicStory _story(int id) => PublicStory(
  id: id,
  businessId: 1,
  mediaUrl: 'https://example.com/story-$id.jpg',
  publishedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

Widget _host(ProviderContainer container, {ThemeData? theme}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: StoryRingWidget(businessId: 1, businessName: 'Alpha Traders'),
        ),
      ),
    ),
  );
}

ProviderContainer _container(List<PublicStory> stories) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      storyPublicRepositoryProvider.overrideWithValue(_FakeRepository(stories)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('unseen story: gradient ring, name shown', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container(<PublicStory>[_story(101)]);
    container.listen(viewedStoriesProvider(1), (_, __) {});

    await tester.pumpWidget(_host(container));
    await tester.pump();
    await tester.pump();

    expect(find.text('Alpha Traders'), findsOneWidget);
    expect(tester.widget<AppAvatar>(find.byType(AppAvatar)).ring,
        AppAvatarRing.unseen);
  });

  testWidgets('seen story: outline ring', (WidgetTester tester) async {
    final ProviderContainer container = _container(<PublicStory>[_story(101)]);
    container.listen(viewedStoriesProvider(1), (_, __) {});
    container.read(viewedStoriesProvider(1).notifier).state = <int>{101};

    await tester.pumpWidget(_host(container, theme: AppTheme.dark));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<AppAvatar>(find.byType(AppAvatar)).ring,
        AppAvatarRing.seen);
  });

  testWidgets('no stories: draws nothing', (WidgetTester tester) async {
    final ProviderContainer container = _container(<PublicStory>[]);
    container.listen(viewedStoriesProvider(1), (_, __) {});

    await tester.pumpWidget(_host(container));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppAvatar), findsNothing);
    expect(find.text('Alpha Traders'), findsNothing);
  });
}
'@

Write-RepoFile 'test\features\discover\presentation\stories_bar_own_tile_test.dart' @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/discover/data/discover_repository.dart';
import 'package:social_commerce_app/features/discover/domain/active_story_group_entity.dart';
import 'package:social_commerce_app/features/discover/domain/discover_repository.dart';
import 'package:social_commerce_app/features/discover/presentation/stories_bar_widget.dart';
import 'package:social_commerce_app/features/feed/domain/feed_page_entity.dart';
import 'package:social_commerce_app/features/stories/data/story_public_repository.dart';
import 'package:social_commerce_app/features/stories/domain/public_story_entity.dart';
import 'package:social_commerce_app/features/stories/domain/story_public_repository.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-114 STEP 1: the Business "your story" tile of the stories tray.
class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this.groups);

  final List<ActiveStoryGroup> groups;

  @override
  Future<List<ActiveStoryGroup>> fetchActiveStoryGroups() async => groups;

  @override
  Future<FeedPage> fetchDiscoverFeed({String? cursor}) =>
      throw UnimplementedError('Not exercised by these tests');
}

class _FakeBusinessProfileRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    return BusinessProfile(
      id: id,
      businessName: 'Alpha Traders',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

class _FakeStoryRepository implements StoryPublicRepository {
  @override
  Future<PaginatedResponse<PublicStory>> fetchBusinessStories(
    int businessId,
  ) async {
    return PaginatedResponse<PublicStory>(
      results: <PublicStory>[
        PublicStory(
          id: 1,
          businessId: businessId,
          mediaUrl: 'https://cdn.example.com/stories/1.jpg',
          publishedAt: DateTime(2026, 1, 1),
          expiresAt: DateTime(2026, 1, 2),
        ),
      ],
      next: null,
      previous: null,
    );
  }

  @override
  Future<void> recordView(int storyId) async {}
}

Widget _wrap({
  required bool showOwnStoryTile,
  required List<ActiveStoryGroup> groups,
  TextDirection direction = TextDirection.ltr,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              body: StoriesBarWidget(showOwnStoryTile: showOwnStoryTile),
            ),
      ),
      GoRoute(
        path: '/form',
        name: RouteNames.storyForm,
        builder:
            (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('STORY_FORM')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(
        _FakeDiscoverRepository(groups),
      ),
      businessProfilePublicRepositoryProvider.overrideWithValue(
        _FakeBusinessProfileRepository(),
      ),
      storyPublicRepositoryProvider.overrideWithValue(_FakeStoryRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder:
          (BuildContext context, Widget? app) =>
              Directionality(textDirection: direction, child: app!),
    ),
  );
}

void main() {
  testWidgets('Business: the tile shows even with no active stories and opens '
      'the story form', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(showOwnStoryTile: true, groups: <ActiveStoryGroup>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your story'), findsOneWidget);

    await tester.tap(find.text('Your story'));
    await tester.pumpAndSettle();
    expect(find.text('STORY_FORM'), findsOneWidget);
  });

  testWidgets('Customer: no tile, and nothing at all without stories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(showOwnStoryTile: false, groups: <ActiveStoryGroup>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your story'), findsNothing);
  });

  testWidgets('LTR: the own tile comes before (left of) the first ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        showOwnStoryTile: true,
        groups: <ActiveStoryGroup>[ActiveStoryGroup(businessId: 5, stories: [])],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Your story')).dx,
      lessThan(tester.getCenter(find.text('Alpha Traders')).dx),
    );
  });

  testWidgets('RTL: the own tile comes before (right of) the first ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        showOwnStoryTile: true,
        groups: <ActiveStoryGroup>[ActiveStoryGroup(businessId: 5, stories: [])],
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Your story')).dx,
      greaterThan(tester.getCenter(find.text('Alpha Traders')).dx),
    );
  });
}
'@


Write-Host ''
Write-Host '== 2/4 Patch home_feed_screen.dart ==' -ForegroundColor Cyan
$oldBlock = @'
    if (!signedIn) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: StoriesBarWidget(),
    );
'@
$newBlock = @'
    if (!signedIn) return const SizedBox.shrink();
    // Part P-114 STEP 1: Business accounts see their own "+" tile first.
    final bool isBusiness = ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) =>
            value?.accountType == AccountType.business,
          _ => false,
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StoriesBarWidget(showOwnStoryTile: isBusiness),
    );
'@
Patch-Once 'lib\features\feed\presentation\home_feed_screen.dart' $oldBlock $newBlock 'showOwnStoryTile: isBusiness'

Write-Host ''
Write-Host '== 3/4 ARB files ==' -ForegroundColor Cyan
$enEntries = @'
  "storyYourStory": "Your story",
  "@storyYourStory": {
    "description": "Label of the Business account's own tile at the start of the stories tray."
  },
  "storyAddTooltip": "Add to your story",
  "@storyAddTooltip": {
    "description": "Screen-reader label of the Business account's own '+' tile in the stories tray. Opens the story creation form."
  },
  "storyRingNewLabel": "{name}, new story",
  "@storyRingNewLabel": {
    "description": "Screen-reader label of a story ring with at least one unseen story.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "storyRingSeenLabel": "{name}, story seen",
  "@storyRingSeenLabel": {
    "description": "Screen-reader label of a story ring whose stories were all seen.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "storyViewerClose": "Close",
  "@storyViewerClose": {
    "description": "Tooltip and screen-reader label of the close button of the full-screen story viewer."
  },
  "storyViewerNotFound": "Story not found.",
  "@storyViewerNotFound": {
    "description": "Story viewer: the link does not point to a valid business."
  },
  "storyViewerEmpty": "No stories to show right now.",
  "@storyViewerEmpty": {
    "description": "Story viewer: the business has no visible stories."
  },
  "storyViewerLoadFailed": "Could not load stories.",
  "@storyViewerLoadFailed": {
    "description": "Story viewer: generic failure message when the stories could not be loaded."
  },
  "storyViewerDefaultName": "Business",
  "@storyViewerDefaultName": {
    "description": "Story viewer: name shown in the header when the business name is not known."
  },
  "businessUnknownName": "Unknown business",
  "@businessUnknownName": {
    "description": "Name shown for a business whose public profile could not be resolved."
  },
  "captionMore": "more",
  "@captionMore": {
    "description": "Button that expands a cut-off post or reel caption in place."
  }
'@
$arEntries = @'
  "storyYourStory": "\u0642\u0635\u062a\u0643",
  "storyAddTooltip": "\u0623\u0636\u0641 \u0625\u0644\u0649 \u0642\u0635\u062a\u0643",
  "storyRingNewLabel": "{name}\u060c \u0642\u0635\u0629 \u062c\u062f\u064a\u062f\u0629",
  "storyRingSeenLabel": "{name}\u060c \u062a\u0645\u062a \u0645\u0634\u0627\u0647\u062f\u0629 \u0627\u0644\u0642\u0635\u0629",
  "storyViewerClose": "\u0625\u063a\u0644\u0627\u0642",
  "storyViewerNotFound": "\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0627\u0644\u0642\u0635\u0629.",
  "storyViewerEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0642\u0635\u0635 \u0644\u0644\u0639\u0631\u0636 \u0627\u0644\u0622\u0646.",
  "storyViewerLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0642\u0635\u0635.",
  "storyViewerDefaultName": "\u0646\u0634\u0627\u0637 \u062a\u062c\u0627\u0631\u064a",
  "businessUnknownName": "\u0646\u0634\u0627\u0637 \u062a\u062c\u0627\u0631\u064a \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641",
  "captionMore": "\u0627\u0644\u0645\u0632\u064a\u062f"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'storyYourStory' $enEntries
Add-ArbEntries 'lib\l10n\app_ar.arb' 'storyYourStory' $arEntries

Write-Host ''
Write-Host '== 4/4 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'Done. Now run the tests from the STEP 1 message.' -ForegroundColor Green
git status --short