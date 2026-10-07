<#
  P114-Step2.ps1
  PART P-114, STEP 2 of 4 (post card, reel card, action row, Home feed assembly with skeletons).

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  in Windows PowerShell or PowerShell 7, on branch part-111 (STEP 1 already applied):

      powershell -ExecutionPolicy Bypass -File .\P114-Step2.ps1

  What it does:
    1. Checks you are in the right repo and that STEP 1 is in place.
    2. CREATES 2 presentation files and 4 test files.
    3. REPLACES post_card.dart, reel_card.dart, content_action_row.dart, home_feed_screen.dart.
       Each one is first compared with the exact version this step was built against;
       if your copy differs the script stops and changes nothing (use -Force to overwrite anyway).
    4. PATCHES 3 existing test files (small, documented edits).
    5. APPENDS 12 new keys to app_en.arb and app_ar.arb.
    6. Runs flutter gen-l10n.
  It is safe to run twice. Nothing is committed: undo everything with
      git checkout -- .
      git clean -fd lib test
#>
param([switch]$SkipGenL10n, [switch]$Force)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Get-Location).Path
$Sep = [System.IO.Path]::DirectorySeparatorChar

function Fail([string]$Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
function Fix-Rel([string]$RelPath) { return ($RelPath -replace '[\\/]', [string]$Sep) }

if (-not (Test-Path (Join-Path $RepoRoot 'pubspec.yaml'))) { Fail 'pubspec.yaml not found. Run this script from the cavallo-mobile repo root.' }
if (-not (Select-String -Path (Join-Path $RepoRoot 'pubspec.yaml') -Pattern 'name: social_commerce_app' -Quiet)) { Fail 'This is not the social_commerce_app repo.' }
foreach ($required in @(
  'lib\core\widgets\app_avatar.dart','lib\core\widgets\app_shimmer_box.dart',
  'lib\core\widgets\media_carousel.dart','lib\core\widgets\expandable_caption.dart',
  'lib\core\l10n\formatters.dart','lib\core\l10n\l10n_context.dart',
  'lib\features\content\presentation\post_card.dart','lib\features\content\presentation\reel_card.dart',
  'lib\features\social\presentation\content_action_row.dart','lib\features\feed\presentation\home_feed_screen.dart',
  'lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Is P-114 STEP 1 applied (branch part-111)?" }
}
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"captionMore"' -Quiet)) { Fail 'app_en.arb has no captionMore key: P-114 STEP 1 is not applied.' }
try { $branch = (git rev-parse --abbrev-ref HEAD).Trim(); Write-Host "Git branch: $branch" } catch { Write-Host 'WARNING: git not available.' -ForegroundColor Yellow }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function ToCrLf([string]$Text) { return ($Text -replace "`r?`n", "`r`n") }

# The script itself is pure ASCII: a non-ASCII character inside a file body is written as {{U+XXXX}}.
function Expand-U([string]$Text) {
  return [regex]::Replace($Text, '\{\{U\+([0-9A-F]{4})\}\}', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}

function Get-TextHash([string]$Text) {
  $lf = $Text -replace "`r`n", "`n"
  $sha = [System.Security.Cryptography.SHA256]::Create()
  return ([System.BitConverter]::ToString($sha.ComputeHash($Utf8NoBom.GetBytes($lf)))).Replace('-', '').ToLower()
}

# Creates the file, or overwrites it when it already exists (safe re-run).
function Write-RepoFile([string]$RelPath, [string]$Content, [bool]$TrailingNewline = $true) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $existed = Test-Path $full
  $text = Expand-U $Content; if ($TrailingNewline) { $text = $text + "`n" }
  [System.IO.File]::WriteAllText($full, (ToCrLf $text), $Utf8NoBom)
  if ($existed) { Write-Host "  UPDATED  $RelPath" } else { Write-Host "  CREATED  $RelPath" }
}

# Replaces an EXISTING file, but only when it is exactly the version this step was built against.
function Replace-RepoFile([string]$RelPath, [string]$ExpectedHash, [string]$Content, [bool]$TrailingNewline) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  if (-not (Test-Path $full)) { Fail "Missing $RelPath." }
  $newText = Expand-U $Content; if ($TrailingNewline) { $newText = $newText + "`n" }
  $currentHash = Get-TextHash ([System.IO.File]::ReadAllText($full))
  if ($currentHash -eq (Get-TextHash $newText)) { Write-Host "  SKIPPED  $RelPath (already up to date)"; return }
  if (($currentHash -ne $ExpectedHash) -and (-not $Force)) {
    Fail "$RelPath is not the version STEP 2 was built against (it has local changes, or STEP 1 was not applied exactly). Nothing was changed. Send me this file, or run again with -Force to overwrite it."
  }
  [System.IO.File]::WriteAllText($full, (ToCrLf $newText), $Utf8NoBom)
  Write-Host "  UPDATED  $RelPath"
}

function Patch-Once([string]$RelPath, [string]$Old, [string]$New, [string]$DoneMarker) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
  $raw = [System.IO.File]::ReadAllText($full)
  $text = $raw -replace "`r`n", "`n"
  $Old = $Old -replace "`r`n", "`n"
  $New = $New -replace "`r`n", "`n"
  $DoneMarker = $DoneMarker -replace "`r`n", "`n"
  if ($text.Contains($DoneMarker)) { Write-Host "  SKIPPED  $RelPath (already patched: $DoneMarker)"; return }
  $pos = $text.IndexOf($Old)
  if ($pos -lt 0) { Fail "Could not find the expected line in $RelPath. Send me that file." }
  if ($text.IndexOf($Old, $pos + 1) -ge 0) { Fail "The expected line appears twice in $RelPath." }
  $text = $text.Substring(0, $pos) + $New + $text.Substring($pos + $Old.Length)
  [System.IO.File]::WriteAllText($full, (ToCrLf $text), $Utf8NoBom)
  Write-Host "  PATCHED  $RelPath"
}

function Add-ArbEntries([string]$RelPath, [string]$MarkerKey, [string]$EntriesText, [int]$KeyCount) {
  $full = Join-Path $RepoRoot (Fix-Rel $RelPath)
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
  Write-Host "  UPDATED  $RelPath (+$KeyCount keys)"
}

Write-Host ''
Write-Host '== 1/5 New presentation files ==' -ForegroundColor Cyan
$new0 = @'
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../social/presentation/content_overflow_menu.dart';

/// Part P-114 STEP 2: the header row shared by `PostCard` and `ReelCard`.
///
/// Instagram anatomy: a circular [AppAvatar], the business name in bold with
/// the blue Verified mark after it, then (at the end side) the amber
/// [FeaturedBadge] when the owning business is Featured, and the existing
/// [ContentOverflowMenu] ("..." with Report).
///
/// Presentation only: every value is passed in by the card, nothing is read
/// from a provider here. `BusinessProfile` has no logo field on the backend,
/// so the avatar shows the initials of [businessName] (same fallback as the
/// stories tray). While the name is still being resolved ([businessName]
/// empty) it shows the generic person icon.
///
/// Featured stays read-only and uses the single [FeaturedBadge] widget.
class ContentCardHeader extends StatelessWidget {
  const ContentCardHeader({
    super.key,
    required this.businessName,
    required this.contentType,
    required this.objectId,
    this.isVerified = false,
    this.isFeatured = false,
  });

  final String businessName;

  /// `"post"` or `"reel"` (the wire value `ContentOverflowMenu` reports with).
  final String contentType;
  final int objectId;

  /// Shows the blue Verified mark after the name.
  final bool isVerified;

  /// Shows the amber [FeaturedBadge] (the OWNING business is Featured).
  final bool isFeatured;

