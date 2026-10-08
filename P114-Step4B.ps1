<#
  P114-Step4B.ps1
  PART P-114, STEP 4 (part B of 3) of 4: COMMENTS SHEET, Instagram style
  (bottom sheet with drag handle + title, scrolling avatar rows with relative time, skeleton
  instead of a spinner, pill input bar pinned above the keyboard, send icon through the RTL
  helper, every text localized). Presentation only: no provider, repository, DTO or route changes.
  (STEP 4A = product detail, already applied. STEP 4C = goldens + missing widget tests + notes.)

  Run from the ROOT of the cavallo-mobile repo (the folder that contains pubspec.yaml),
  on branch part-111 with STEP 4A applied:

      powershell -ExecutionPolicy Bypass -File .\P114-Step4B.ps1

  What it does:
    1. Checks the repo and that STEP 4A is in place.
    2. CREATES 1 test file (comments_sheet_p114_test.dart, 6 tests).
    3. REPLACES 3 files (comments_section, comment_list_widget, comment_input_widget), each only
       if it is exactly the version this step was built against (else it stops; -Force overwrites).
    4. PATCHES post_detail_screen.dart and reel_detail_screen.dart: the Comment icon now opens the
       sheet (showCommentsSheet) instead of scrolling. The inline comments block stays in the page.
    5. APPENDS 8 keys to app_en.arb and app_ar.arb, then runs flutter gen-l10n.
  Safe to run twice. Nothing is committed: undo with  git checkout -- .  and  git clean -fd lib test
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
  'lib\core\widgets\app_avatar.dart','lib\core\widgets\app_shimmer_box.dart','lib\core\l10n\formatters.dart',
  'lib\core\l10n\l10n_context.dart','lib\core\l10n\rtl_helpers.dart','lib\core\theme\app_colors.dart',
  'lib\features\social\presentation\comments_section.dart','lib\features\social\presentation\comment_list_widget.dart',
  'lib\features\social\presentation\comment_input_widget.dart','lib\features\social\presentation\comment_list_provider.dart',
  'lib\features\content\presentation\post_detail_screen.dart','lib\features\content\presentation\reel_detail_screen.dart',
  'test\features\social\comment_widgets_test.dart','test\features\social\fake_social_interaction_repository.dart',
  'lib\l10n\app_en.arb','lib\l10n\app_ar.arb')) {
  if (-not (Test-Path (Join-Path $RepoRoot (Fix-Rel $required)))) { Fail "Missing $required. Are you on branch part-111 with STEP 4A applied?" }
}
if (-not (Select-String -Path (Join-Path $RepoRoot (Fix-Rel 'lib\l10n\app_en.arb')) -Pattern '"productDetailTitle"' -Quiet)) { Fail 'app_en.arb has no productDetailTitle key: P-114 STEP 4A is not applied.' }
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
    Fail "$RelPath is not the version STEP 4B was built against (it has local changes, or STEP 4A / an earlier step was not applied exactly). Nothing was changed. Send me this file, or run again with -Force to overwrite it."
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
Write-Host '== 1/5 New test file ==' -ForegroundColor Cyan
$newTest = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/features/social/domain/comment_entity.dart';
import 'package:social_commerce_app/features/social/presentation/comment_input_widget.dart';
import 'package:social_commerce_app/features/social/presentation/comments_section.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import 'fake_social_interaction_repository.dart';

/// Part P-114 STEP 4B: the comments bottom sheet. Presentation only: these
/// tests prove the anatomy (sheet, avatar rows, skeleton, pinned input bar)
/// in English LTR, Arabic RTL and dark, and that posting still works.
CommentEntity _comment(int id, String text) => CommentEntity(
  id: id,
  userId: 100 + id,
  contentType: 'post',
  objectId: 1,
  text: text,
  isHidden: false,
  createdAt: DateTime.utc(2026, 9, 24, 10),
);

