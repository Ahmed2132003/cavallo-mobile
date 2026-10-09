# ============================================================================
# P-115 / STEP 8A - Localization cleanup, part 1 of 2
#   * creates  test/l10n/no_hardcoded_strings_test.dart  (the repository guard)
#   * localizes the Staff moderation feature (queue, review, reject dialog,
#     priority badge, age chip) and the Business analytics screen
#   * adds 66 keys to app_en.arb / app_ar.arb (Arabic = pending native review)
#   * deletes the dead placeholder business_console_screen.dart (no route and
#     no import references it any more)
# Run from the repo root (D:\Cavallo\social_commerce_app) in PowerShell:
#     powershell -ExecutionPolicy Bypass -File .\p115_step8a_localization.ps1
# Safe to run: every expected line is checked FIRST. If one is missing the
# script stops before writing anything. Backups go to %TEMP%.
# ============================================================================
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Fail([string]$Message) {
    Write-Host ''
    Write-Host ("STOP: " + $Message) -ForegroundColor Red
    Write-Host 'Nothing was changed.' -ForegroundColor Red
    exit 1
}
function Read-Raw([string]$Path) { return [System.IO.File]::ReadAllText((Join-Path $root $Path), $utf8) }
function Write-Raw([string]$Path, [string]$Text) {
    $full = Join-Path $root $Path
    $dir = Split-Path -Parent $full
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($full, $Text, $utf8)
}
function Count-Occurrences([string]$Text, [string]$Needle) {
    $count = 0
    $index = 0
    while (($index = $Text.IndexOf($Needle, $index, [System.StringComparison]::Ordinal)) -ge 0) {
        $count++
        $index += $Needle.Length
    }
    return $count
}
function Get-Newline([string]$Text) {
    if ($Text.Contains("`r`n")) { return "`r`n" }
    return "`n"
}
function To-Newline([string]$Text, [string]$Newline) { return ($Text -replace "`r?`n", $Newline) }

# ---- 0. Preconditions -------------------------------------------------------
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) { Fail 'pubspec.yaml not found. Run this from the repo root.' }
if (-not (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^name:\s*social_commerce_app' -Quiet)) { Fail 'This is not the social_commerce_app repo.' }
if (Test-Path (Join-Path $root 'test/l10n/no_hardcoded_strings_test.dart')) { Fail 'test/l10n/no_hardcoded_strings_test.dart already exists: STEP 8A looks already applied.' }
$deadFile = 'lib/features/business_console/presentation/business_console_screen.dart'
$refs = Get-ChildItem -Path (Join-Path $root 'lib'), (Join-Path $root 'test') -Recurse -Filter *.dart | Select-String -SimpleMatch 'business_console_screen.dart'
if ($refs) { Fail ('business_console_screen.dart is still referenced, so it is not dead code: ' + (($refs | ForEach-Object { $_.Path + ':' + $_.LineNumber }) -join '; ')) }
Write-Host 'Preconditions OK.' -ForegroundColor Green

$edits = New-Object System.Collections.ArrayList
function Add-Edit([string]$Path, [string]$Old, [string]$New) {
    [void]$script:edits.Add(@{ Path = $Path; Old = $Old; New = $New })
}
# ---- edits: lib/features/moderation/presentation/moderation_widgets.dart
$old = @'
import '../../../core/widgets/app_status_chip.dart';
'@
$new = @'
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../l10n/app_localizations.dart';
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new
$old = @'
/// treated as zero.
String formatQueueAge(Duration age) {
  final totalMinutes = age.isNegative ? 0 : age.inMinutes;
  if (totalMinutes < 1) {
    return '<1 min';
  }
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final totalHours = totalMinutes ~/ 60;
  if (totalHours < 24) {
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$totalHours h' : '$totalHours h $minutes min';
  }
  final days = totalHours ~/ 24;
  final hours = totalHours % 24;
  return hours == 0 ? '$days d' : '$days d $hours h';
}
'@
$new = @'
/// treated as zero.
///
/// Part P-115 (STEP 8A): the words come from the ARB files. [l10n] is the
/// active language; without it the English texts are used (plain unit
/// tests have no widget tree).
String formatQueueAge(Duration age, {AppLocalizations? l10n}) {
  final texts = l10n ?? lookupAppLocalizations(const Locale('en'));
  final totalMinutes = age.isNegative ? 0 : age.inMinutes;
  if (totalMinutes < 1) {
    return texts.moderationAgeUnderMinute;
  }
  if (totalMinutes < 60) {
    return texts.moderationAgeMinutes(totalMinutes);
  }
  final totalHours = totalMinutes ~/ 60;
  if (totalHours < 24) {
    final minutes = totalMinutes % 60;
    return minutes == 0
        ? texts.moderationAgeHours(totalHours)
        : texts.moderationAgeHoursMinutes(totalHours, minutes);
  }
  final days = totalHours ~/ 24;
  final hours = totalHours % 24;
  return hours == 0
      ? texts.moderationAgeDays(days)
      : texts.moderationAgeDaysHours(days, hours);
}
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new
$old = @'
/// Display label for the backend's content-type model name
/// (`"post"` -> `"Post"`). Deliberately generic - no per-type table - so a
/// content type added in Phase 7/8 needs no change here.
String contentTypeLabel(String contentType) {
  if (contentType.isEmpty) {
    return 'Unknown';
  }
  return contentType[0].toUpperCase() + contentType.substring(1);
}
'@
$new = @'
/// Display label for the backend's content-type model name
/// (`"post"` -> `"Post"`). The three known types are localized; any content
/// type added later falls back to its capitalized backend name, so it needs
/// no change here to show up.
///
/// Part P-115 (STEP 8A): [l10n] is the active language; without it the
/// English texts are used.
String contentTypeLabel(String contentType, {AppLocalizations? l10n}) {
  final texts = l10n ?? lookupAppLocalizations(const Locale('en'));
  if (contentType.isEmpty) {
    return texts.moderationContentTypeUnknown;
  }
  return switch (contentType) {
    'post' => texts.moderationContentTypePost,
    'reel' => texts.moderationContentTypeReel,
    'story' => texts.moderationContentTypeStory,
    _ => contentType[0].toUpperCase() + contentType.substring(1),
  };
}
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new
$old = @'
              'Fast path',
'@
$new = @'
              context.l10n.moderationPriorityFast,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new
$old = @'
        'Normal',
'@
$new = @'
        context.l10n.moderationPriorityNormal,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new
$old = @'
    final label =
        urgency == QueueUrgency.breached
            ? '${formatQueueAge(age)} \u00B7 overdue'
            : formatQueueAge(age);
'@
$new = @'
    final l10n = context.l10n;
    final ageText = formatQueueAge(age, l10n: l10n);
    final label =
        urgency == QueueUrgency.breached
            ? l10n.moderationAgeOverdue(ageText)
            : ageText;
'@
Add-Edit 'lib/features/moderation/presentation/moderation_widgets.dart' $old $new

# ---- edits: lib/features/moderation/presentation/moderation_queue_screen.dart
$old = @'
import '../../../core/network/api_failure.dart';
'@
$new = @'
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
        title: const Text('Moderation queue'),
'@
$new = @'
        title: Text(context.l10n.moderationQueueTitle),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
            tooltip: 'Refresh',
'@
$new = @'
            tooltip: context.l10n.commonRefresh,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
      body: _buildBody(ref, queueAsync, items),
    );
  }

  Widget _buildBody(
    WidgetRef ref,
'@
$new = @'
      body: _buildBody(context, ref, queueAsync, items),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
        message: _loadErrorMessage(queueAsync.error),
'@
$new = @'
        message: _loadErrorMessage(context, queueAsync.error),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
      return const EmptyStateWidget(
        message: 'The queue is clear.\nNothing is waiting for review.',
        icon: Icons.task_alt,
'@
$new = @'
      return EmptyStateWidget(
        message: context.l10n.moderationQueueEmpty,
        icon: Icons.task_alt,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
String _loadErrorMessage(Object? error) {
  return switch (error) {
    DioException(error: AuthFailure()) =>
      'Your account is not allowed to review content. If it should be, '
          'ask an admin to add it to the Moderator group.',
    DioException(error: final ApiFailure failure) => failure.message,
    _ => 'Could not load the moderation queue.',
  };
}
'@
$new = @'
String _loadErrorMessage(BuildContext context, Object? error) {
  final l10n = context.l10n;
  return switch (error) {
    DioException(error: AuthFailure()) => l10n.moderationNotAllowed,
    DioException(error: final ApiFailure failure) => failure.message,
    _ => l10n.moderationQueueLoadFailed,
  };
}
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
    final text =
        fastPathCount == 0
            ? '${items.length} pending'
            : '${items.length} pending \u00B7 $fastPathCount fast path';
'@
$new = @'
    final l10n = context.l10n;
    final text =
        fastPathCount == 0
            ? l10n.moderationSummaryPending(items.length)
            : l10n.moderationSummaryPendingFast(items.length, fastPathCount);
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new
$old = @'
    final String shownText = hasPreview ? previewText : 'No preview available';
    final submitter = item.submitterBusinessName;
    final typeLine =
        submitter == null
            ? contentTypeLabel(item.contentType)
            : '${contentTypeLabel(item.contentType)} \u00B7 $submitter';
'@
$new = @'
    final String shownText =
        hasPreview ? previewText : context.l10n.moderationNoPreview;
    final submitter = item.submitterBusinessName;
    final typeLabel = contentTypeLabel(item.contentType, l10n: context.l10n);
    final typeLine =
        submitter == null ? typeLabel : '$typeLabel \u00B7 $submitter';
'@
Add-Edit 'lib/features/moderation/presentation/moderation_queue_screen.dart' $old $new

# ---- edits: lib/features/moderation/presentation/moderation_review_screen.dart
$old = @'
import '../../../core/network/api_failure.dart';
'@
$new = @'
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
import '../../../core/widgets/app_text_field.dart';
'@
$new = @'
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/app_localizations.dart';
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    final navigator = Navigator.of(context);
    setState(() => _approving = true);
'@
$new = @'
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _approving = true);
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
        messenger.showSnackBar(const SnackBar(content: Text(_alreadyHandled)));
        navigator.pop(false);
        return;
      }
      setState(() => _approving = false);
'@
$new = @'
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.moderationAlreadyHandled)),
        );
        navigator.pop(false);
        return;
      }
      setState(() => _approving = false);
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
            _actionErrorMessage(
              error,
              fallback: 'Could not approve this item. Please try again.',
            ),