  static const double avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle nameStyle = (Theme.of(context).textTheme.labelLarge ??
            const TextStyle())
        .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 0, 8),
      child: Row(
        children: <Widget>[
          AppAvatar(name: businessName, size: avatarSize),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    businessName,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified,
                    key: const ValueKey<String>('content_card_verified_mark'),
                    size: 16,
                    color: colors.brand,
                    semanticLabel: context.l10n.feedVerifiedLabel,
                  ),
                ],
              ],
            ),
          ),
          // Part P-110: display-only; shown when the OWNING business is
          // Featured. Every caller (Home feed, Discover, chat shares,
          // business profile) inherits it from here.
          if (isFeatured) ...<Widget>[
            const SizedBox(width: 8),
            const FeaturedBadge(),
          ],
          ContentOverflowMenu(contentType: contentType, objectId: objectId),
        ],
      ),
    );
  }
}
'@
Write-RepoFile 'lib\features\content\presentation\content_card_header.dart' $new0
$new1 = @'
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
'@
Write-RepoFile 'lib\features\feed\presentation\feed_skeleton.dart' $new1

Write-Host ''
Write-Host '== 2/5 Replace existing presentation files (checked first) ==' -ForegroundColor Cyan
$rep0 = @'
import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/expandable_caption.dart';
import '../../../core/widgets/media_carousel.dart';
import '../domain/public_post_entity.dart';
import '../../social/presentation/content_action_row.dart';
import 'content_card_header.dart';

/// Part P-045 scope: a reusable, customer-facing presentation of a single
/// published [PublicPost]. Every value it needs (the post, the business
/// display name, the tap callback) is passed in by the caller, so Phase 10's
/// Feed can reuse it unmodified.
///
/// `businessAvatarUrl` is deliberately not a parameter: `BusinessProfile`
/// has no logo/avatar field on the backend yet, so the avatar shows the
/// initials of the business name.
///
/// Part P-058 update: the action row is [ContentActionRow] (real Like/Save/
/// Share), and the business row ends with a "..." menu offering Report.
/// The Comment icon reuses [onTap] (open the detail screen).
///
/// Part P-114 STEP 2 (presentation only, same constructor plus one optional
/// flag): the Instagram-style post anatomy in Cavallo Blue.
///   1. [ContentCardHeader]: avatar, name, Verified, Featured badge, "..." menu.
///   2. Media in a FIXED 1:1 box ([MediaCarousel]) so the list never jumps
///      while the image loads; an [AppShimmerBox] skeleton shows meanwhile.
///   3. Action row: Like, Comment, Share at the start, Save at the end, then
///      the likes line, the caption (expandable "more") and the
///      "View all N comments" link, all inside [ContentActionRow]
///      (`showSummaryLines`) because it owns the live like/comment counts.
///   4. Relative time ("3 hours ago") from `createdAt`, through
///      [AppFormatters] only.
/// The whole card still opens the detail screen through [onTap]. No comment
/// preview is shown: the feed payload carries no comments and this part adds
/// no provider.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.businessName,
    this.onTap,
    this.isBusinessVerified = false,
  });

  final PublicPost post;
  final String businessName;
  final VoidCallback? onTap;

  /// Part P-114 STEP 2: shows the blue Verified mark after the business name.
  /// The caller resolves it (the Home feed reads the public business profile);
  /// callers that do not know it keep the default and show no mark.
  final bool isBusinessVerified;

  /// Post media box: width divided by height (1:1, Instagram square).
  static const double mediaAspectRatio = 1;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final String? imageUrl = post.imageUrl;
    final List<String> imageUrls =
        (imageUrl == null || imageUrl.isEmpty)
            ? const <String>[]
            : <String>[imageUrl];
    final DateTime? createdAt = post.createdAt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ContentCardHeader(
              businessName: businessName,
              contentType: 'post',
              objectId: post.id,
              isVerified: isBusinessVerified,
              isFeatured: post.isFeatured,
            ),
            MediaCarousel(
              imageUrls: imageUrls,
              aspectRatio: mediaAspectRatio,
              semanticLabel:
                  businessName.isEmpty
                      ? null
                      : context.l10n.feedPostMediaLabel(businessName),
            ),
            ContentActionRow(
              contentType: 'post',
              objectId: post.id,
              onCommentTap: () => onTap?.call(),
              isLiked: post.isLiked,
              isSaved: post.isSaved,
              likesCount: post.likesCount,
              commentsCount: post.commentsCount,
              sharesCount: post.sharesCount,
              updatedAt: post.updatedAt,
              showSummaryLines: true,
              summaryCaption:
                  post.caption.isEmpty
                      ? null
                      : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ExpandableCaption(text: post.caption),
                      ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 0),
                child: Text(
                  AppFormatters(context.l10n).relativeTime(createdAt),
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\content\presentation\post_card.dart' '323d0fd578952b83e7bfc478f385b8ca000704093d8af07117db883109d96f95' $rep0 $false
$rep1 = @'
import 'package:flutter/material.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../domain/public_reel_entity.dart';
import '../../social/presentation/content_action_row.dart';
import 'content_card_header.dart';

/// Part P-045 scope: same role as [PostCard] for a published [PublicReel].
/// Reusable, no parent-screen dependency, business identity is text only.
///
/// Part P-058 update: same [ContentActionRow] + Report "..." menu wiring as
/// `PostCard`, with `contentType: 'reel'`.
///
/// Part P-114 STEP 2 (presentation only, same constructor plus one optional
/// flag): Instagram-style reel anatomy.
///   1. [ContentCardHeader] (same as the post card).
///   2. 9:16 media in a FIXED box so the list never jumps while the
///      thumbnail loads; an [AppShimmerBox] skeleton shows meanwhile. The play
///      mark stays in the middle (decorative: playback belongs to the Reel
///      detail screen).
///   3. Overlaid on the media: the actions as a column at the END side
///      (Like, Comment, Share, Save, white on a dark scrim, with counts) and
///      the caption at the bottom START side. The scrim and the white are the
///      two theme-independent colours that sit on top of media, the same
///      convention as the story viewer.
///   4. Relative time under the media, through [AppFormatters] only.
/// The whole card still opens the detail screen through [onTap].
class ReelCard extends StatelessWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.businessName,
    this.onTap,
    this.isBusinessVerified = false,
  });

  final PublicReel reel;
  final String businessName;
  final VoidCallback? onTap;

  /// Part P-114 STEP 2: shows the blue Verified mark after the business name.
  /// Same contract as `PostCard.isBusinessVerified`.
  final bool isBusinessVerified;

  /// Reel media box: width divided by height (9:16).
  static const double mediaAspectRatio = 9 / 16;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime? createdAt = reel.createdAt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ContentCardHeader(
              businessName: businessName,
              contentType: 'reel',
              objectId: reel.id,
              isVerified: isBusinessVerified,
              isFeatured: reel.isFeatured,
            ),
            AspectRatio(
              aspectRatio: mediaAspectRatio,
              child: Semantics(
                label:
                    businessName.isEmpty
                        ? null
                        : context.l10n.feedReelMediaLabel(businessName),
                image: true,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ReelThumbnail(thumbnailUrl: reel.thumbnailUrl),
                    const _PlayIconOverlay(),
                    const Positioned.fill(child: _BottomScrim()),
                    PositionedDirectional(
                      end: 4,
                      bottom: 12,
                      child: ContentActionRow(
                        contentType: 'reel',
                        objectId: reel.id,
                        onCommentTap: () => onTap?.call(),
                        isLiked: reel.isLiked,
                        isSaved: reel.isSaved,
                        likesCount: reel.likesCount,
                        commentsCount: reel.commentsCount,
                        sharesCount: reel.sharesCount,
                        updatedAt: reel.updatedAt,
                        overlay: true,
                      ),
                    ),
                    if (reel.caption.isNotEmpty)
                      PositionedDirectional(
                        start: 12,
                        end: 64,
                        bottom: 16,
                        child: Text(
                          reel.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: _reelOnMedia,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
                child: Text(
                  AppFormatters(context.l10n).relativeTime(createdAt),
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The two theme-independent colours that sit on top of reel media: white
/// text and icons, and a black scrim behind them. They stay the same in Light
/// and Dark because the media itself does not change with the theme.
const Color _reelOnMedia = Color(0xFFFFFFFF);
final Color _reelScrim = Colors.black.withValues(alpha: 0.55);
final Color _reelPlayBackground = Colors.black.withValues(alpha: 0.45);

/// Thumbnail with the same neutral-fallback convention as before: no URL shows
/// the movie icon, a failed load shows the broken-image icon, and while the
/// image loads an [AppShimmerBox] skeleton fills the fixed 9:16 box.
class _ReelThumbnail extends StatelessWidget {
  const _ReelThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? url = thumbnailUrl;

    Widget placeholder(IconData icon) => ColoredBox(
      color: colors.surfaceVariant,
      child: Center(child: Icon(icon, size: 40, color: colors.textSecondary)),
    );

    if (url == null || url.isEmpty) {
      return placeholder(Icons.movie_outlined);
    }
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
          (BuildContext _, Object error, StackTrace? stack) =>
              placeholder(Icons.broken_image_outlined),
    );
  }
}

/// Dark gradient at the bottom of the media so the white caption and action
/// icons stay readable on any thumbnail. Vertical, so it needs no RTL logic.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.transparent, _reelScrim],
          ),
        ),
      ),
    );
  }
}

