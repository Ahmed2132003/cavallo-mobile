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
    builder:
        (BuildContext sheetContext) =>
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
