import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Part P-115 (STEP 5): the single row anatomy of every Business Console list
/// (products, posts/reels, stories).
///
/// thumbnail | title, meta lines, status chip, footer | trailing actions
///
/// Presentation only: it knows nothing about providers or moderation rules.
class ConsoleRow extends StatelessWidget {
  const ConsoleRow({
    super.key,
    required this.leading,
    required this.title,
    this.titleMaxLines = 1,
    this.meta = const <Widget>[],
    this.status,
    this.footer,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final int titleMaxLines;
  final List<Widget> meta;
  final Widget? status;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget? statusWidget = status;
    final Widget? footerWidget = footer;
    final Widget? trailingWidget = trailing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final Widget line in meta)
                  Padding(padding: const EdgeInsets.only(top: 4), child: line),
                if (statusWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: statusWidget,
                  ),
                if (footerWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: footerWidget,
                  ),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}

/// 56 px rounded thumbnail shared by the console rows.
///
/// [url] null or empty shows [placeholderIcon]; a failed load shows a broken
/// image icon. Colours come from the tokens only.
class ConsoleThumbnail extends StatelessWidget {
  const ConsoleThumbnail({
    super.key,
    required this.url,
    required this.placeholderIcon,
  });

  final String? url;
  final IconData placeholderIcon;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    Widget box(IconData icon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.textSecondary),
      );
    }

    final String? value = url;
    if (value == null || value.isEmpty) {
      return box(placeholderIcon);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => box(Icons.broken_image_outlined),
      ),
    );
  }
}