class _PlayIconOverlay extends StatelessWidget {
  const _PlayIconOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: _reelPlayBackground,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: const Icon(Icons.play_arrow, color: _reelOnMedia, size: 32),
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\content\presentation\reel_card.dart' 'a64b6c2f8c967e8e572b6b6e63a5dc6b72c337b92936e720f05935a7c087944f' $rep1 $false
$rep2 = @'
import 'package:flutter/material.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/domain/shared_content.dart';
import '../../chat/presentation/share_to_conversation_sheet.dart';
import 'content_interaction_key.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058 scope: replaces `ContentStubActionRow` (P-045) on
/// PostCard/ReelCard. The Comment icon does not act inline: it calls
/// [onCommentTap], which the caller wires to navigation to the detail
/// screen's comment section.
///
/// Part BUGFIX-058: this widget now seeds `contentInteractionProvider`
/// from the real per-viewer data the caller passes in ([isLiked],
/// [isSaved], [likesCount], [commentsCount], [sharesCount],
/// [updatedAt]) {{U+2014}} coming from `PublicPost`/`PublicReel`, which
/// `PostPublicSerializer`/`ReelPublicSerializer` now populate per-user.
/// This replaces the old "always start at isLiked: false / 0 counts"
/// behavior that let one account's local optimistic toggles leak into
/// whatever account viewed the same content next in the same running
/// app session.
///
/// Re-seed trigger (STEP 5 decision): this widget seeds once in
/// `initState`, and again in `didUpdateWidget` ONLY when the incoming
/// raw values (`isLiked`/`isSaved`/the three counts/`updatedAt`) differ
/// from the snapshot this widget last SCHEDULED a seed from. That
/// snapshot is compared against the constructor inputs, never against
/// the provider's live (possibly optimistically-toggled) state {{U+2014}} so a
/// rebuild caused by the user's own toggle never re-triggers a seed
/// (the parent's `PublicPost`/`PublicReel` data hasn't changed), while
/// a genuinely new fetch (pull-to-refresh, a different account's
/// session after logout/login reusing this same widget tree, re-paging
/// the feed) that returns different per-viewer values does re-seed.
/// This is deliberately independent of the `.autoDispose` /
/// invalidate-on-logout fix to `contentInteractionProvider` itself
/// (tracked as a separate step of this bugfix) {{U+2014}} the two are
/// complementary, not redundant: this fixes what the state is seeded
/// FROM, that fixes WHEN a stale per-account state gets cleared out
/// entirely.
///
/// Same precedent as `FollowButton` (`follow_button.dart`, Part P-058):
/// provider state can't be modified during the build phase, so the
/// actual `notifier.seed()` call is deferred with `Future.microtask`
/// rather than called directly from `initState`/`didUpdateWidget`.
/// Until that deferred seed lands, [build] shows the real per-viewer
/// values this widget was constructed with (not a flash of the
/// provider's brand-new default state).
///
/// [isLiked]/[isSaved]/[likesCount]/[commentsCount]/[sharesCount]/
/// [updatedAt] are optional with the same false/0/null defaults as
/// `PublicPost`/`PublicReel` themselves (see those entities'
/// docstrings) so the existing `content_action_row_test.dart` fixtures,
/// which construct this widget directly without them, keep working
/// unmodified.
///
/// Part P-114 STEP 2 (presentation only; every provider call, callback and the
/// Share flow are exactly as before). Three optional flags restyle it:
///  * default (all false): the plain bar (Like, Comment, Share, then Save at the
///    end) with the compact counts beside the icons. This is what the existing
///    tests and the detail screens still get.
///  * [showSummaryLines]: Instagram post anatomy. The counts beside the icons are
///    replaced by the likes line ("1.2K likes"), then [summaryCaption], then
///    the "View all N comments" link (it calls [onCommentTap]). They live here
///    because this widget owns the live like and comment counts.
///  * [overlay]: reel anatomy. A column (Like, Comment, Share, Save) in white,
///    with counts, to be placed over the media at the end side.
/// Counts go through `AppFormatters`, tooltips come from the ARB files.
class ContentActionRow extends ConsumerStatefulWidget {
  const ContentActionRow({
    super.key,
    required this.contentType,
    required this.objectId,
    required this.onCommentTap,
    this.isLiked = false,
    this.isSaved = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.updatedAt,
    this.showSummaryLines = false,
    this.summaryCaption,
    this.overlay = false,
  });

  /// `"post"` or `"reel"`.
  final String contentType;
  final int objectId;
  final VoidCallback onCommentTap;

  /// The current viewer's real like state for this content, from
  /// `PublicPost.isLiked` / `PublicReel.isLiked`.
  final bool isLiked;

  /// The current viewer's real save state for this content, from
  /// `PublicPost.isSaved` / `PublicReel.isSaved`.
  final bool isSaved;

  /// Real denormalized counters from `PublicPost`/`PublicReel`.
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  /// `PublicPost.updatedAt` / `PublicReel.updatedAt`, used as part of
  /// the re-seed trigger described in this class's docstring.
  final DateTime? updatedAt;

  /// Part P-114 STEP 2: show the likes line, [summaryCaption] and the
  /// "View all N comments" link under the icons, and hide the counts beside
  /// the icons (they would repeat the same numbers).
  final bool showSummaryLines;

  /// Part P-114 STEP 2: the caption widget placed between the likes line and
  /// the comments link (the caller adds its own horizontal padding). Only used
  /// with [showSummaryLines].
  final Widget? summaryCaption;

  /// Part P-114 STEP 2: vertical white column for use over reel media.
  final bool overlay;

  @override
  ConsumerState<ContentActionRow> createState() => _ContentActionRowState();
}

class _ContentActionRowState extends ConsumerState<ContentActionRow> {
  /// Flips true once the first deferred seed has actually run.
  bool _seeded = false;

  // Snapshot of the raw, per-viewer values this widget last SCHEDULED a
  // seed from. Set synchronously (not inside the deferred microtask) so
  // a second didUpdateWidget call before the first microtask fires
  // always compares against a valid, up-to-date snapshot.
  late bool _seededIsLiked;
  late bool _seededIsSaved;
  late int _seededLikesCount;
  late int _seededCommentsCount;
  late int _seededSharesCount;
  late DateTime? _seededUpdatedAt;

  ContentInteractionKey get _key => (
    contentType: widget.contentType,
    objectId: widget.objectId,
  );

