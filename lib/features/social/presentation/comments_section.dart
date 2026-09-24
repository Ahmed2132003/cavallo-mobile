import 'package:flutter/material.dart';

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
        Text('Comments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        CommentInputWidget(contentType: contentType, objectId: objectId),
        const SizedBox(height: 8),
        CommentListWidget(contentType: contentType, objectId: objectId),
      ],
    );
  }
}