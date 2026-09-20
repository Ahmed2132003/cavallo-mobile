import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/queue_item_entity.dart';
import 'moderation_provider.dart';
import 'moderation_widgets.dart';

/// Part P-040 scope: the moderator's item review screen — a larger view
/// of one queue item with an Approve action and a Reject action that
/// requires a written reason.
///
/// ### How the screen is given its item, and how it leaves
///
/// The [QueueItem] is passed in (the queue screen already holds the full
/// object), not looked up by id — the same "no lookup, the caller has it"
/// reasoning as `ProductFormScreen.existingProduct`. What the screen shows
/// is therefore the snapshot from the last queue load, which is also why
/// the age is captioned as such.
///
/// Like `ProductFormScreen`, this screen has no `RouteNames` / `GoRouter`
/// dependency: it leaves with a plain `Navigator.pop`, so it can be tested
/// inside a bare `MaterialApp` and the router (a later step) only decides
/// how it is reached. The pop result says what happened:
///   * `true`  — this moderator approved or rejected the item.
///   * `false` — the item turned out to be no longer pending (already
///     decided by another moderator, or deleted), so it was dropped from
///     the queue and there is nothing left to review.
///   * `null`  — the moderator backed out without deciding.
///
/// ### Approve and Reject
///
/// Both call `ModerationQueueNotifier`, which talks to the backend first
/// and removes the item from the queue only after a confirmed success —
/// so a failure here never makes an item disappear. Approve has no
/// confirmation dialog on purpose: it is the fast path for a moderator
/// clearing many items, and the outcome is confirmed by a snackbar.
///
/// Reject opens a dialog ([_RejectReasonDialog]) whose confirm button
/// stays disabled until a non-blank reason is typed — the same rule the
/// backend enforces (`reason` must not be blank), applied up front so the
/// moderator gets instant feedback instead of a round trip to learn it.
/// The reject request itself runs INSIDE the dialog, so a failure (network
/// drop, 403) is shown next to the reason field and the typed reason is
/// still there to resend, instead of being lost with a closed dialog.
class ModerationReviewScreen extends ConsumerStatefulWidget {
  const ModerationReviewScreen({super.key, required this.item});

  final QueueItem item;

  @override
  ConsumerState<ModerationReviewScreen> createState() =>
      _ModerationReviewScreenState();
}