  @override
  void initState() {
    super.initState();
    _scheduleSeed();
  }

  @override
  void didUpdateWidget(covariant ContentActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    final keyChanged =
        oldWidget.contentType != widget.contentType ||
        oldWidget.objectId != widget.objectId;
    final dataChanged =
        widget.isLiked != _seededIsLiked ||
        widget.isSaved != _seededIsSaved ||
        widget.likesCount != _seededLikesCount ||
        widget.commentsCount != _seededCommentsCount ||
        widget.sharesCount != _seededSharesCount ||
        widget.updatedAt != _seededUpdatedAt;

    if (keyChanged || dataChanged) {
      _scheduleSeed();
    }
  }

  void _scheduleSeed() {
    // Record the snapshot synchronously so overlapping calls (a second
    // didUpdateWidget before the first microtask has run) always compare
    // against the latest inputs.
    _seededIsLiked = widget.isLiked;
    _seededIsSaved = widget.isSaved;
    _seededLikesCount = widget.likesCount;
    _seededCommentsCount = widget.commentsCount;
    _seededSharesCount = widget.sharesCount;
    _seededUpdatedAt = widget.updatedAt;

    final isLiked = widget.isLiked;
    final isSaved = widget.isSaved;
    final likesCount = widget.likesCount;
    final commentsCount = widget.commentsCount;
    final sharesCount = widget.sharesCount;
    final key = _key;

    // Provider state can't be modified during the build phase, so defer
    // (same precedent as FollowButton's one-time seed).
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(contentInteractionProvider(key).notifier)
          .seed(
            isLiked: isLiked,
            isSaved: isSaved,
            likesCount: likesCount,
            commentsCount: commentsCount,
            sharesCount: sharesCount,
          );
      if (!_seeded) setState(() => _seeded = true);
    });
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(socialErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(contentInteractionProvider(_key));
    final notifier = ref.read(contentInteractionProvider(_key).notifier);
    final AppColors colors = context.appColors;
    final AppLocalizations l10n = context.l10n;
    final AppFormatters formatters = AppFormatters(l10n);
    final TextTheme textTheme = Theme.of(context).textTheme;
    // Part P-114 STEP 2: primary text colour in the app (theme aware), white
    // over reel media.
    final Color iconColor =
        widget.overlay ? _overlayOnMedia : colors.textPrimary;

    // Before the (possibly still-pending) deferred seed lands, show the
    // real per-viewer values this widget was given instead of a flash of
    // the provider's brand-new default state (unliked, 0 counts).
    final isLiked = _seeded ? providerState.isLiked : widget.isLiked;
    final isSaved = _seeded ? providerState.isSaved : widget.isSaved;
    final likesCount = _seeded ? providerState.likesCount : widget.likesCount;
    final commentsCount =
        _seeded ? providerState.commentsCount : widget.commentsCount;

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) _showError(context, e);
      }
    }

    // Part P-114 STEP 2: the Share flow, byte-for-byte the same behavior as
    // the closure that used to be inline in the Share button, moved into a
    // local function so the bar and the overlay layouts both use it.
    void onShare() {
      // The pre-existing P-058 flow, byte-for-byte the same
      // behavior: track the share, then open the native sheet.
      Future<void> nativeShare() => guarded(() async {
        await notifier.share();
        if (context.mounted) {
          await SharePlus.instance.share(
            ShareParams(
              text: 'Check out this ${widget.contentType} on Cavallo',
            ),
          );
        }
      });

      // Part P-077: offer "Share to conversation" next to it.
      final sharedType = SharedContentType.fromRaw(widget.contentType);
      if (sharedType == null) {
        nativeShare();
        return;
      }
      showShareOptionsSheet(
        context,
        contentType: sharedType,
        objectId: widget.objectId,
        onNativeShare: nativeShare,
        onSharedToConversation: () async {
          // Best-effort: the message is already delivered, so a
          // failed share-count bump must not surface as an error.
          try {
            await notifier.share();
          } catch (_) {}
        },
      );
    }

    Widget countLabel(int count) =>
        count > 0 && !widget.showSummaryLines
            ? Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                formatters.compactCount(count),
                style: textTheme.labelMedium,
              ),
            )
            : const SizedBox.shrink();

    final Widget likeButton = IconButton(
      icon: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? colors.danger : iconColor,
      ),
      tooltip: l10n.actionLike,
      onPressed: () => guarded(notifier.toggleLike),
    );
    final Widget commentButton = IconButton(
      icon: Icon(Icons.mode_comment_outlined, color: iconColor),
      tooltip: l10n.actionComment,
      onPressed: widget.onCommentTap,
    );
    final Widget shareButton = IconButton(
      icon: Icon(Icons.share_outlined, color: iconColor),
      tooltip: l10n.actionShare,
      onPressed: onShare,
    );
    final Widget saveButton = IconButton(
      icon: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_border,
        color: iconColor,
      ),
      tooltip: l10n.actionSave,
      onPressed: () => guarded(notifier.toggleSave),
    );

    if (widget.overlay) {
      Widget overlayCount(int count) => Text(
        formatters.compactCount(count),
        style: textTheme.labelMedium?.copyWith(
          color: iconColor,
          fontWeight: FontWeight.w600,
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          likeButton,
          if (likesCount > 0) overlayCount(likesCount),
          commentButton,
          if (commentsCount > 0) overlayCount(commentsCount),
          shareButton,
          saveButton,
        ],
      );
    }

    final Widget bar = Row(
      children: <Widget>[
        likeButton,
        countLabel(likesCount),
        commentButton,
        countLabel(commentsCount),
        shareButton,
        const Spacer(),
        saveButton,
      ],
    );
    if (!widget.showSummaryLines) {
      return bar;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        bar,
        if (likesCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.feedLikesLine(
                likesCount,
                formatters.compactCount(likesCount),
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (widget.summaryCaption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: widget.summaryCaption,
          ),
        if (commentsCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCommentTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l10n.feedViewAllComments(
                    commentsCount,
                    formatters.compactCount(commentsCount),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Part P-114 STEP 2: white, the one theme-independent colour used for the
/// action icons and counts when the row sits on top of reel media.
const Color _overlayOnMedia = Color(0xFFFFFFFF);
'@
Replace-RepoFile 'lib\features\social\presentation\content_action_row.dart' 'd773b71046d615b32ca64cce38e843de82a2b9b2ef3c571608742f808ed4549c' $rep2 $true
$rep3 = @'
/// Part P-061 scope: `HomeFeedScreen` {{U+2014}} the real `/home` landing screen,
/// replacing Part P-007's placeholder (`home_screen.dart`, deleted by
/// this part). Infinite-scrolling, cursor-paginated feed of published
/// [PublicPost]s/[PublicReel]s, backed by `homeFeedProvider`
/// (`home_feed_provider.dart`, STEP 1/2).
///
/// ### Card reuse {{U+2014}} zero modification
///
/// Every item renders through the existing [PostCard]/[ReelCard] (Part
/// P-045), exactly as `BusinessProfilePublicScreen`'s own Posts/Reels
/// sections already do {{U+2014}} same `businessName` + `onTap` shape, same
/// `context.pushNamed(RouteNames.postDetail / reelDetail, ...)`
/// navigation convention. Neither card was touched by this part.
/// (Part P-114 STEP 2 restyled both cards in place; the feed still hands them
/// the same `post`/`reel`, `businessName` and `onTap`, plus the optional
/// `isBusinessVerified` flag it reads from the same business lookup.)
///
/// ### `businessName` resolution {{U+2014}} per item, non-blocking
///
/// The feed payload only carries a `business` id per item (P-059's own
/// documented shape), so each row resolves its own display name through
/// the existing `businessProfilePublicProvider(id)` (Part P-029) inside
/// [_FeedListItem] {{U+2014}} a small [ConsumerWidget] per row, so one slow or
/// failed name lookup never blocks the rest of the list from rendering
/// (per this part's execution prompt).
///
/// ### Infinite scroll {{U+2014}} 80% threshold
///
/// [_HomeFeedScreenState] attaches a [ScrollController] listener that
/// calls `homeFeedProvider.notifier.loadMore()` once the scroll position
/// crosses 80% of the current scrollable extent. `loadMore()` is already
/// idempotent/no-op while a load is in flight or once `nextCursor` is
/// `null` (see that method's own docstring), so this listener does not
/// need its own in-flight guard.
///
/// ### Pull-to-refresh {{U+2014}} a known, flagged trade-off
///
/// [RefreshIndicator] calls `homeFeedProvider.notifier.refresh()`, which
/// (per `home_feed_provider.dart`'s STEP 1/2 fix) sets `state` to a bare
/// `AsyncValue.loading()` with no attached previous data {{U+2014}} Riverpod's
/// `copyWithPrevious` is an internal member this project's own analyzer
/// pass already ruled out. That means this screen's top-level `switch`
/// briefly renders [FeedSkeletonList] instead of the list for the
/// duration of a manual refresh (now as the skeleton, Part P-114 STEP 2),
/// rather than keeping the old items
/// visible under the pull spinner. Flagged rather than silently
/// patched: fixing it properly means changing `FeedState`/the
/// provider's contract, which is out of this screen's own scope.
///
/// ### Navigation - no debug menu (Part P-113, STEP 6B)
///
/// This screen has no debug or overflow menu. Every destination the old
/// debug menu opened is now reached from visible UI: the bottom bar (Explore,
/// Saved, Create, Moderation, Chats, Profile), the Home top bar (notifications
/// and chats), the stories tray at the top of this feed, and the Profile and
/// Settings hub (Business tools, language, appearance, log out). The
/// navigation manifest and its reachability test keep it that way.
///
/// ### Instagram-style assembly (Part P-114 STEP 2)
///
/// Presentation only: every provider call, route and callback is unchanged.
/// The list is full width (no side padding): the stories tray, a hairline,
/// then post and reel cards that carry their own hairline. The first load
/// shows [FeedSkeletonList] and loading more shows one [FeedPostSkeleton]
/// instead of spinners. The empty and error messages come from the ARB files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/shell/home_top_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../chat/presentation/chat_unread_provider.dart';
import '../../content/domain/public_post_entity.dart';
import '../../content/domain/public_reel_entity.dart';
import '../../content/presentation/post_card.dart';
import '../../content/presentation/reel_card.dart';
import '../../discover/presentation/discover_provider.dart';
import '../../discover/presentation/stories_bar_widget.dart';
import '../../notifications/presentation/notification_list_provider.dart';
import '../domain/feed_item_entity.dart';
import 'feed_skeleton.dart';
import 'home_feed_provider.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
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

  /// Fires `loadMore()` once the user has scrolled past 80% of the
  /// current scrollable extent. Guarded against `maxScrollExtent == 0`
  /// (a feed short enough to not scroll at all yet) to avoid firing on
  /// every frame in that case. `loadMore()` itself is the source of
  /// truth for "is there more to load" / "is a load already running" {{U+2014}}
  /// see `home_feed_provider.dart`.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final threshold = position.maxScrollExtent * 0.8;
    if (position.pixels >= threshold) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      // Part P-113: the shared Home top bar (wordmark, bell and chats icons
      // with unread badges). No debug or overflow menu: every destination is
      // reached from the bottom bar, the top bar or the Profile hub.
      appBar: const HomeTopBar(),
      body: switch (feedAsync) {
        AsyncData(value: final state) => _FeedBody(
          state: state,
          scrollController: _scrollController,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const FeedSkeletonList(
          key: ValueKey<String>('home_feed_skeleton'),
        ),
      },
    );
  }
}

/// The loaded (or loading-more) feed: pull-to-refresh wrapping either
/// the scrollable item list or, for a genuinely empty feed (both the
/// following tier and the backfill returned nothing), an
/// [EmptyStateWidget] {{U+2014}} still wrapped in a scrollable so
/// [RefreshIndicator] keeps working.
class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.state, required this.scrollController});

  final FeedState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() {
      // Part P-113 (STEP 5): a user-initiated refresh also re-reads the two
      // unread counts of the top bar (one request each, no polling).
      ref.invalidate(notificationListProvider);
      ref.invalidate(chatUnreadCountProvider);
      ref.invalidate(activeStoryGroupsProvider);
      return ref.read(homeFeedProvider.notifier).refresh();
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _HomeStoriesTray(),
            const SizedBox(height: 96),
            EmptyStateWidget(
              message: context.l10n.feedEmptyMessage,
              icon: Icons.dynamic_feed_outlined,
            ),
          ],
        ),
      );
    }

    // Index 0 is the stories tray (Part P-113 STEP 6A); feed items follow.
    final itemCount = 1 + state.items.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _HomeStoriesTray();
          }
          final itemIndex = index - 1;
          if (itemIndex >= state.items.length) {
            // Part P-114 STEP 2: a skeleton card instead of a spinner.
            return const FeedPostSkeleton(
              key: ValueKey<String>('home_feed_loading_more'),
            );
          }
          return _FeedListItem(item: state.items[itemIndex]);
        },
      ),
    );
  }
}

