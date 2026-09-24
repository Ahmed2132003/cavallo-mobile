import 'package:flutter/material.dart';

import 'report_dialog.dart';

enum _ContentMenuAction { report }

/// Part P-058: the "..." menu shown on cards, detail screens and comment
/// rows. Only one action for now (Report). [contentType] is the wire value
/// `reports/targets.py` accepts: "post", "reel" or "comment" here.
class ContentOverflowMenu extends StatelessWidget {
  const ContentOverflowMenu({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ContentMenuAction>(
      tooltip: 'More options',
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (action) {
        switch (action) {
          case _ContentMenuAction.report:
            showReportDialog(
              context,
              contentType: contentType,
              objectId: objectId,
            );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<_ContentMenuAction>(
          value: _ContentMenuAction.report,
          child: Text('Report'),
        ),
      ],
    );
  }
}