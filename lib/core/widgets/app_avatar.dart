import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// State of the story ring drawn around an [AppAvatar].
enum AppAvatarRing {
  /// No ring.
  none,

  /// Unseen story: blue gradient ring (Design Tokens: storyRing).
  unseen,

  /// Seen story: hairline ring in the outline colour.
  seen,
}

/// Part P-111: the one circular avatar of the app, with an optional story ring.
///
/// P-114 / P-115 must use this widget instead of inventing local variants.
///
/// * Shows [imageUrl] when given; falls back to the initials of [name], then to
///   a person icon, on a missing URL or a failed load.
/// * [ring] draws the Instagram-style ring. The gap between ring and photo is
///   painted with [ringGapColor] (default: the scaffold background, where the
///   stories tray and profile headers sit; pass `colors.surface` on a card).
/// * With [onTap] the touch target is at least 44 logical pixels.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.ring = AppAvatarRing.none,
    this.ringGapColor,
    this.onTap,
    this.semanticLabel,
  });

  /// Network image. Optional.
  final String? imageUrl;

  /// Display name, used for the initials fallback and the semantic label.
  final String? name;

  /// Diameter of the photo itself (the ring is drawn outside of it).
  final double size;

  final AppAvatarRing ring;

  final Color? ringGapColor;

  final VoidCallback? onTap;

  final String? semanticLabel;

  /// Thickness of the ring and the gap between ring and photo.
  static const double ringWidth = 2.5;
  static const double ringGap = 2;

  static const double minTapTarget = 44;

  /// First letter of up to the first two words, upper-cased. Empty when [name]
  /// is null or blank.
  static String initialsOf(String? name) {
    final List<String> parts =
        (name ?? '')
            .trim()
            .split(RegExp(r'\s+'))
            .where((String p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) {
      return '';
    }
    String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
    if (parts.length == 1) {
      return first(parts.first);
    }
    return first(parts[0]) + first(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget photo = SizedBox.square(
      dimension: size,
      child: ClipOval(child: _buildContent(context, colors)),
    );

    final Color gapColor = ringGapColor ?? colors.background;
    final Widget framed;
    switch (ring) {
      case AppAvatarRing.none:
        framed = photo;
      case AppAvatarRing.unseen:
        framed = Container(
          padding: const EdgeInsets.all(ringWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: colors.storyRing,
          ),
          child: Container(
            padding: const EdgeInsets.all(ringGap),
            decoration: BoxDecoration(shape: BoxShape.circle, color: gapColor),
            child: photo,
          ),
        );
      case AppAvatarRing.seen:
        framed = Container(
          padding: const EdgeInsets.all(ringGap),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gapColor,
            border: Border.all(color: colors.storyRingSeen, width: ringWidth),
          ),
          child: photo,
        );
    }

    Widget result = Semantics(
      label: semanticLabel ?? name,
      image: true,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: framed,
    );

    if (onTap != null) {
      result = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTapTarget,
            minHeight: minTapTarget,
          ),
          child: Center(child: result),
        ),
      );
    }
    return result;
  }

  Widget _buildContent(BuildContext context, AppColors colors) {
    final Widget fallback = _buildFallback(colors);
    final String? url = imageUrl;
    if (url == null || url.isEmpty) {
      return fallback;
    }
    final int cacheSize =
        (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      errorBuilder:
          (BuildContext _, Object error, StackTrace? stack) => fallback,
      loadingBuilder:
          (BuildContext _, Widget child, ImageChunkEvent? progress) =>
              progress == null
                  ? child
                  : ColoredBox(color: colors.surfaceVariant),
    );
  }

  Widget _buildFallback(AppColors colors) {
    final String initials = initialsOf(name);
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child:
            initials.isEmpty
                ? Icon(
                  Icons.person,
                  size: size * 0.55,
                  color: colors.textSecondary,
                )
                : Text(
                  initials,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
      ),
    );
  }
}