class _ModerationReviewScreenState
    extends ConsumerState<ModerationReviewScreen> {
  bool _approving = false;

  Future<void> _approve() async {
    if (_approving) {
      return;
    }
    // Captured before the await so nothing below touches a BuildContext
    // after an async gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _approving = true);

    try {
      await ref
          .read(moderationQueueProvider.notifier)
          .approve(widget.item.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isNoLongerPending(error)) {
        // The notifier already dropped the item from the queue.
        messenger.showSnackBar(const SnackBar(content: Text(_alreadyHandled)));
        navigator.pop(false);
        return;
      }
      setState(() => _approving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _actionErrorMessage(
              error,
              fallback: 'Could not approve this item. Please try again.',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Item approved')));
    navigator.pop(true);
  }

  Future<void> _reject() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final outcome = await showDialog<_RejectOutcome>(
      context: context,
      // A stray tap outside must not throw away a half-written reason.
      barrierDismissible: false,
      builder: (dialogContext) => _RejectReasonDialog(item: widget.item),
    );

    if (!mounted || outcome == null) {
      return;
    }
    switch (outcome) {
      case _RejectOutcome.rejected:
        messenger.showSnackBar(const SnackBar(content: Text('Item rejected')));
        navigator.pop(true);
      case _RejectOutcome.alreadyHandled:
        messenger.showSnackBar(const SnackBar(content: Text(_alreadyHandled)));
        navigator.pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the (autoDispose) queue provider alive for as long as this
    // screen is open. In the app the queue screen underneath already does
    // this; here it makes approve/reject safe even when this screen is
    // the only thing listening, e.g. in tests or after a future deep link.
    ref.listen(moderationQueueProvider, (previous, next) {});

    final item = widget.item;
    final theme = Theme.of(context);
    final previewText = item.previewText;
    final hasPreviewText = previewText != null && previewText.isNotEmpty;
    final submitter = item.submitterBusinessName;

    return Scaffold(
      appBar: AppBar(title: const Text('Review content')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.previewImageUrl != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: QueuePreviewThumbnail(
                    key: const ValueKey('review-preview-image'),
                    imageUrl: item.previewImageUrl,
                    size: math.min(constraints.maxWidth, 480),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Text('Preview', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            hasPreviewText ? previewText : 'No preview available',
            key: const ValueKey('review-preview-text'),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: hasPreviewText ? null : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    label: 'Type',
                    child: Text(contentTypeLabel(item.contentType)),
                  ),
                  if (submitter != null)
                    _DetailRow(label: 'Submitted by', child: Text(submitter)),
                  _DetailRow(
                    label: 'Priority',
                    child: PriorityBadge(priority: item.priority),
                  ),
                  _DetailRow(
                    label: 'Waiting',
                    child: QueueAgeChip(
                      priority: item.priority,
                      age: item.ageDuration,
                    ),
                  ),
                  _DetailRow(label: 'Queue item', child: Text('#${item.id}')),
                  const SizedBox(height: 4),
                  Text(
                    'Waiting time is as of the last queue refresh.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('review-reject-button'),
                  onPressed: _approving ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  key: const ValueKey('review-approve-button'),
                  label: 'Approve',
                  isLoading: _approving,
                  onPressed: _approve,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// How the reject dialog ended, when it ended by leaving the screen's
/// item behind (a plain Cancel returns `null` instead).
enum _RejectOutcome { rejected, alreadyHandled }

/// Shown when the backend says the item is not pending anymore.
const String _alreadyHandled =
    'This item was already handled by someone else, or no longer exists. '
    'It has been removed from your queue.';

/// 409 = already decided, 404 = the row no longer exists (see
/// `ModerationRepository`'s docstring — neither has a dedicated
/// `ApiFailure` subtype, so the status code is read from the response).
/// Same rule `ModerationQueueNotifier` uses to drop the item from the
/// queue.
bool _isNoLongerPending(Object error) {
  if (error is! DioException) {
    return false;
  }
  final statusCode = error.response?.statusCode;
  return statusCode == 409 || statusCode == 404;
}

/// What the moderator should read for a failed approve/reject. A 403 gets
/// the same actionable explanation the queue screen gives: the route gate
/// uses `is_moderator`/`is_staff`, but the API needs the
/// `can_moderate_content` permission, which comes from Group membership
/// (see the P-040 gap note in PROJECT_PROGRESS.md).
String _actionErrorMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: AuthFailure()) =>
      'Your account is not allowed to review content. If it should be, '
          'ask an admin to add it to the Moderator group.',
    DioException(error: ValidationFailure(:final fields, :final message)) =>
      fields['reason']?.join(' ') ?? message,
    DioException(error: final ApiFailure failure) => failure.message,
    _ => fallback,
  };
}

/// The reject dialog: a required reason field plus a confirm button that
/// stays disabled until the reason has real content. It owns its text
/// controller and runs the reject request itself — see
/// [ModerationReviewScreen]'s docstring for why.
class _RejectReasonDialog extends ConsumerStatefulWidget {
  const _RejectReasonDialog({required this.item});

  final QueueItem item;

  @override
  ConsumerState<_RejectReasonDialog> createState() =>
      _RejectReasonDialogState();
}

class _RejectReasonDialogState extends ConsumerState<_RejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _touched = false;
  bool _submitting = false;
  String? _error;

  bool get _hasReason => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onReasonChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onReasonChanged() {
    setState(() {
      _touched = true;
      // Editing the reason after a failed attempt clears the old error.
      _error = null;
    });
  }

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.isEmpty || _submitting) {
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(moderationQueueProvider.notifier)
          .reject(widget.item.id, reason);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isNoLongerPending(error)) {
        navigator.pop(_RejectOutcome.alreadyHandled);
        return;
      }
      setState(() {
        _submitting = false;
        _error = _actionErrorMessage(
          error,
          fallback: 'Could not reject this item. Please try again.',
        );
      });
      return;
    }

    if (!mounted) {
      return;
    }
    navigator.pop(_RejectOutcome.rejected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRequired = _touched && !_hasReason;

    return AlertDialog(
      title: const Text('Reject content'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The business will see this reason.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          AppTextField(
            key: const ValueKey('reject-reason-field'),
            label: 'Reason (required)',
            controller: _controller,
            keyboardType: TextInputType.multiline,
            maxLines: 3,
          ),
          if (showRequired) ...[
            const SizedBox(height: 8),
            Text(
              'A reason is required.',
              key: const ValueKey('reject-reason-required'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('reject-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('reject-cancel-button'),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          key: const ValueKey('reject-confirm-button'),
          label: 'Reject',
          isLoading: _submitting,
          onPressed: _hasReason ? _submit : null,
        ),
      ],
    );
  }
}