/// One row of the feed. Resolves its own `businessName` through
/// `businessProfilePublicProvider` (Part P-029) {{U+2014}} independent of every
/// other row's own lookup {{U+2014}} then delegates to [PostCard]/[ReelCard]
/// (Part P-045) unmodified.
class _FeedListItem extends ConsumerWidget {
  const _FeedListItem({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      businessProfilePublicProvider(item.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) =>
        profile?.businessName ?? context.l10n.businessUnknownName,
      _ => '',
    };
    // Part P-114 STEP 2: the same lookup also tells whether to show the blue
    // Verified mark (false while loading or when the profile is unknown).
    final bool isVerified = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.isVerified ?? false,
      _ => false,
    };

    // Part P-114 STEP 2: no wrapper padding; each card carries its own
    // bottom hairline (full-width Instagram list).
    return switch (item) {
      PostFeedItem(:final post) => PostCard(
        post: post,
        businessName: businessName,
        isBusinessVerified: isVerified,
        onTap:
            () => context.pushNamed(
              RouteNames.postDetail,
              pathParameters: {RouteNames.idParam: '${post.id}'},
            ),
      ),
      ReelFeedItem(:final reel) => ReelCard(
        reel: reel,
        businessName: businessName,
        isBusinessVerified: isVerified,
        onTap:
            () => context.pushNamed(
              RouteNames.reelDetail,
              pathParameters: {RouteNames.idParam: '${reel.id}'},
            ),
      ),
    };
  }
}

/// A genuine first-load failure (no connectivity, 5xx, an unexpected
/// payload) {{U+2014}} retryable. `homeFeedProvider` has automatic retry
/// disabled (see that file's docstring), so this button is the only
/// thing that retries; `ref.invalidate` re-runs `build()` from scratch,
/// same convention as every other top-level screen error view in this
/// project (`BusinessProfilePublicScreen._LoadErrorView`, etc.).
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      message: context.l10n.feedLoadFailed,
      onRetry: () => ref.invalidate(homeFeedProvider),
    );
  }
}

/// Part P-113 (STEP 6A): the stories tray at the top of the Home feed - the
/// locked reachability matrix names it as the entry point to the Story viewer
/// ("Tab 1; story rings open Story viewer"). It reuses the existing
/// [StoriesBarWidget] (the same bar the Explore tab shows), draws nothing
/// while signed out, and nothing when no business has an active story.
class _HomeStoriesTray extends ConsumerWidget {
  const _HomeStoriesTray();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool signedIn = ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value != null,
          _ => false,
        },
      ),
    );
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
    // Part P-114 STEP 2: a hairline separates the tray from the first card.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: StoriesBarWidget(showOwnStoryTile: isBusiness),
        ),
        Divider(height: 0.5, thickness: 0.5, color: context.appColors.outline),
      ],
    );
  }
}
'@
Replace-RepoFile 'lib\features\feed\presentation\home_feed_screen.dart' '980d874fdb20923969e02b0210a3b4277a082a8b673d358c75f1754b76497209' $rep3 $true