'@
$new = @'
            _actionErrorMessage(
              error,
              fallback: l10n.moderationApproveFailed,
              l10n: l10n,
            ),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    messenger.showSnackBar(const SnackBar(content: Text('Item approved')));
'@
$new = @'
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.moderationItemApproved)),
    );
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    final navigator = Navigator.of(context);

    final outcome = await showDialog<_RejectOutcome>(
'@
$new = @'
    final navigator = Navigator.of(context);
    final l10n = context.l10n;

    final outcome = await showDialog<_RejectOutcome>(
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
        messenger.showSnackBar(const SnackBar(content: Text('Item rejected')));
        navigator.pop(true);
      case _RejectOutcome.alreadyHandled:
        messenger.showSnackBar(const SnackBar(content: Text(_alreadyHandled)));
        navigator.pop(false);
'@
$new = @'
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.moderationItemRejected)),
        );
        navigator.pop(true);
      case _RejectOutcome.alreadyHandled:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.moderationAlreadyHandled)),
        );
        navigator.pop(false);
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    final colors = context.appColors;
    final previewText = item.previewText;
'@
$new = @'
    final colors = context.appColors;
    final l10n = context.l10n;
    final previewText = item.previewText;
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
      appBar: AppBar(title: const Text('Review content')),
'@
$new = @'
      appBar: AppBar(title: Text(l10n.moderationReviewTitle)),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
            'Preview',
'@
$new = @'
            l10n.moderationPreview,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
            hasPreviewText ? previewText : 'No preview available',
'@
$new = @'
            hasPreviewText ? previewText : l10n.moderationNoPreview,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                    label: 'Type',
                    child: Text(contentTypeLabel(item.contentType)),
                  ),
                  if (submitter != null)
                    _DetailRow(label: 'Submitted by', child: Text(submitter)),
                  _DetailRow(
                    label: 'Priority',
'@
$new = @'
                    label: l10n.moderationDetailType,
                    child: Text(
                      contentTypeLabel(item.contentType, l10n: l10n),
                    ),
                  ),
                  if (submitter != null)
                    _DetailRow(
                      label: l10n.moderationDetailSubmittedBy,
                      child: Text(submitter),
                    ),
                  _DetailRow(
                    label: l10n.moderationDetailPriority,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                    label: 'Waiting',
'@
$new = @'
                    label: l10n.moderationDetailWaiting,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                  _DetailRow(label: 'Queue item', child: Text('#${item.id}')),
'@
$new = @'
                  _DetailRow(
                    label: l10n.moderationDetailQueueItem,
                    child: Text('#${item.id}'),
                  ),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                    'Waiting time is as of the last queue refresh.',
'@
$new = @'
                    l10n.moderationWaitingNote,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                  child: const Text('Reject'),
'@
$new = @'
                  child: Text(l10n.moderationReject),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
                  label: 'Approve',
'@
$new = @'
                  label: l10n.moderationApprove,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
/// Shown when the backend says the item is not pending anymore.
const String _alreadyHandled =
    'This item was already handled by someone else, or no longer exists. '
    'It has been removed from your queue.';

/// 409 = already decided, 404 = the row no longer exists (see
'@
$new = @'
/// 409 = already decided, 404 = the row no longer exists (see
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
String _actionErrorMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: AuthFailure()) =>
      'Your account is not allowed to review content. If it should be, '
          'ask an admin to add it to the Moderator group.',
