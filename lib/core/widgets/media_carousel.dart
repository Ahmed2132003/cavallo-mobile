import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_shimmer_box.dart';

/// Part P-114 STEP 1: swipeable media with dots, in a FIXED aspect ratio so a
/// list never jumps while images load (1:1 or 4:5 for posts, 9:16 for reels).
///
/// Presentation only: it receives the image URLs and shows them with
/// `Image.network` (the app's existing image loader). While an image loads it
/// shows an [AppShimmerBox] skeleton. Pages follow the reading direction, so
/// the carousel swipes the other way in Arabic. The dots are hidden when there
/// is a single image.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 1,
    this.onPageChanged,
    this.onTap,
    this.semanticLabel,
  });

  final List<String> imageUrls;

  /// Width divided by height. 1 (square), 4 / 5 (portrait post), 9 / 16 (reel).
  final double aspectRatio;

  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> urls = widget.imageUrls;

    final Widget body;
    if (urls.isEmpty) {
      body = ColoredBox(
        color: colors.surfaceVariant,
        child: Center(
          child: Icon(Icons.image_outlined, color: colors.textSecondary),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: _onPageChanged,
            itemBuilder:
                (BuildContext context, int index) =>
                    _CarouselImage(url: urls[index]),
          ),
          if (urls.length > 1)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 8,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _Dots(count: urls.length, index: _index),
                ),
              ),
            ),
        ],
      );
    }

    Widget result = AspectRatio(aspectRatio: widget.aspectRatio, child: body);
    if (widget.onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: result,
      );
    }
    return Semantics(label: widget.semanticLabel, image: true, child: result);
  }
}

class _CarouselImage extends StatelessWidget {
  const _CarouselImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder:
          (BuildContext _, Widget child, ImageChunkEvent? progress) =>
              progress == null
                  ? child
                  : const SizedBox.expand(
                    child: AppShimmerBox(borderRadius: 0),
                  ),
      errorBuilder:
          (BuildContext _, Object error, StackTrace? stack) => ColoredBox(
            color: colors.surfaceVariant,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.textSecondary,
              ),
            ),
          ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Container(
            key: ValueKey<String>('media_carousel_dot_$i'),
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i == index
                      ? colors.brand
                      : colors.surface.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}