Widget _host(
  FakeSocialInteractionRepository fake, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [socialInteractionRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showCommentsSheet(context, contentType: 'post', objectId: 1),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

FakeSocialInteractionRepository _twoComments() =>
    FakeSocialInteractionRepository()
      ..commentsToReturn = [_comment(1, 'first one'), _comment(2, 'second one')];

void main() {
  group('comments sheet', () {
    testWidgets('opens as a bottom sheet with title, avatar rows and input',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(CommentsSheet), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('first one'), findsOneWidget);
      expect(find.text('second one'), findsOneWidget);
      expect(find.byType(AppAvatar), findsNWidgets(2));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Post comment'), findsOneWidget);
    });

    testWidgets('posting from the sheet still creates the comment',
        (WidgetTester tester) async {
      final FakeSocialInteractionRepository fake = _twoComments();
      await tester.pumpWidget(_host(fake));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sheet comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('createComment:post:1'));
      expect(find.text('sheet comment'), findsOneWidget);
    });

    testWidgets('shows a skeleton, not a spinner, while the list loads',
        (WidgetTester tester) async {
      final FakeSocialInteractionRepository fake =
          FakeSocialInteractionRepository()..gate = Completer<void>();
      await tester.pumpWidget(_host(fake));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      fake.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('No comments yet. Be the first to comment.'),
          findsOneWidget);
    });

    testWidgets('Arabic: RTL sheet with localized title and hint',
        (WidgetTester tester) async {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      await tester.pumpWidget(_host(_twoComments(), locale: const Locale('ar')));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(CommentsSheet))),
        TextDirection.rtl,
      );
      expect(find.text(ar.commentsTitle), findsOneWidget);
      expect(find.byTooltip(ar.commentsPostTooltip), findsOneWidget);
      expect(find.text(ar.commentsAuthorFallback('101')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments(), theme: AppTheme.dark));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('first one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the input bar stays above the keyboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_twoComments()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 300 logical px keyboard (the test view has a 3.0 pixel ratio).
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final double inputBottom = tester
          .getBottomLeft(find.byType(CommentInputWidget))
          .dy;
      final double screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(inputBottom, lessThanOrEqualTo(screenHeight - 300));
      expect(tester.takeException(), isNull);
    });
  });
}
'@
Write-RepoFile 'test\features\social\comments_sheet_p114_test.dart' $newTest

Write-Host ''
Write-Host '== 2/5 Replace presentation files ==' -ForegroundColor Cyan
$sec = @'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import 'comment_input_widget.dart';
import 'comment_list_widget.dart';

/// Part P-058: the whole comments block (title + input + list) for a
/// Post/Reel detail screen. Drop it into any scrollable body.
class ContentCommentsSection extends StatelessWidget {
  const ContentCommentsSection({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.commentsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        CommentInputWidget(contentType: contentType, objectId: objectId),
        const SizedBox(height: 8),
        CommentListWidget(contentType: contentType, objectId: objectId),
      ],
    );
  }
}

/// Part P-114 STEP 4B: opens the comments of one Post/Reel as a bottom sheet
/// (drag handle, title, scrolling avatar rows, input bar pinned above the
/// keyboard). It reuses [CommentListWidget] and [CommentInputWidget], so the
/// same providers and repository calls run as in the inline section.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String contentType,
  required int objectId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        CommentsSheet(contentType: contentType, objectId: objectId),
  );
}