'@
$new = @'
String _actionErrorMessage(
  Object error, {
  required String fallback,
  required AppLocalizations l10n,
}) {
  return switch (error) {
    DioException(error: AuthFailure()) => l10n.moderationNotAllowed,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
'@
$new = @'
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() {
      _submitting = true;
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
        _error = _actionErrorMessage(
          error,
          fallback: 'Could not reject this item. Please try again.',
        );
'@
$new = @'
        _error = _actionErrorMessage(
          error,
          fallback: l10n.moderationRejectFailed,
          l10n: l10n,
        );
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
    final colors = context.appColors;
    final showRequired = _touched && !_hasReason;
'@
$new = @'
    final colors = context.appColors;
    final l10n = context.l10n;
    final showRequired = _touched && !_hasReason;
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
      title: const Text('Reject content'),
'@
$new = @'
      title: Text(l10n.moderationRejectTitle),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
            'The business will see this reason.',
'@
$new = @'
            l10n.moderationRejectNote,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
            label: 'Reason (required)',
'@
$new = @'
            label: l10n.moderationRejectReasonLabel,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
              'A reason is required.',
'@
$new = @'
              l10n.moderationRejectReasonRequired,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
          child: const Text('Cancel'),
'@
$new = @'
          child: Text(l10n.commonCancel),
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new
$old = @'
          label: 'Reject',
          variant: AppButtonVariant.danger,
'@
$new = @'
          label: l10n.moderationReject,
          variant: AppButtonVariant.danger,
'@
Add-Edit 'lib/features/moderation/presentation/moderation_review_screen.dart' $old $new

# ---- edits: lib/features/business_console/presentation/analytics_screen.dart
$old = @'
import '../../../core/network/api_failure.dart';
'@
$new = @'
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
      appBar: AppBar(title: const Text('Analytics')),
'@
$new = @'
      appBar: AppBar(title: Text(context.l10n.consoleNavAnalytics)),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
    int days,
  ) {
    // A finished failure wins over any stale value;
'@
$new = @'
    int days,
  ) {
    final l10n = context.l10n;
    // A finished failure wins over any stale value;
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
          message: _loadErrorMessage(statsAsync.error),
'@
$new = @'
          message: _loadErrorMessage(context, statsAsync.error),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            message:
                'No activity has been recorded for the last $days days yet.',
'@
$new = @'
            message: l10n.analyticsEmpty(days),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
        'Days with data: $withData of $days',
'@
$new = @'
        l10n.analyticsDaysWithData(withData, days),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
        'Days are counted in UTC. Days without a recorded row are not '
        'drawn as zero.',
'@
$new = @'
        l10n.analyticsUtcNote,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
        title: 'New followers by day',
        semanticsLabel:
            'New followers: ${totals.newFollowers} total over $days days',
'@
$new = @'
        title: l10n.analyticsChartFollowersTitle,
        semanticsLabel: l10n.analyticsChartFollowersSemantics(
          days,
          totals.newFollowers,
        ),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
        title: 'Likes received by day',
        semanticsLabel:
            'Likes received: ${totals.likesReceived} total over $days days',
'@
$new = @'
        title: l10n.analyticsChartLikesTitle,
        semanticsLabel: l10n.analyticsChartLikesSemantics(
          days,
          totals.likesReceived,
        ),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
      const _SectionHeading('Ratings'),
'@
$new = @'
      _SectionHeading(l10n.analyticsRatingsHeading),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
          'No rating has been recorded yet, so there is no rating trend '
          'to draw.',
'@
$new = @'
          l10n.analyticsRatingEmpty,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
          title: 'Average rating by day',
          semanticsLabel:
              'Average rating: latest '
              '${ratings.latestAverage?.toStringAsFixed(2)} over $days days',
'@
$new = @'
          title: l10n.analyticsChartRatingTitle,
          semanticsLabel: l10n.analyticsChartRatingSemantics(
            days,
            ratings.latestAverage?.toStringAsFixed(2) ?? '',
          ),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
          'Each point is the average rating stored when that day was rolled '
          'up. Days before the first rating are not drawn.',
'@
$new = @'
          l10n.analyticsRatingNote,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
        const _SectionHeading('Catalog size'),
'@
$new = @'
        _SectionHeading(l10n.analyticsCatalogHeading),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
          'As of ${catalog.asOf.day}/${catalog.asOf.month} (UTC). These are '
          'totals recorded by the daily rollup, not daily changes.',
'@
$new = @'
          l10n.analyticsCatalogAsOf(catalog.asOf.day, catalog.asOf.month),
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
String _loadErrorMessage(Object? error) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    _ => 'Could not load your analytics.',
  };
}
'@
$new = @'
String _loadErrorMessage(BuildContext context, Object? error) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    _ => context.l10n.analyticsLoadFailed,
  };
}
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: 7,
          label: Text('7 days', key: ValueKey('analytics-range-7')),
        ),
        ButtonSegment(
          value: 14,
          label: Text('14 days', key: ValueKey('analytics-range-14')),
        ),
        ButtonSegment(
          value: 30,
          label: Text('30 days', key: ValueKey('analytics-range-30')),
        ),
      ],
