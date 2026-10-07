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