/// The content of the comments bottom sheet. The input bar sits at the bottom
/// of the sheet and rises with the keyboard; only the list scrolls.
class CommentsSheet extends StatelessWidget {
  const CommentsSheet({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.appColors;
    final insets = media.viewInsets.bottom;
    final available = media.size.height - insets - media.padding.top - 24;
    final height = math.min(media.size.height * 0.85, available);

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: height,
        // A Scaffold (transparent, no inset handling of its own) lets a
        // SnackBar from a failed send show inside the sheet.
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    context.l10n.commentsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: colors.outline),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  child: CommentListWidget(
                    contentType: contentType,
                    objectId: objectId,
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: colors.outline),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  child: CommentInputWidget(
                    contentType: contentType,
                    objectId: objectId,
                  ),
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
Replace-RepoFile 'lib\features\social\presentation\comments_section.dart' 'b1e2b9d96348eae79d4dfcc5098fd4d99f17518037fe183d6c8641baad554713' $sec $false
$lst = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../domain/comment_entity.dart';
import 'comment_list_provider.dart';
import 'content_interaction_key.dart';
import 'content_overflow_menu.dart';

/// Part P-058 + P-114 STEP 4B: the comment list for one Post/Reel. Renders
/// exactly what the backend returns (no client-side hidden-comment
/// filtering). A comment with `isHidden: true` is only ever present for its
/// own author or a moderator, so it gets a subtle "pending review" marker.
///
/// P-114: avatar rows (AppAvatar), relative time (AppFormatters), a skeleton
/// instead of a spinner, every text from the ARB files. No provider, repository
/// or callback changed.
///
/// KNOWN GAP: the backend `user` field is a bare id (no username/avatar), so
/// authors render as "User #<id>" with the neutral avatar until a backend part
/// adds an author object.
class CommentListWidget extends ConsumerStatefulWidget {
  const CommentListWidget({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  ConsumerState<CommentListWidget> createState() => _CommentListWidgetState();
}

class _CommentListWidgetState extends ConsumerState<CommentListWidget> {
  ContentInteractionKey get _key =>
      (contentType: widget.contentType, objectId: widget.objectId);

  @override
  void initState() {
    super.initState();
    // Provider state can't be modified during the build phase, so defer.
    Future.microtask(() {
      if (mounted) {
        ref.read(commentListProvider(_key).notifier).loadFirstPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentListProvider(_key));
    final notifier = ref.read(commentListProvider(_key).notifier);
    final error = state.error;
    final colors = context.appColors;
    final l10n = context.l10n;

    if (state.isLoading && state.items.isEmpty) {
      return Semantics(
        label: l10n.commentsLoadingLabel,
        child: const ExcludeSemantics(
          child: Column(
            children: [
              _CommentSkeletonRow(),
              _CommentSkeletonRow(),
              _CommentSkeletonRow(),
            ],
          ),
        ),
      );
    }

    if (error != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            TextButton(
              onPressed: notifier.loadFirstPage,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.commentsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in state.items)
          _CommentTile(key: ValueKey(comment.id), comment: comment),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(error, style: TextStyle(color: colors.dangerText)),
          ),
        if (state.nextUrl != null)
          state.isLoadingMore
              ? const _CommentSkeletonRow()
              : Center(
                  child: TextButton(
                    onPressed: notifier.loadMore,
                    child: Text(l10n.commentsLoadMore),
                  ),
                ),
      ],
    );
  }
}

/// Skeleton of one comment row (avatar + two text lines).
class _CommentSkeletonRow extends StatelessWidget {
  const _CommentSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox.circle(size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(width: 110, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                AppShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({super.key, required this.comment});

  final CommentEntity comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = context.l10n;
    final author = l10n.commentsAuthorFallback(comment.userId.toString());
    final time = AppFormatters(l10n).relativeTime(comment.createdAt);
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(size: 36, semanticLabel: author),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(time, style: metaStyle),
                if (comment.isHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(l10n.commentsPendingReview, style: metaStyle),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ContentOverflowMenu(contentType: 'comment', objectId: comment.id),
        ],
      ),
    );
  }
}
'@
Replace-RepoFile 'lib\features\social\presentation\comment_list_widget.dart' 'fe1a548d728bb4526628981e0bda249b3022636263cb6e0763e3a4a1a4aecab7' $lst $false
$inp = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/social_interaction_repository_impl.dart';
import 'comment_list_provider.dart';
import 'content_interaction_key.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058 + P-114 STEP 4B: pill-shaped text field + send button. On
/// success the new comment is put on top of the local list and the comment
/// counter is bumped. On failure the text is kept and a SnackBar explains
/// why. Behaviour is unchanged; only the look, the localized texts and the
/// 44 px send target are new.
class CommentInputWidget extends ConsumerStatefulWidget {
  const CommentInputWidget({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  ConsumerState<CommentInputWidget> createState() => _CommentInputWidgetState();
}

class _CommentInputWidgetState extends ConsumerState<CommentInputWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  ContentInteractionKey get _key =>
      (contentType: widget.contentType, objectId: widget.objectId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final created = await ref
          .read(socialInteractionRepositoryProvider)
          .createComment(
            contentType: widget.contentType,
            objectId: widget.objectId,
            text: text,
          );
      if (!mounted) return;
      ref.read(commentListProvider(_key).notifier).addCreated(created);
      ref.read(contentInteractionProvider(_key).notifier).recordNewComment();
      _controller.clear();
      setState(() => _sending = false);
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(socialErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !_sending,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.commentsInputHint,
              isDense: true,
              filled: true,
              fillColor: colors.surfaceVariant,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                16,
                12,
                16,
                12,
              ),
              border: pill,
              enabledBorder: pill,
              disabledBorder: pill,
              focusedBorder: pill.copyWith(
                borderSide: BorderSide(color: colors.brand),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: _sending
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: DirectionalIcon(Icons.send, color: colors.brandText),
                  tooltip: l10n.commentsPostTooltip,
                  onPressed: _submit,
                ),
        ),
      ],
    );
  }
}
'@
Replace-RepoFile 'lib\features\social\presentation\comment_input_widget.dart' 'a544c7d871615f8550dc64ae6ebcc952983ae3d07049139806b455dbb42d3bb7' $inp $false

Write-Host ''
Write-Host '== 3/5 Comment icon opens the sheet (post + reel detail) ==' -ForegroundColor Cyan
$o = @'
  void _scrollToComments() {
    final target = _commentsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
'@
$n = @'
  void _openComments() {
    showCommentsSheet(context, contentType: 'post', objectId: widget.post.id);
  }
'@
$m = @'
void _openComments()
'@
Patch-Once 'lib\features\content\presentation\post_detail_screen.dart' $o $n $m
Patch-Once 'lib\features\content\presentation\post_detail_screen.dart' 'onCommentTap: _scrollToComments,' 'onCommentTap: _openComments,' 'onCommentTap: _openComments,'
$o = @'
  void _scrollToComments() {
    final target = _commentsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
'@
$n = @'
  void _openComments() {
    showCommentsSheet(context, contentType: 'reel', objectId: widget.reel.id);
  }
'@
$m = @'
void _openComments()
'@
Patch-Once 'lib\features\content\presentation\reel_detail_screen.dart' $o $n $m
Patch-Once 'lib\features\content\presentation\reel_detail_screen.dart' 'onCommentTap: _scrollToComments,' 'onCommentTap: _openComments,' 'onCommentTap: _openComments,'

Write-Host ''
Write-Host '== 4/5 ARB keys (8 per language) ==' -ForegroundColor Cyan
$enEntries = @'
  "commentsTitle": "Comments",
  "@commentsTitle": {
    "description": "Heading of the comments bottom sheet and of the inline comments block on post and reel detail screens."
  },
  "commentsInputHint": "Add a comment...",
  "@commentsInputHint": {
    "description": "Hint of the comment input field."
  },
  "commentsPostTooltip": "Post comment",
  "@commentsPostTooltip": {
    "description": "Tooltip and screen-reader label of the send button of the comment input."
  },
  "commentsEmpty": "No comments yet. Be the first to comment.",
  "@commentsEmpty": {
    "description": "Empty state of the comment list."
  },
  "commentsPendingReview": "Pending review: hidden from other users",
  "@commentsPendingReview": {
    "description": "Marker under a comment that is hidden pending moderation; only its author or a moderator sees it."
  },
  "commentsLoadMore": "Load more comments",
  "@commentsLoadMore": {
    "description": "Button that loads the next page of comments."
  },
  "commentsAuthorFallback": "User #{id}",
  "@commentsAuthorFallback": {
    "description": "Author name of a comment while the backend gives only the user id. id is the user id.",
    "placeholders": {
      "id": {
        "type": "String"
      }
    }
  },
  "commentsLoadingLabel": "Loading comments",
  "@commentsLoadingLabel": {
    "description": "Screen-reader label of the comment list loading skeleton."
  }
'@
$arEntries = @'
  "commentsTitle": "\u0627\u0644\u062a\u0639\u0644\u064a\u0642\u0627\u062a",
  "commentsInputHint": "\u0623\u0636\u0641 \u062a\u0639\u0644\u064a\u0642\u064b\u0627...",
  "commentsPostTooltip": "\u0646\u0634\u0631 \u0627\u0644\u062a\u0639\u0644\u064a\u0642",
  "commentsEmpty": "\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0639\u0644\u064a\u0642\u0627\u062a \u0628\u0639\u062f. \u0643\u0646 \u0623\u0648\u0644 \u0645\u0646 \u064a\u0639\u0644\u0651\u0642.",
  "commentsPendingReview": "\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629: \u0645\u062e\u0641\u064a \u0639\u0646 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646 \u0627\u0644\u0622\u062e\u0631\u064a\u0646",
  "commentsLoadMore": "\u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0632\u064a\u062f \u0645\u0646 \u0627\u0644\u062a\u0639\u0644\u064a\u0642\u0627\u062a",
  "commentsAuthorFallback": "\u0645\u0633\u062a\u062e\u062f\u0645 \u0631\u0642\u0645 {id}",
  "commentsLoadingLabel": "\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0639\u0644\u064a\u0642\u0627\u062a"
'@
Add-ArbEntries 'lib\l10n\app_en.arb' 'commentsTitle' (Expand-U $enEntries) 8
Add-ArbEntries 'lib\l10n\app_ar.arb' 'commentsTitle' (Expand-U $arEntries) 8

Write-Host ''
Write-Host '== 5/5 flutter gen-l10n ==' -ForegroundColor Cyan
if ($SkipGenL10n) {
  Write-Host '  skipped (-SkipGenL10n). Run: flutter gen-l10n'
} else {
  flutter gen-l10n
  if ($LASTEXITCODE -ne 0) { Fail 'flutter gen-l10n failed. Send me the output.' }
}

Write-Host ''
Write-Host 'STEP 4B applied. Next: flutter analyze, then the tests listed in the message.' -ForegroundColor Green