Write-Host ''
Write-Host '== 3/5 ARB files ==' -ForegroundColor Cyan
$enEntries = @'
  "actionLike": "Like",
  "@actionLike": {
    "description": "Tooltip and screen-reader label of the Like button on posts and reels."
  },
  "actionComment": "Comment",
  "@actionComment": {
    "description": "Tooltip and screen-reader label of the Comment button on posts and reels."
  },
  "actionShare": "Share",
  "@actionShare": {
    "description": "Tooltip and screen-reader label of the Share button on posts and reels."
  },
  "actionSave": "Save",
  "@actionSave": {
    "description": "Tooltip and screen-reader label of the Save (bookmark) button on posts and reels."
  },
  "feedLikesLine": "{count, plural, one{{formatted} like} other{{formatted} likes}}",
  "@feedLikesLine": {
    "description": "Likes line under the action row of a post card. count is the exact number (it picks the plural form); formatted is the compact text (for example 1.2K) shown to the user.",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "formatted": {
        "type": "String"
      }
    }
  },
  "feedViewAllComments": "{count, plural, one{View 1 comment} other{View all {formatted} comments}}",
  "@feedViewAllComments": {
    "description": "Link under the caption of a post card that opens the comments. count is the exact number (plural form); formatted is the compact text.",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "formatted": {
        "type": "String"
      }
    }
  },
  "feedVerifiedLabel": "Verified",
  "@feedVerifiedLabel": {
    "description": "Screen-reader label of the blue Verified mark after a business name."
  },
  "feedPostMediaLabel": "Post by {name}",
  "@feedPostMediaLabel": {
    "description": "Screen-reader label of the picture of a post card.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "feedReelMediaLabel": "Reel by {name}",
  "@feedReelMediaLabel": {
    "description": "Screen-reader label of the media of a reel card.",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "feedEmptyMessage": "Your feed is empty right now.\nFollow some businesses, or check back soon.",
  "@feedEmptyMessage": {
    "description": "Home feed: message shown when there is nothing to show yet."
  },
  "feedLoadFailed": "Could not load your feed.",
  "@feedLoadFailed": {
    "description": "Home feed: message shown when the first page could not be loaded (next to the Retry button)."
  },
  "feedLoadingLabel": "Loading your feed",
  "@feedLoadingLabel": {
    "description": "Home feed: screen-reader label of the skeleton shown while the first page loads."
  }
'@
$arEntries = @'
  "actionLike": "\u0625\u0639\u062c\u0627\u0628",
  "actionComment": "\u062a\u0639\u0644\u064a\u0642",
  "actionShare": "\u0645\u0634\u0627\u0631\u0643\u0629",
  "actionSave": "\u062d\u0641\u0638",
  "feedLikesLine": "{count, plural, zero{{formatted} \u0625\u0639\u062c\u0627\u0628} one{\u0625\u0639\u062c\u0627\u0628 \u0648\u0627\u062d\u062f} two{\u0625\u0639\u062c\u0627\u0628\u0627\u0646} few{{formatted} \u0625\u0639\u062c\u0627\u0628\u0627\u062a} many{{formatted} \u0625\u0639\u062c\u0627\u0628\u064b\u0627} other{{formatted} \u0625\u0639\u062c\u0627\u0628}}",
  "feedViewAllComments": "{count, plural, zero{\u0639\u0631\u0636 \u0643\u0644 {formatted} \u062a\u0639\u0644\u064a\u0642} one{\u0639\u0631\u0636 \u0627\u0644\u062a\u0639\u0644\u064a\u0642} two{\u0639\u0631\u0636 \u0627\u0644\u062a\u0639\u0644\u064a\u0642\u064a\u0646} few{\u0639\u0631\u0636 \u0643\u0644 {formatted} \u062a\u0639\u0644\u064a\u0642\u0627\u062a} many{\u0639\u0631\u0636 \u0643\u0644 {formatted} \u062a\u0639\u0644\u064a\u0642\u064b\u0627} other{\u0639\u0631\u0636 \u0643\u0644 {formatted} \u062a\u0639\u0644\u064a\u0642}}",
  "feedVerifiedLabel": "\u0645\u0648\u062b\u0651\u0642",
  "feedPostMediaLabel": "\u0645\u0646\u0634\u0648\u0631 \u0645\u0646 {name}",
  "feedReelMediaLabel": "\u0631\u064a\u0644 \u0645\u0646 {name}",
  "feedEmptyMessage": "\u062e\u0644\u0627\u0635\u062a\u0643 \u0641\u0627\u0631\u063a\u0629 \u062d\u0627\u0644\u064a\u064b\u0627.\n\u062a\u0627\u0628\u0639 \u0628\u0639\u0636 \u0627\u0644\u0623\u0646\u0634\u0637\u0629 \u0627\u0644\u062a\u062c\u0627\u0631\u064a\u0629\u060c \u0623\u0648 \u0639\u062f \u0644\u0627\u062d\u0642\u064b\u0627.",
  "feedLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u062e\u0644\u0627\u0635\u062a\u0643.",
  "feedLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u062e\u0644\u0627\u0635\u062a\u0643"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'actionLike' $enEntries 12
Add-ArbEntries 'lib\l10n\app_ar.arb' 'actionLike' $arEntries 12

Write-Host ''
Write-Host '== 4/5 Tests ==' -ForegroundColor Cyan
$t0 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/core/widgets/media_carousel.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the Instagram-style anatomy of [PostCard], in English
/// (left-to-right) and Arabic (right-to-left), Light and Dark. The behavior
/// tests (Like, Comment, Report, tap) stay in `post_card_test.dart`.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
const PublicPost _post = PublicPost(
  id: 701,
  businessId: 7,
  caption: 'New arrivals just landed.',
);

PublicPost _with({
  int likes = 0,
  int comments = 0,
  bool featured = false,
  DateTime? createdAt,
  String caption = 'New arrivals just landed.',
}) {
  return PublicPost(
    id: 701,
    businessId: 7,
    caption: caption,
    likesCount: likes,
    commentsCount: comments,
    isFeatured: featured,
    createdAt: createdAt,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  PublicPost post = _post,
  VoidCallback? onTap,
  bool verified = false,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // A clean tree each time, so a test can call _pump more than once.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: PostCard(
            post: post,
            businessName: 'Al Ananka Store',
            onTap: onTap,
            isBusinessVerified: verified,
          ),
        ),
      ),
    ),
  );
  // Let the deferred like/save seed of the action row land.
  await tester.pump();
}

