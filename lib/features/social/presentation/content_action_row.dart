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
/// [updatedAt]) — coming from `PublicPost`/`PublicReel`, which
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
/// the provider's live (possibly optimistically-toggled) state — so a
/// rebuild caused by the user's own toggle never re-triggers a seed
/// (the parent's `PublicPost`/`PublicReel` data hasn't changed), while
/// a genuinely new fetch (pull-to-refresh, a different account's
/// session after logout/login reusing this same widget tree, re-paging
/// the feed) that returns different per-viewer values does re-seed.
/// This is deliberately independent of the `.autoDispose` /
/// invalidate-on-logout fix to `contentInteractionProvider` itself
/// (tracked as a separate step of this bugfix) — the two are
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
const Color _overlayOnMedia = Colors.white;
