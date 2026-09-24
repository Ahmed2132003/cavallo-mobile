import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/social_interaction_repository_impl.dart';
import '../domain/report_reason.dart';
import 'social_error_message.dart';

/// Part P-058: opens the report reason-picker for a Post, Reel or
/// Comment. Offers exactly the 4 reasons from [ReportReason] (P-057),
/// with an optional free-text details field.
Future<void> showReportDialog(
  BuildContext context, {
  required String contentType,
  required int objectId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ReportDialog(contentType: contentType, objectId: objectId),
  );
}

String _reasonLabel(ReportReason reason) => switch (reason) {
  ReportReason.spam => 'Spam',
  ReportReason.inappropriate => 'Inappropriate content',
  ReportReason.misleading => 'Misleading',
  ReportReason.other => 'Other',
};

class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  ReportReason? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(socialInteractionRepositoryProvider)
          .reportTarget(
            contentType: widget.contentType,
            objectId: widget.objectId,
            reason: reason,
            details: _detailsController.text.trim(),
          );
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks, your report was submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = socialErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return AlertDialog(
      title: const Text('Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this?'),
            const SizedBox(height: 8),
            for (final reason in ReportReason.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _reason == reason
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(_reasonLabel(reason)),
                onTap: _submitting
                    ? null
                    : () => setState(() => _reason = reason),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_reason == null || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}