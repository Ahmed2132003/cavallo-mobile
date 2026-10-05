import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-111: the skeleton placeholder ("shimmer") used instead of spinners
/// where P-114 / P-115 specify a skeleton loader.
///
/// Colours come from the tokens (surfaceVariant base, a slightly lighter or
/// darker highlight computed from textPrimary), so it works in Light and Dark.
///
/// * Give it [width] / [height], or let a parent (e.g. a ListView row) decide.
/// * [AppShimmerBox.circle] is the avatar-shaped skeleton.
/// * The sweep stops when [animate] is false or when the OS asks to reduce
///   motion (`MediaQuery.disableAnimations`). Tests that use `pumpAndSettle`
///   should pass `animate: false`, because a repeating animation never settles.
class AppShimmerBox extends StatefulWidget {
  const AppShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.animate = true,
  }) : _circle = false;

  const AppShimmerBox.circle({
    super.key,
    required double size,
    this.animate = true,
  }) : width = size,
       height = size,
       borderRadius = 0,
       _circle = true;

  final double? width;
  final double? height;
  final double borderRadius;
  final bool animate;
  final bool _circle;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AppShimmerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final bool shouldRun =
        widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color base = colors.surfaceVariant;
    final Color highlight = Color.lerp(base, colors.textPrimary, 0.08)!;
    final bool isCircle = widget._circle;
    final double direction =
        Directionality.of(context) == TextDirection.rtl ? -1 : 1;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double percent = (-1 + 2 * _controller.value) * direction;
              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius:
                      isCircle
                          ? null
                          : BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: <Color>[base, highlight, base],
                    stops: const <double>[0.25, 0.5, 0.75],
                    transform: _SlideGradientTransform(percent),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}