'@
$new = @'
    final l10n = context.l10n;
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: 7,
          label: Text(
            l10n.analyticsRangeDays(7),
            key: const ValueKey('analytics-range-7'),
          ),
        ),
        ButtonSegment(
          value: 14,
          label: Text(
            l10n.analyticsRangeDays(14),
            key: const ValueKey('analytics-range-14'),
          ),
        ),
        ButtonSegment(
          value: 30,
          label: Text(
            l10n.analyticsRangeDays(30),
            key: const ValueKey('analytics-range-30'),
          ),
        ),
      ],
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
  final AnalyticsTotals totals;

  @override
  Widget build(BuildContext context) {
    return Column(
'@
$new = @'
  final AnalyticsTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
                label: 'New followers',
'@
$new = @'
                label: l10n.analyticsNewFollowers,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
                label: 'Likes received',
'@
$new = @'
                label: l10n.analyticsLikesReceived,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
                label: 'Comments received',
'@
$new = @'
                label: l10n.analyticsCommentsReceived,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
                label: 'Story views',
'@
$new = @'
                label: l10n.analyticsStoryViews,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
    final latest = summary.latestAverage;
    return Row(
'@
$new = @'
    final latest = summary.latestAverage;
    final l10n = context.l10n;
    return Row(
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'New ratings',
'@
$new = @'
            label: l10n.analyticsNewRatings,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'Average rating',
'@
$new = @'
            label: l10n.analyticsAverageRating,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    return Row(
'@
$new = @'
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'Active products',
'@
$new = @'
            label: l10n.analyticsActiveProducts,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'Published posts',
'@
$new = @'
            label: l10n.analyticsPublishedPosts,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'Published reels',
'@
$new = @'
            label: l10n.analyticsPublishedReels,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new
$old = @'
            label: 'Retry',
            onPressed: onRetry,
'@
$new = @'
            label: context.l10n.commonRetry,
            onPressed: onRetry,
'@
Add-Edit 'lib/features/business_console/presentation/analytics_screen.dart' $old $new

# ---- ARB entries
$arbEn = @'
  "commonRefresh": "Refresh",
  "@commonRefresh": {
    "description": "Generic refresh button / tooltip."
  },
  "commonCancel": "Cancel",
  "@commonCancel": {
    "description": "Generic cancel button of a dialog."
  },
  "moderationQueueTitle": "Moderation queue",
  "@moderationQueueTitle": {
    "description": "Staff: title of the moderation queue screen."
  },
  "moderationQueueEmpty": "The queue is clear.\nNothing is waiting for review.",
  "@moderationQueueEmpty": {
    "description": "Staff: empty state of the moderation queue."
  },
  "moderationNotAllowed": "Your account is not allowed to review content. If it should be, ask an admin to add it to the Moderator group.",
  "@moderationNotAllowed": {
    "description": "Staff: shown when the API answers 403 for a moderation call."
  },
  "moderationQueueLoadFailed": "Could not load the moderation queue.",
  "@moderationQueueLoadFailed": {
    "description": "Staff: generic load failure of the moderation queue."
  },
  "moderationSummaryPending": "{count} pending",
  "@moderationSummaryPending": {
    "description": "Staff: queue summary line. count is the number of pending items.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "moderationSummaryPendingFast": "{count} pending \u00b7 {fast} fast path",
  "@moderationSummaryPendingFast": {
    "description": "Staff: queue summary line when some items are fast path.",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "fast": {
        "type": "int"
      }
    }
  },
  "moderationNoPreview": "No preview available",
  "@moderationNoPreview": {
    "description": "Staff: placeholder when a queue item has no preview text."
  },
  "moderationPriorityFast": "Fast path",
  "@moderationPriorityFast": {
    "description": "Staff: priority badge of a fast path item."
  },
  "moderationPriorityNormal": "Normal",
  "@moderationPriorityNormal": {
    "description": "Staff: priority badge of a normal item."
  },
  "moderationAgeUnderMinute": "<1 min",
  "@moderationAgeUnderMinute": {
    "description": "Staff: waiting time shorter than one minute."
  },
  "moderationAgeMinutes": "{minutes} min",
  "@moderationAgeMinutes": {
    "description": "Staff: waiting time in minutes.",
    "placeholders": {
      "minutes": {
        "type": "int"
      }
    }
  },
  "moderationAgeHours": "{hours} h",
  "@moderationAgeHours": {
    "description": "Staff: waiting time in whole hours.",
    "placeholders": {
      "hours": {
        "type": "int"
      }
    }
  },
  "moderationAgeHoursMinutes": "{hours} h {minutes} min",
  "@moderationAgeHoursMinutes": {
    "description": "Staff: waiting time in hours and minutes.",
    "placeholders": {
      "hours": {
        "type": "int"
      },
      "minutes": {
        "type": "int"
      }
    }
  },
  "moderationAgeDays": "{days} d",
  "@moderationAgeDays": {
    "description": "Staff: waiting time in whole days.",
    "placeholders": {
      "days": {
        "type": "int"
      }
    }
  },
  "moderationAgeDaysHours": "{days} d {hours} h",
  "@moderationAgeDaysHours": {
    "description": "Staff: waiting time in days and hours.",
    "placeholders": {
      "days": {
        "type": "int"
      },
      "hours": {
        "type": "int"
      }
    }
  },
  "moderationAgeOverdue": "{age} \u00b7 overdue",
  "@moderationAgeOverdue": {
    "description": "Staff: waiting time chip text when the SLA is breached. age is the already formatted waiting time.",
    "placeholders": {
      "age": {
        "type": "String"
      }
    }
  },
  "moderationContentTypePost": "Post",
  "@moderationContentTypePost": {
    "description": "Staff: content type label."
  },
  "moderationContentTypeReel": "Reel",
  "@moderationContentTypeReel": {
    "description": "Staff: content type label."
  },
  "moderationContentTypeStory": "Story",
  "@moderationContentTypeStory": {
    "description": "Staff: content type label."
  },
  "moderationContentTypeUnknown": "Unknown",
  "@moderationContentTypeUnknown": {
    "description": "Staff: content type label when the backend sent none."
  },
  "moderationReviewTitle": "Review content",
  "@moderationReviewTitle": {
    "description": "Staff: title of the review screen."
  },
  "moderationPreview": "Preview",
  "@moderationPreview": {
    "description": "Staff: caption above the preview text on the review screen."
  },
  "moderationDetailType": "Type",
  "@moderationDetailType": {
    "description": "Staff: review details row label."
  },
  "moderationDetailSubmittedBy": "Submitted by",
  "@moderationDetailSubmittedBy": {
    "description": "Staff: review details row label."
  },
  "moderationDetailPriority": "Priority",
  "@moderationDetailPriority": {
    "description": "Staff: review details row label."
  },
  "moderationDetailWaiting": "Waiting",
  "@moderationDetailWaiting": {
    "description": "Staff: review details row label."
  },
  "moderationDetailQueueItem": "Queue item",
  "@moderationDetailQueueItem": {
    "description": "Staff: review details row label."
  },
  "moderationWaitingNote": "Waiting time is as of the last queue refresh.",
  "@moderationWaitingNote": {
    "description": "Staff: note under the review details."
  },
  "moderationReject": "Reject",
  "@moderationReject": {
    "description": "Staff: reject button and confirm button."
  },
  "moderationApprove": "Approve",
  "@moderationApprove": {
    "description": "Staff: approve button."
  },
  "moderationItemApproved": "Item approved",
  "@moderationItemApproved": {
    "description": "Staff: snackbar after approving."
  },
  "moderationItemRejected": "Item rejected",
  "@moderationItemRejected": {
    "description": "Staff: snackbar after rejecting."
  },
  "moderationApproveFailed": "Could not approve this item. Please try again.",
  "@moderationApproveFailed": {
    "description": "Staff: fallback error when approving fails."
  },
  "moderationRejectFailed": "Could not reject this item. Please try again.",
  "@moderationRejectFailed": {
    "description": "Staff: fallback error when rejecting fails."
  },
  "moderationAlreadyHandled": "This item was already handled by someone else, or no longer exists. It has been removed from your queue.",
  "@moderationAlreadyHandled": {
    "description": "Staff: snackbar when the item is no longer pending."
  },
  "moderationRejectTitle": "Reject content",
  "@moderationRejectTitle": {
    "description": "Staff: title of the reject dialog."
  },
  "moderationRejectNote": "The business will see this reason.",
  "@moderationRejectNote": {
    "description": "Staff: note in the reject dialog. The rejection reason is always visible to the business."
  },
  "moderationRejectReasonLabel": "Reason (required)",
  "@moderationRejectReasonLabel": {
    "description": "Staff: label of the reason field in the reject dialog."
  },
  "moderationRejectReasonRequired": "A reason is required.",
  "@moderationRejectReasonRequired": {
    "description": "Staff: validation text under the reason field."
  },
  "analyticsLoadFailed": "Could not load your analytics.",
  "@analyticsLoadFailed": {
    "description": "Business: analytics load failure."
  },
  "analyticsEmpty": "{days, plural, one{No activity has been recorded for the last day yet.} other{No activity has been recorded for the last {days} days yet.}}",
  "@analyticsEmpty": {
    "description": "Business: analytics empty state. days is the exact range (it picks the plural form).",
    "placeholders": {
      "days": {
        "type": "int"
      }
    }
  },
  "analyticsDaysWithData": "Days with data: {withData} of {days}",
  "@analyticsDaysWithData": {
    "description": "Business: how many days of the range have a recorded row.",
    "placeholders": {
      "withData": {
        "type": "int"
      },
      "days": {
        "type": "int"
      }
    }
  },
  "analyticsUtcNote": "Days are counted in UTC. Days without a recorded row are not drawn as zero.",
  "@analyticsUtcNote": {
    "description": "Business: note under the analytics totals."
  },
  "analyticsChartFollowersTitle": "New followers by day",
  "@analyticsChartFollowersTitle": {
    "description": "Business: chart title."
  },
  "analyticsChartFollowersSemantics": "{days, plural, one{New followers: {total} total over 1 day} other{New followers: {total} total over {days} days}}",
  "@analyticsChartFollowersSemantics": {
    "description": "Business: screen reader summary of the followers chart. days picks the plural form.",
    "placeholders": {
      "days": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "analyticsChartLikesTitle": "Likes received by day",
  "@analyticsChartLikesTitle": {
    "description": "Business: chart title."
  },
  "analyticsChartLikesSemantics": "{days, plural, one{Likes received: {total} total over 1 day} other{Likes received: {total} total over {days} days}}",
  "@analyticsChartLikesSemantics": {
    "description": "Business: screen reader summary of the likes chart. days picks the plural form.",
    "placeholders": {
      "days": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "analyticsRatingsHeading": "Ratings",
  "@analyticsRatingsHeading": {
    "description": "Business: section heading."
  },
  "analyticsRatingEmpty": "No rating has been recorded yet, so there is no rating trend to draw.",
  "@analyticsRatingEmpty": {
    "description": "Business: shown when there is no rating in the range."
  },
  "analyticsChartRatingTitle": "Average rating by day",
  "@analyticsChartRatingTitle": {
    "description": "Business: chart title."
  },
  "analyticsChartRatingSemantics": "{days, plural, one{Average rating: latest {average} over 1 day} other{Average rating: latest {average} over {days} days}}",
  "@analyticsChartRatingSemantics": {
    "description": "Business: screen reader summary of the rating chart. days picks the plural form; average is the formatted latest average.",
    "placeholders": {
      "days": {
        "type": "int"
      },
      "average": {
        "type": "String"
      }
    }
  },
  "analyticsRatingNote": "Each point is the average rating stored when that day was rolled up. Days before the first rating are not drawn.",
  "@analyticsRatingNote": {
    "description": "Business: note under the rating chart."
  },
  "analyticsCatalogHeading": "Catalog size",
  "@analyticsCatalogHeading": {
    "description": "Business: section heading."
  },
  "analyticsCatalogAsOf": "As of {day}/{month} (UTC). These are totals recorded by the daily rollup, not daily changes.",
  "@analyticsCatalogAsOf": {
    "description": "Business: note above the catalog size cards.",
    "placeholders": {
      "day": {
        "type": "int"
      },
      "month": {
        "type": "int"
      }
    }
  },
  "analyticsRangeDays": "{days, plural, one{{days} day} other{{days} days}}",
  "@analyticsRangeDays": {
    "description": "Business: label of a range segment (7 / 14 / 30 days).",
    "placeholders": {
      "days": {
        "type": "int"
      }
    }
  },
  "analyticsNewFollowers": "New followers",
  "@analyticsNewFollowers": {
    "description": "Business: analytics card label."
  },
  "analyticsLikesReceived": "Likes received",
  "@analyticsLikesReceived": {
    "description": "Business: analytics card label."
  },
  "analyticsCommentsReceived": "Comments received",
  "@analyticsCommentsReceived": {
    "description": "Business: analytics card label."
  },
  "analyticsStoryViews": "Story views",
  "@analyticsStoryViews": {
    "description": "Business: analytics card label."
  },
  "analyticsNewRatings": "New ratings",
  "@analyticsNewRatings": {
    "description": "Business: analytics card label."
  },
  "analyticsAverageRating": "Average rating",
  "@analyticsAverageRating": {
    "description": "Business: analytics card label."
  },
  "analyticsActiveProducts": "Active products",
  "@analyticsActiveProducts": {
    "description": "Business: analytics card label."
  },
  "analyticsPublishedPosts": "Published posts",
  "@analyticsPublishedPosts": {
    "description": "Business: analytics card label."
  },
  "analyticsPublishedReels": "Published reels",
  "@analyticsPublishedReels": {
    "description": "Business: analytics card label."
  }
'@
$arbAr = @'
  "commonRefresh": "\u062a\u062d\u062f\u064a\u062b",
  "commonCancel": "\u0625\u0644\u063a\u0627\u0621",
  "moderationQueueTitle": "\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "moderationQueueEmpty": "\u0627\u0644\u0642\u0627\u0626\u0645\u0629 \u0641\u0627\u0631\u063a\u0629.\n\u0644\u0627 \u064a\u0648\u062c\u062f \u0634\u064a\u0621 \u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629.",
  "moderationNotAllowed": "\u062d\u0633\u0627\u0628\u0643 \u063a\u064a\u0631 \u0645\u0633\u0645\u0648\u062d \u0644\u0647 \u0628\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u062a\u0648\u0649. \u0625\u0630\u0627 \u0643\u0627\u0646 \u064a\u062c\u0628 \u0623\u0646 \u064a\u064f\u0633\u0645\u062d \u0644\u0647\u060c \u0641\u0627\u0637\u0644\u0628 \u0645\u0646 \u0627\u0644\u0645\u0633\u0624\u0648\u0644 \u0625\u0636\u0627\u0641\u062a\u0647 \u0625\u0644\u0649 \u0645\u062c\u0645\u0648\u0639\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u064a\u0646.",
  "moderationQueueLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629.",
  "moderationSummaryPending": "{count} \u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629",
  "moderationSummaryPendingFast": "{count} \u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u00b7 {fast} \u0645\u0633\u0627\u0631 \u0633\u0631\u064a\u0639",
  "moderationNoPreview": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0639\u0627\u064a\u0646\u0629",
  "moderationPriorityFast": "\u0645\u0633\u0627\u0631 \u0633\u0631\u064a\u0639",
  "moderationPriorityNormal": "\u0639\u0627\u062f\u064a",
  "moderationAgeUnderMinute": "\u0623\u0642\u0644 \u0645\u0646 \u062f\u0642\u064a\u0642\u0629",
  "moderationAgeMinutes": "{minutes} \u062f",
  "moderationAgeHours": "{hours} \u0633",
  "moderationAgeHoursMinutes": "{hours} \u0633 {minutes} \u062f",
  "moderationAgeDays": "{days} \u064a\u0648\u0645",
  "moderationAgeDaysHours": "{days} \u064a\u0648\u0645 {hours} \u0633",
  "moderationAgeOverdue": "{age} \u00b7 \u0645\u062a\u0623\u062e\u0631",
  "moderationContentTypePost": "\u0645\u0646\u0634\u0648\u0631",
  "moderationContentTypeReel": "\u0631\u064a\u0644",
  "moderationContentTypeStory": "\u0633\u062a\u0648\u0631\u064a",
  "moderationContentTypeUnknown": "\u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641",
  "moderationReviewTitle": "\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u062d\u062a\u0648\u0649",
  "moderationPreview": "\u0627\u0644\u0645\u0639\u0627\u064a\u0646\u0629",
  "moderationDetailType": "\u0627\u0644\u0646\u0648\u0639",
  "moderationDetailSubmittedBy": "\u0623\u0631\u0633\u0644\u0647",
  "moderationDetailPriority": "\u0627\u0644\u0623\u0648\u0644\u0648\u064a\u0629",
  "moderationDetailWaiting": "\u0645\u062f\u0629 \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631",
  "moderationDetailQueueItem": "\u0639\u0646\u0635\u0631 \u0627\u0644\u0642\u0627\u0626\u0645\u0629",
  "moderationWaitingNote": "\u0645\u062f\u0629 \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631 \u0645\u062d\u0633\u0648\u0628\u0629 \u062d\u062a\u0649 \u0622\u062e\u0631 \u062a\u062d\u062f\u064a\u062b \u0644\u0644\u0642\u0627\u0626\u0645\u0629.",
  "moderationReject": "\u0631\u0641\u0636",
  "moderationApprove": "\u0645\u0648\u0627\u0641\u0642\u0629",
  "moderationItemApproved": "\u062a\u0645\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0627\u0644\u0639\u0646\u0635\u0631",
  "moderationItemRejected": "\u062a\u0645 \u0631\u0641\u0636 \u0627\u0644\u0639\u0646\u0635\u0631",
  "moderationApproveFailed": "\u062a\u0639\u0630\u0651\u0631\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0647\u0630\u0627 \u0627\u0644\u0639\u0646\u0635\u0631. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "moderationRejectFailed": "\u062a\u0639\u0630\u0651\u0631 \u0631\u0641\u0636 \u0647\u0630\u0627 \u0627\u0644\u0639\u0646\u0635\u0631. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "moderationAlreadyHandled": "\u062a\u0645\u062a \u0645\u0639\u0627\u0644\u062c\u0629 \u0647\u0630\u0627 \u0627\u0644\u0639\u0646\u0635\u0631 \u0628\u0648\u0627\u0633\u0637\u0629 \u0634\u062e\u0635 \u0622\u062e\u0631 \u0623\u0648 \u0644\u0645 \u064a\u0639\u062f \u0645\u0648\u062c\u0648\u062f\u064b\u0627. \u062a\u0645\u062a \u0625\u0632\u0627\u0644\u062a\u0647 \u0645\u0646 \u0642\u0627\u0626\u0645\u062a\u0643.",
  "moderationRejectTitle": "\u0631\u0641\u0636 \u0627\u0644\u0645\u062d\u062a\u0648\u0649",
  "moderationRejectNote": "\u0633\u064a\u0631\u0649 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a \u0647\u0630\u0627 \u0627\u0644\u0633\u0628\u0628.",
  "moderationRejectReasonLabel": "\u0627\u0644\u0633\u0628\u0628 (\u0645\u0637\u0644\u0648\u0628)",
  "moderationRejectReasonRequired": "\u0627\u0644\u0633\u0628\u0628 \u0645\u0637\u0644\u0648\u0628.",
  "analyticsLoadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a.",
  "analyticsEmpty": "{days, plural, zero{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 {days} \u064a\u0648\u0645 \u0628\u0639\u062f.} one{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 \u064a\u0648\u0645 \u0628\u0639\u062f.} two{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 \u064a\u0648\u0645\u064a\u0646 \u0628\u0639\u062f.} few{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 {days} \u0623\u064a\u0627\u0645 \u0628\u0639\u062f.} many{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 {days} \u064a\u0648\u0645\u064b\u0627 \u0628\u0639\u062f.} other{\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u0646\u0634\u0627\u0637 \u062e\u0644\u0627\u0644 \u0622\u062e\u0631 {days} \u064a\u0648\u0645 \u0628\u0639\u062f.}}",
  "analyticsDaysWithData": "\u0623\u064a\u0627\u0645 \u0628\u0647\u0627 \u0628\u064a\u0627\u0646\u0627\u062a: {withData} \u0645\u0646 {days}",
  "analyticsUtcNote": "\u062a\u064f\u062d\u062a\u0633\u0628 \u0627\u0644\u0623\u064a\u0627\u0645 \u0628\u0627\u0644\u062a\u0648\u0642\u064a\u062a \u0627\u0644\u0639\u0627\u0644\u0645\u064a \u0627\u0644\u0645\u0646\u0633\u0651\u0642 (UTC). \u0627\u0644\u0623\u064a\u0627\u0645 \u0627\u0644\u062a\u064a \u0644\u0627 \u064a\u0648\u062c\u062f \u0644\u0647\u0627 \u0633\u062c\u0644 \u0644\u0627 \u062a\u064f\u0631\u0633\u0645 \u0639\u0644\u0649 \u0623\u0646\u0647\u0627 \u0635\u0641\u0631.",
  "analyticsChartFollowersTitle": "\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f \u062d\u0633\u0628 \u0627\u0644\u064a\u0648\u0645",
  "analyticsChartFollowersSemantics": "{days, plural, zero{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645} one{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 \u064a\u0648\u0645 \u0648\u0627\u062d\u062f} two{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 \u064a\u0648\u0645\u064a\u0646} few{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u0623\u064a\u0627\u0645} many{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645\u064b\u0627} other{\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u0627\u0644\u062c\u062f\u062f: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645}}",
  "analyticsChartLikesTitle": "\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629 \u062d\u0633\u0628 \u0627\u0644\u064a\u0648\u0645",
  "analyticsChartLikesSemantics": "{days, plural, zero{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645} one{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 \u064a\u0648\u0645 \u0648\u0627\u062d\u062f} two{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 \u064a\u0648\u0645\u064a\u0646} few{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u0623\u064a\u0627\u0645} many{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645\u064b\u0627} other{\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629: {total} \u0625\u062c\u0645\u0627\u0644\u064b\u0627 \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645}}",
  "analyticsRatingsHeading": "\u0627\u0644\u062a\u0642\u064a\u064a\u0645\u0627\u062a",
  "analyticsRatingEmpty": "\u0644\u0645 \u064a\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0623\u064a \u062a\u0642\u064a\u064a\u0645 \u0628\u0639\u062f\u060c \u0644\u0630\u0644\u0643 \u0644\u0627 \u064a\u0648\u062c\u062f \u0627\u062a\u062c\u0627\u0647 \u062a\u0642\u064a\u064a\u0645 \u0644\u0631\u0633\u0645\u0647.",
  "analyticsChartRatingTitle": "\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645 \u062d\u0633\u0628 \u0627\u0644\u064a\u0648\u0645",
  "analyticsChartRatingSemantics": "{days, plural, zero{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645} one{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 \u064a\u0648\u0645 \u0648\u0627\u062d\u062f} two{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 \u064a\u0648\u0645\u064a\u0646} few{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 {days} \u0623\u064a\u0627\u0645} many{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645\u064b\u0627} other{\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645: \u0627\u0644\u0623\u062d\u062f\u062b {average} \u062e\u0644\u0627\u0644 {days} \u064a\u0648\u0645}}",
  "analyticsRatingNote": "\u0643\u0644 \u0646\u0642\u0637\u0629 \u0647\u064a \u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645 \u0627\u0644\u0645\u062d\u0641\u0648\u0638 \u0639\u0646\u062f \u062a\u062c\u0645\u064a\u0639 \u0630\u0644\u0643 \u0627\u0644\u064a\u0648\u0645. \u0627\u0644\u0623\u064a\u0627\u0645 \u0627\u0644\u0633\u0627\u0628\u0642\u0629 \u0644\u0623\u0648\u0644 \u062a\u0642\u064a\u064a\u0645 \u0644\u0627 \u062a\u064f\u0631\u0633\u0645.",
  "analyticsCatalogHeading": "\u062d\u062c\u0645 \u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c",
  "analyticsCatalogAsOf": "\u062d\u062a\u0649 {day}/{month} (UTC). \u0647\u0630\u0647 \u0625\u062c\u0645\u0627\u0644\u064a\u0627\u062a \u0633\u062c\u0651\u0644\u0647\u0627 \u0627\u0644\u062a\u062c\u0645\u064a\u0639 \u0627\u0644\u064a\u0648\u0645\u064a\u060c \u0648\u0644\u064a\u0633\u062a \u062a\u063a\u064a\u0651\u0631\u0627\u062a \u064a\u0648\u0645\u064a\u0629.",
  "analyticsRangeDays": "{days, plural, zero{{days} \u064a\u0648\u0645} one{\u064a\u0648\u0645} two{\u064a\u0648\u0645\u0627\u0646} few{{days} \u0623\u064a\u0627\u0645} many{{days} \u064a\u0648\u0645\u064b\u0627} other{{days} \u064a\u0648\u0645}}",
  "analyticsNewFollowers": "\u0645\u062a\u0627\u0628\u0639\u0648\u0646 \u062c\u062f\u062f",
  "analyticsLikesReceived": "\u0627\u0644\u0625\u0639\u062c\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629",
  "analyticsCommentsReceived": "\u0627\u0644\u062a\u0639\u0644\u064a\u0642\u0627\u062a \u0627\u0644\u0645\u0633\u062a\u0644\u0645\u0629",
  "analyticsStoryViews": "\u0645\u0634\u0627\u0647\u062f\u0627\u062a \u0627\u0644\u0633\u062a\u0648\u0631\u064a",
  "analyticsNewRatings": "\u062a\u0642\u064a\u064a\u0645\u0627\u062a \u062c\u062f\u064a\u062f\u0629",
  "analyticsAverageRating": "\u0645\u062a\u0648\u0633\u0637 \u0627\u0644\u062a\u0642\u064a\u064a\u0645",
  "analyticsActiveProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629",
  "analyticsPublishedPosts": "\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0629",
  "analyticsPublishedReels": "\u0627\u0644\u0631\u064a\u0644\u0632 \u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0629"
'@
# ---- the guard test
$guardTest = @'
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Part P-115 (STEP 8): the repository-wide "no hardcoded user-facing
/// strings" guard.
///
/// It reads every `.dart` file under `lib/` (except the generated
/// `lib/l10n/`) and fails when a user-facing string literal is written
/// directly in the code instead of coming from `AppLocalizations`.
///
/// What counts as user-facing (the literal must be the direct argument):
///   * `Text('...')` / `Text("...")`  (this also covers SnackBar content,
///     dialog titles and AppBar titles, which are all `Text`)
///   * `hintText:`, `labelText:`, `helperText:`, `errorText:`, `tooltip:`,
///     `semanticLabel:`, `semanticsLabel:`
///   * `label:` and `message:` - only in presentation code and in
///     `lib/core/widgets/` (AppButton, AppTextField, EmptyStateWidget...);
///     data and network layers use `message:` for API failures, which is a
///     separate concern and is not scanned.
///
/// A literal is ignored when, after removing `$interpolations` and escapes,
/// it holds no letters (for example `'#${item.id}'` or `'${a}/${b}'`), and
/// when it sits on a comment line.
///
/// Rules for this file:
///   * Never weaken the scanner to make a test pass.
///   * An entry in [_allowlist] needs a written reason (a comment on the
///     entry). The whole file is exempt, so keep entries rare: debug-only
///     code is the only accepted reason.
///   * [_pendingMigration] is a TEMPORARY list used while the migration is
///     split over several steps. It must end up empty. A file that is on the
///     list but has no violations left fails the test, so the list can only
///     shrink.
///
/// `flutter test` runs from the project root, so the paths are relative.

/// Files that are allowed to keep literals, each with the reason.
const Map<String, String> _allowlist = <String, String>{
  // (none yet)
};

/// Files that still contain literals and are being migrated. TEMPORARY.
const Set<String> _pendingMigration = <String>{
  'lib/core/widgets/widget_gallery_demo.dart',
  'lib/features/business_profile/presentation/business_onboarding_screen.dart',
  'lib/features/business_profile/presentation/business_profile_edit_screen.dart',
  'lib/features/business_profile/presentation/business_profile_screen.dart',
  'lib/features/chat/presentation/chat_thread_screen.dart',
  'lib/features/chat/presentation/message_bubble_widget.dart',
  'lib/features/chat/presentation/share_to_conversation_sheet.dart',
  'lib/features/chat/presentation/shared_content_card.dart',
  'lib/features/content/presentation/post_detail_screen.dart',
  'lib/features/content/presentation/post_form_screen.dart',
  'lib/features/content/presentation/reel_detail_screen.dart',
  'lib/features/content/presentation/reel_form_screen.dart',
  'lib/features/notifications/presentation/push_notification_handler.dart',
  'lib/features/products/presentation/product_form_screen.dart',
  'lib/features/social/presentation/content_overflow_menu.dart',
  'lib/features/social/presentation/report_dialog.dart',
  'lib/features/stories/presentation/story_creation_screen.dart',
  'lib/features/stories/presentation/story_upload_status_banner.dart',
};

class HardcodedLiteral {
  const HardcodedLiteral(this.file, this.line, this.kind, this.text);

  final String file;
  final int line;
  final String kind;
  final String text;

  @override
  String toString() => '$file:$line  $kind  "$text"';
}

final RegExp _literalPattern = RegExp(
  r'''(\bText\(|\bhintText:|\blabelText:|\bhelperText:|\berrorText:|\btooltip:|\bsemanticLabel:|\bsemanticsLabel:|\blabel:|\bmessage:)\s*(['"])((?:\\.|(?!\2)[^\\])*)\2''',
  dotAll: true,
);

final RegExp _letters = RegExp(r'[A-Za-z\u0600-\u06FF]');

String _visibleText(String raw) {
  return raw
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_]\w*'), '')
      .replaceAll(RegExp(r'\\u[0-9A-Fa-f]{4}'), '')
      .replaceAll(RegExp(r'\\.'), '');
}

bool _kindNeedsPresentationPath(String kind) =>
    kind == 'label:' || kind == 'message:';

bool _isPresentationPath(String path) =>
    path.contains('/presentation/') || path.startsWith('lib/core/widgets/');

/// Finds the user-facing literals in [source]. [path] uses forward slashes.
List<HardcodedLiteral> scanSource(String path, String source) {
  final List<HardcodedLiteral> found = <HardcodedLiteral>[];
  for (final RegExpMatch match in _literalPattern.allMatches(source)) {
    final String kind = match.group(1)!;
    if (_kindNeedsPresentationPath(kind) && !_isPresentationPath(path)) {
      continue;
    }
    final int lineStart = source.lastIndexOf('\n', match.start) + 1;
    final int lineEnd = source.indexOf('\n', match.start);
    final String lineText = source.substring(
      lineStart,
      lineEnd == -1 ? source.length : lineEnd,
    );
    if (lineText.trimLeft().startsWith('//')) {
      continue;
    }
    final String literal = match.group(3)!;
    if (!_letters.hasMatch(_visibleText(literal))) {
      continue;
    }
    final int line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    found.add(
      HardcodedLiteral(
        path,
        line,
        kind.endsWith('(') ? 'Text' : kind,
        literal.length > 60 ? '${literal.substring(0, 60)}...' : literal,
      ),
    );
  }
  return found;
}

Map<String, List<HardcodedLiteral>> _scanLib() {
  final Map<String, List<HardcodedLiteral>> byFile =
      <String, List<HardcodedLiteral>>{};
  final Directory lib = Directory('lib');
  expect(lib.existsSync(), isTrue, reason: 'run flutter test from the root');
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String path = entity.path.replaceAll('\\', '/');
    if (path.startsWith('lib/l10n/')) {
      continue;
    }
    final List<HardcodedLiteral> found = scanSource(
      path,
      entity.readAsStringSync(),
    );
    if (found.isNotEmpty) {
      byFile[path] = found;
    }
  }
  return byFile;
}

void main() {
  group('scanner self-test', () {
    test('finds literals in the user-facing positions', () {
      const String path = 'lib/features/x/presentation/x.dart';
      expect(scanSource(path, "Text('Hello')"), hasLength(1));
      expect(scanSource(path, 'Text("Hello")'), hasLength(1));
      expect(scanSource(path, "const Text(\n  'Hello world',\n)"), hasLength(1));
      expect(scanSource(path, "TextField(hintText: 'Search')"), hasLength(1));
      expect(scanSource(path, "InputDecoration(labelText: 'Name')"), hasLength(1));
      expect(scanSource(path, "IconButton(tooltip: 'Back')"), hasLength(1));
      expect(scanSource(path, "SnackBar(content: Text('Saved'))"), hasLength(1));
      expect(scanSource(path, "AppButton(label: 'Save')"), hasLength(1));
      expect(scanSource(path, "EmptyStateWidget(message: 'Nothing')"), hasLength(1));
      expect(scanSource(path, "Text('Total: \${t.count} items')"), hasLength(1));
    });

    test('ignores localized text, numbers, comments and other layers', () {
      const String path = 'lib/features/x/presentation/x.dart';
      expect(scanSource(path, 'Text(context.l10n.save)'), isEmpty);
      expect(scanSource(path, "Text('#\${item.id}')"), isEmpty);
      expect(scanSource(path, "Text('\${a}/\${b}')"), isEmpty);
      expect(scanSource(path, "Text('\\u2014')"), isEmpty);
      expect(scanSource(path, "  // Text('Hello')"), isEmpty);
      expect(scanSource(path, "  /// Text('Hello')"), isEmpty);
      expect(scanSource(path, "SelectableText('Hello')"), isEmpty);
      expect(
        scanSource('lib/features/x/data/x.dart', "Failure(message: 'Oops')"),
        isEmpty,
      );
    });
  });

  group('repository scan', () {
    late Map<String, List<HardcodedLiteral>> violations;

    setUpAll(() {
      violations = _scanLib();
    });

    test('no user-facing hardcoded string outside the allowlist', () {
      final List<HardcodedLiteral> unexpected = <HardcodedLiteral>[];
      violations.forEach((String file, List<HardcodedLiteral> items) {
        if (_allowlist.containsKey(file) || _pendingMigration.contains(file)) {
          return;
        }
        unexpected.addAll(items);
      });
      expect(
        unexpected,
        isEmpty,
        reason:
            'Move these into lib/l10n/app_en.arb + app_ar.arb and read them '
            'through context.l10n:\n${unexpected.join('\n')}',
      );
    });

    test('every allowlist entry has a reason and is still needed', () {
      _allowlist.forEach((String file, String reason) {
        expect(reason.trim(), isNotEmpty, reason: '$file has no reason');
        expect(
          violations.containsKey(file),
          isTrue,
          reason: '$file is on the allowlist but has no literals: remove it',
        );
      });
    });

    test('every pending-migration file still has literals', () {
      for (final String file in _pendingMigration) {
        expect(
          violations.containsKey(file),
          isTrue,
          reason: '$file is clean now: remove it from _pendingMigration',
        );
      }
    });
  });
}

'@

# ---- 1. Compute every change in memory first (nothing is written yet) -------
$contents = @{}
$order = New-Object System.Collections.ArrayList
foreach ($edit in $edits) {
    $path = $edit.Path
    if (-not $contents.ContainsKey($path)) {
        if (-not (Test-Path (Join-Path $root $path))) { Fail ("File not found: " + $path) }
        $contents[$path] = Read-Raw $path
        [void]$order.Add($path)
    }
    $text = $contents[$path]
    $nl = Get-Newline $text
    $oldText = To-Newline $edit.Old $nl
    $newText = To-Newline $edit.New $nl
    $found = Count-Occurrences $text $oldText
    if ($found -ne 1) {
        $preview = $edit.Old
        if ($preview.Length -gt 90) { $preview = $preview.Substring(0, 90) }
        Fail ("Expected exactly 1 match, found " + $found + " in " + $path + " for: " + $preview + "   (was this step already applied, or was the file changed after P-115 STEP 7?)")
    }
    $contents[$path] = $text.Replace($oldText, $newText)
}
foreach ($arb in @(@('lib/l10n/app_en.arb', $arbEn), @('lib/l10n/app_ar.arb', $arbAr))) {
    $path = $arb[0]
    $text = Read-Raw $path
    if ($text.Contains('"moderationQueueTitle"')) { Fail ($path + ' already contains the STEP 8A keys.') }
    $nl = Get-Newline $text
    $lastBrace = $text.LastIndexOf('}')
    if ($lastBrace -lt 0) { Fail ($path + ' has no closing brace.') }
    $head = $text.Substring(0, $lastBrace).TrimEnd()
    $contents[$path] = $head + ',' + $nl + (To-Newline $arb[1] $nl) + $nl + '}' + $nl
    [void]$order.Add($path)
}
Write-Host ('All ' + $edits.Count + ' edits and both ARB files computed OK.') -ForegroundColor Green

# ---- 2. Backup, then write ----------------------------------------------------
$backup = Join-Path $env:TEMP ('p115_step8a_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
foreach ($path in (@($order) + @($deadFile))) {
    $source = Join-Path $root $path
    $target = Join-Path $backup $path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
}
Write-Host ('Backup written to ' + $backup) -ForegroundColor Yellow

foreach ($path in $order) { Write-Raw $path $contents[$path] }
Write-Raw 'test/l10n/no_hardcoded_strings_test.dart' $guardTest
Remove-Item -LiteralPath (Join-Path $root $deadFile)
Write-Host 'Files written; business_console_screen.dart removed.' -ForegroundColor Green

# ---- 3. Format, generate, analyze, test --------------------------------------
$ErrorActionPreference = 'Continue'
$evidence = Join-Path $root 'p115_step8a_evidence.txt'
'P-115 STEP 8A evidence - ' + (Get-Date -Format 's') | Out-File -FilePath $evidence -Encoding utf8
function Run-Step([string]$Title, [scriptblock]$Command) {
    Write-Host ''
    Write-Host ('>>> ' + $Title) -ForegroundColor Cyan
    Add-Content -Path $evidence -Value ('===== ' + $Title + ' =====') -Encoding UTF8
    & $Command 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        Add-Content -Path $evidence -Value $line -Encoding UTF8
    }
    $code = $LASTEXITCODE
    Add-Content -Path $evidence -Value ('exit code: ' + $code) -Encoding UTF8
    Write-Host ('exit code: ' + $code) -ForegroundColor $(if ($code -eq 0) { 'Green' } else { 'Red' })
}

$formatFiles = @(@($order) | Where-Object { $_ -like '*.dart' }) + @('test/l10n/no_hardcoded_strings_test.dart')
Run-Step '1/5 dart format' { dart format $formatFiles }
Run-Step '2/5 flutter gen-l10n' { flutter gen-l10n }
Run-Step '3/5 flutter analyze' { flutter analyze }
Run-Step '4/5 flutter test test/l10n (ARB parity, encoding, pipeline, NEW no-hardcoded-strings)' { flutter test test/l10n }
Run-Step '5/5 flutter test moderation + business_console + routing' { flutter test test/features/moderation test/features/business_console test/routing }

Write-Host ''
Write-Host 'Done. Evidence: p115_step8a_evidence.txt' -ForegroundColor Green