void main() {
  group('PostCard (P-114) - header', () {
    testWidgets('shows the avatar and the name, and no Verified mark', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('Al Ananka Store'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsNothing,
      );
      expect(find.byType(FeaturedBadge), findsNothing);
    });

    testWidgets('shows the blue Verified mark when the business is verified', (
      tester,
    ) async {
      await _pump(tester, verified: true);

      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsOneWidget,
      );
    });

    testWidgets('shows the single Featured badge for a Featured business', (
      tester,
    ) async {
      await _pump(tester, post: _with(featured: true));

      expect(find.byType(FeaturedBadge), findsOneWidget);
    });
  });

  group('PostCard (P-114) - media and action row', () {
    testWidgets('media is a fixed 1:1 box', (tester) async {
      await _pump(tester);

      final AspectRatio box = tester.widget<AspectRatio>(
        find.descendant(
          of: find.byType(MediaCarousel),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(box.aspectRatio, 1);
    });

    testWidgets('left-to-right: Like, Comment, Share first, Save last', (
      tester,
    ) async {
      await _pump(tester);

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dx;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dx;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dx;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dx;

      expect(like, lessThan(comment));
      expect(comment, lessThan(share));
      expect(share, lessThan(save));
    });

    testWidgets('right-to-left: the same order, mirrored', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dx;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dx;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dx;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dx;

      expect(like, greaterThan(comment));
      expect(comment, greaterThan(share));
      expect(share, greaterThan(save));
    });

    testWidgets('the counts beside the icons are replaced by the likes line', (
      tester,
    ) async {
      await _pump(tester, post: _with(likes: 12, comments: 3));

      expect(find.text('12 likes'), findsOneWidget);
      // Not repeated as bare numbers next to the icons.
      expect(find.text('12'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('PostCard (P-114) - likes line, comments link, time', () {
    testWidgets('likes line: none for 0, singular for 1, compact for 1200', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.textContaining('like'), findsNothing);

      await _pump(tester, post: _with(likes: 1));
      expect(find.text('1 like'), findsOneWidget);

      await _pump(tester, post: _with(likes: 1200));
      expect(find.text('1.2K likes'), findsOneWidget);
    });

    testWidgets('comments link: "View 1 comment" and "View all 3 comments"', (
      tester,
    ) async {
      await _pump(tester, post: _with(comments: 1));
      expect(find.text('View 1 comment'), findsOneWidget);

      await _pump(tester, post: _with(comments: 3));
      expect(find.text('View all 3 comments'), findsOneWidget);
    });

    testWidgets('no comments link when there are no comments', (tester) async {
      await _pump(tester);

      expect(find.textContaining('comment'), findsNothing);
    });

    testWidgets('tapping the comments link calls onTap once', (tester) async {
      int taps = 0;
      await _pump(tester, post: _with(comments: 3), onTap: () => taps++);

      await tester.tap(find.text('View all 3 comments'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a long caption is cut with "more" and expands in place', (
      tester,
    ) async {
      final String longCaption = List<String>.filled(60, 'word').join(' ');
      await _pump(tester, post: _with(caption: longCaption));

      expect(find.text('more'), findsOneWidget);

      await tester.tap(find.text('more'));
      await tester.pump();

      expect(find.text('more'), findsNothing);
      expect(find.text(longCaption), findsOneWidget);
    });

    testWidgets('relative time is shown under the action row', (tester) async {
      await _pump(
        tester,
        post: _with(
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );

      expect(find.text('3 hours ago'), findsOneWidget);
    });
  });

  group('PostCard (P-114) - Arabic and Dark', () {
    testWidgets('Arabic: likes line and tooltips come from the ARB file', (
      tester,
    ) async {
      await _pump(
        tester,
        post: _with(likes: 1),
        locale: const Locale('ar'),
      );

      // "One like" (ar) and the Like tooltip (ar).
      expect(
        find.text('\u0625\u0639\u062c\u0627\u0628 \u0648\u0627\u062d\u062f'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('\u0625\u0639\u062c\u0627\u0628'),
        findsOneWidget,
      );
    });

    testWidgets('renders in Dark without errors', (tester) async {
      await _pump(
        tester,
        post: _with(likes: 5, comments: 2, featured: true),
        verified: true,
        theme: AppTheme.dark,
      );

      expect(find.byType(PostCard), findsOneWidget);
      expect(find.text('5 likes'), findsOneWidget);
    });
  });
}
'@
Write-RepoFile 'test\features\content\presentation\post_card_p114_test.dart' $t0
$t1 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/featured_badge.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the Instagram-style anatomy of [ReelCard], in English
/// (left-to-right) and Arabic (right-to-left), Light and Dark. The behavior
/// tests (Like, Comment, Report, tap) stay in `reel_card_test.dart`.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
PublicReel _reel({
  int likes = 0,
  int comments = 0,
  bool featured = false,
  String caption = 'Behind the scenes.',
}) {
  return PublicReel(
    id: 801,
    businessId: 7,
    caption: caption,
    likesCount: likes,
    commentsCount: comments,
    isFeatured: featured,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  PublicReel? reel,
  VoidCallback? onTap,
  bool verified = false,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: ReelCard(
            reel: reel ?? _reel(),
            businessName: 'Al Ananka Store',
            onTap: onTap,
            isBusinessVerified: verified,
          ),
        ),
      ),
    ),
  );
  // Let the deferred like/save seed of the action row land.
  await tester.pump();
}

/// The fixed 9:16 media box (the AspectRatio that holds the play mark).
Finder _media() => find.ancestor(
  of: find.byIcon(Icons.play_arrow),
  matching: find.byType(AspectRatio),
);

void main() {
  group('ReelCard (P-114) - media', () {
    testWidgets('media is a fixed 9:16 box', (tester) async {
      await _pump(tester);

      final AspectRatio box = tester.widget<AspectRatio>(_media());
      expect(box.aspectRatio, closeTo(9 / 16, 0.0001));
    });

    testWidgets('the caption is overlaid on the media, not below it', (
      tester,
    ) async {
      await _pump(tester);

      final Rect media = tester.getRect(_media());
      final Rect caption = tester.getRect(find.text('Behind the scenes.'));
      expect(caption.top, greaterThan(media.top));
      expect(caption.bottom, lessThanOrEqualTo(media.bottom));
    });

    testWidgets('the four actions are overlaid on the media', (tester) async {
      await _pump(tester);

      final Rect media = tester.getRect(_media());
      for (final IconData icon in <IconData>[
        Icons.favorite_border,
        Icons.mode_comment_outlined,
        Icons.share_outlined,
        Icons.bookmark_border,
      ]) {
        final Offset center = tester.getCenter(find.byIcon(icon));
        expect(media.contains(center), isTrue, reason: '$icon is outside');
      }
    });

    testWidgets('the counts are shown beside the overlaid actions', (
      tester,
    ) async {
      await _pump(tester, reel: _reel(likes: 12, comments: 3));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ReelCard (P-114) - reading direction', () {
    testWidgets('left-to-right: the actions sit at the right (end) side', (
      tester,
    ) async {
      await _pump(tester);

      final double middle = tester.getCenter(find.byType(ReelCard)).dx;
      expect(tester.getCenter(find.byIcon(Icons.favorite_border)).dx, greaterThan(middle));
    });

    testWidgets('right-to-left: the actions sit at the left (end) side', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('ar'));

      final double middle = tester.getCenter(find.byType(ReelCard)).dx;
      expect(tester.getCenter(find.byIcon(Icons.favorite_border)).dx, lessThan(middle));
    });

    testWidgets('Arabic tooltips come from the ARB file', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      // Like (ar) and Save (ar).
      expect(
        find.byTooltip('\u0625\u0639\u062c\u0627\u0628'),
        findsOneWidget,
      );
      expect(find.byTooltip('\u062d\u0641\u0638'), findsOneWidget);
    });
  });

  group('ReelCard (P-114) - header and theme', () {
    testWidgets('Verified mark and Featured badge show only when set', (
      tester,
    ) async {
      await _pump(tester);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsNothing,
      );
      expect(find.byType(FeaturedBadge), findsNothing);

      await _pump(tester, reel: _reel(featured: true), verified: true);
      expect(
        find.byKey(const ValueKey<String>('content_card_verified_mark')),
        findsOneWidget,
      );
      expect(find.byType(FeaturedBadge), findsOneWidget);
    });

    testWidgets('renders in Dark without errors', (tester) async {
      await _pump(
        tester,
        reel: _reel(likes: 5, comments: 2, featured: true),
        verified: true,
        theme: AppTheme.dark,
      );

      expect(find.byType(ReelCard), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
'@
Write-RepoFile 'test\features\content\presentation\reel_card_p114_test.dart' $t1
$t2 = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/presentation/content_action_row.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import 'fake_social_interaction_repository.dart';

/// Part P-114 STEP 2: the three looks of [ContentActionRow] (plain bar,
/// summary lines for posts, overlay column for reels). The behavior tests
/// (optimistic Like, Save, error revert) stay in `content_action_row_test.dart`
/// and run against the plain bar, which did not change.
///
/// This file is ASCII only: Arabic text is written as \uXXXX escapes.
Future<void> _pumpRow(
  WidgetTester tester, {
  int likes = 0,
  int comments = 0,
  bool summary = false,
  bool overlay = false,
  Widget? caption,
  VoidCallback? onComment,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: ContentActionRow(
              contentType: 'post',
              objectId: 1,
              onCommentTap: onComment ?? () {},
              likesCount: likes,
              commentsCount: comments,
              showSummaryLines: summary,
              summaryCaption: caption,
              overlay: overlay,
            ),
          ),
        ),
      ),
    ),
  );
  // Let the deferred seed land.
  await tester.pump();
}

void main() {
  group('ContentActionRow (P-114) - plain bar (unchanged look)', () {
    testWidgets('keeps the compact counts beside the icons, no likes line', (
      tester,
    ) async {
      await _pumpRow(tester, likes: 1200, comments: 3);

      expect(find.text('1.2K'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('likes'), findsNothing);
      expect(find.textContaining('View'), findsNothing);
    });

    testWidgets('icons use the primary text colour of the theme', (
      tester,
    ) async {
      await _pumpRow(tester);

      final Icon share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
      expect(share.color, AppColors.light.textPrimary);
    });
  });

  group('ContentActionRow (P-114) - summary lines', () {
    testWidgets('likes line, then the caption, then the comments link', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        likes: 12,
        comments: 3,
        summary: true,
        caption: const Text('Caption here'),
      );

      final double likes = tester.getTopLeft(find.text('12 likes')).dy;
      final double caption = tester.getTopLeft(find.text('Caption here')).dy;
      final double link =
          tester.getTopLeft(find.text('View all 3 comments')).dy;

      expect(likes, lessThan(caption));
      expect(caption, lessThan(link));
    });

    testWidgets('the counts beside the icons are hidden', (tester) async {
      await _pumpRow(tester, likes: 12, comments: 3, summary: true);

      expect(find.text('12'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('tapping the comments link calls onCommentTap', (tester) async {
      int taps = 0;
      await _pumpRow(
        tester,
        comments: 2,
        summary: true,
        onComment: () => taps++,
      );

      await tester.tap(find.text('View all 2 comments'));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('ContentActionRow (P-114) - overlay column', () {
    testWidgets('stacks Like, Comment, Share, Save top to bottom', (
      tester,
    ) async {
      await _pumpRow(tester, overlay: true);

      final double like = tester.getCenter(find.byIcon(Icons.favorite_border)).dy;
      final double comment =
          tester.getCenter(find.byIcon(Icons.mode_comment_outlined)).dy;
      final double share = tester.getCenter(find.byIcon(Icons.share_outlined)).dy;
      final double save =
          tester.getCenter(find.byIcon(Icons.bookmark_border)).dy;

      expect(like, lessThan(comment));
      expect(comment, lessThan(share));
      expect(share, lessThan(save));
    });

    testWidgets('icons are white and the counts are shown', (tester) async {
      await _pumpRow(tester, overlay: true, likes: 12, comments: 3);

      final Icon share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
      expect(share.color, const Color(0xFFFFFFFF));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ContentActionRow (P-114) - Arabic', () {
    testWidgets('tooltips come from the ARB file', (tester) async {
      await _pumpRow(tester, locale: const Locale('ar'));

      // Like, Comment, Share, Save in Arabic.
      expect(find.byTooltip('\u0625\u0639\u062c\u0627\u0628'), findsOneWidget);
      expect(find.byTooltip('\u062a\u0639\u0644\u064a\u0642'), findsOneWidget);
      expect(
        find.byTooltip('\u0645\u0634\u0627\u0631\u0643\u0629'),
        findsOneWidget,
      );
      expect(find.byTooltip('\u062d\u0641\u0638'), findsOneWidget);
    });
  });
}
'@
Write-RepoFile 'test\features\social\content_action_row_p114_test.dart' $t2
$t3 = @'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/features/feed/presentation/feed_skeleton.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 2: the Home feed skeletons replace the spinners. They are
/// built from the shared AppShimmerBox, keep the post card's fixed 1:1 media
/// box, and work in Light, Dark, left-to-right and right-to-left.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('FeedSkeletonList shows two post skeletons and no spinner', (
    tester,
  ) async {
    await _pump(tester, const FeedSkeletonList());

    expect(find.byType(FeedPostSkeleton), findsNWidgets(2));
    expect(find.byType(AppShimmerBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('FeedSkeletonList honours the count', (tester) async {
    await _pump(tester, const FeedSkeletonList(count: 3));

    expect(find.byType(FeedPostSkeleton), findsNWidgets(3));
  });

  testWidgets('a post skeleton keeps the fixed 1:1 media box', (tester) async {
    await _pump(tester, const FeedPostSkeleton(animate: false));

    final AspectRatio box = tester.widget<AspectRatio>(
      find.descendant(
        of: find.byType(FeedPostSkeleton),
        matching: find.byType(AspectRatio),
      ),
    );
    expect(box.aspectRatio, 1);
  });

  testWidgets('renders in Dark and in right-to-left without errors', (
    tester,
  ) async {
    await _pump(
      tester,
      const FeedSkeletonList(),
      theme: AppTheme.dark,
      locale: const Locale('ar'),
    );

    expect(find.byType(FeedPostSkeleton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
'@
Write-RepoFile 'test\features\feed\presentation\feed_skeleton_test.dart' $t3
$pc1Old = @'
        expect(find.text('1'), findsOneWidget);
'@
$pc1New = @'
        // Part P-114 STEP 2: the count is now the likes line under the icons.
        expect(find.text('1 like'), findsOneWidget);
'@
Patch-Once 'test\features\content\presentation\post_card_test.dart' $pc1Old $pc1New 'the count is now the likes line under the icons'
$pc2Old = @'
        expect(find.text('1'), findsNothing);
'@
$pc2New = @'
        expect(find.text('1 like'), findsNothing);
'@
Patch-Once 'test\features\content\presentation\post_card_test.dart' $pc2Old $pc2New 'find.text(''1 like''), findsNothing'
$hf1Old = @'
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
'@
$hf1New = @'
      // Part P-114 STEP 2: a skeleton, not a spinner, while the first page loads.
      expect(
        find.byKey(const ValueKey<String>('home_feed_skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
'@
Patch-Once 'test\features\feed\presentation\home_feed_screen_test.dart' $hf1Old $hf1New 'ValueKey<String>(''home_feed_skeleton'')'
$s25aOld = @'
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
'@
$s25aNew = @'
        // Part P-114 STEP 2: the bottom row is a skeleton card, not a spinner.
        expect(
          find.byKey(const ValueKey<String>('home_feed_loading_more')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
'@
Patch-Once 'test\features\feed\presentation\home_feed_screen_section25_test.dart' $s25aOld $s25aNew 'the bottom row is a skeleton card, not a spinner'
$s25bOld = @'
        expect(find.byType(CircularProgressIndicator), findsNothing);
        position = _position(tester);
'@
$s25bNew = @'
        expect(
          find.byKey(const ValueKey<String>('home_feed_loading_more')),
          findsNothing,
        );
        position = _position(tester);
'@
Patch-Once 'test\features\feed\presentation\home_feed_screen_section25_test.dart' $s25bOld $s25bNew 'home_feed_loading_more'')),
          findsNothing'

Write-Host ''
Write-Host '== 5/5 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'Done. Now run the tests from the STEP 2 message.' -ForegroundColor Green
git status --short