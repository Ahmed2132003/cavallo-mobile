import 'package:flutter/widgets.dart';

/// Part P-112: small helpers for right-to-left layouts.
///
/// Rules for every file touched by P-112 and later parts:
///  * use `EdgeInsetsDirectional`, `AlignmentDirectional`,
///    `TextAlign.start` / `TextAlign.end` and `PositionedDirectional`
///    instead of left / right;
///  * show directional icons (back, forward, send, chevrons) through
///    [DirectionalIcon] so they point the right way in Arabic.

/// True when the closest [Directionality] is right-to-left.
bool isRtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// An [Icon] that points the right way in both directions.
///
/// Icons such as `Icons.arrow_back` or `Icons.send` already mirror themselves
/// (`IconData.matchTextDirection`); those are drawn as they are. Any other
/// icon with a direction (for example `Icons.play_arrow`) is flipped
/// horizontally in right-to-left layouts.
class DirectionalIcon extends StatelessWidget {
  const DirectionalIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget child = Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
    if (!isRtl(context) || icon.matchTextDirection) {
      return child;
    }
    return Transform.flip(flipX: true, child: child);
  }
}
