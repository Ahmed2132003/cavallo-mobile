import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_colors.dart';

/// Part P-117: the shared hero tag of the auth logo. One logo per route, so
/// the logo flies between login, register and forgot-password.
const String kAuthLogoHeroTag = 'auth-logo';

/// The bundled logo image (blue rounded square, white horse head, wordmark).
const String kAuthLogoAsset = 'assets/images/cavallo_logo.png';

/// Animated Cavallo logo shown above the fields of the auth screens.
///
/// * Entrance (once, no loop): fade + scale 0.85 -> 1.0 (easeOutBack) + a
///   small slide (~700 ms), then ONE glow pulse (~900 ms) that settles back to
///   the resting glow, so `pumpAndSettle` always finishes.
/// * The entrance plays once per app session. Later instances start in the
///   final state, so the [Hero] flight between screens is not fought by a
///   second fade-in.
/// * `MediaQuery.disableAnimationsOf` -> final state from the first frame.
/// * The glow colour comes from `context.appColors.brand` only (same image
///   for both themes).
/// * Shrinks smoothly while the keyboard is open.
class AuthLogoHeader extends StatefulWidget {
  const AuthLogoHeader({this.size = 104, super.key});

  /// Side length of the square logo.
  final double size;

  /// Key of the placeholder shown when the asset cannot be loaded.
  static const Key fallbackKey = ValueKey<String>('auth-logo-fallback');

  /// Lets tests start from "first time in this session".
  @visibleForTesting
  static void debugResetEntrance() {
    _AuthLogoHeaderState._entrancePlayed = false;
  }

  @override
  State<AuthLogoHeader> createState() => _AuthLogoHeaderState();
}

class _AuthLogoHeaderState extends State<AuthLogoHeader>
    with SingleTickerProviderStateMixin {
  static bool _entrancePlayed = false;

  static const Duration _total = Duration(milliseconds: 1600);
  static const double _fadeEnd = 450 / 1600;
  static const double _entranceEnd = 700 / 1600;
  static const double _restGlow = 0.22;
  static const double _peakGlow = 0.50;
  static const double _compactFactor = 0.62;

  late final AnimationController _controller;
  late final CurvedAnimation _fadeCurve;
  late final CurvedAnimation _scaleCurve;
  late final CurvedAnimation _slideCurve;
  late final CurvedAnimation _pulseCurve;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
    _fadeCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, _fadeEnd, curve: Curves.easeOut),
    );
    _scaleCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, _entranceEnd, curve: Curves.easeOutBack),
    );
    _slideCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, _entranceEnd, curve: Curves.easeOutCubic),
    );
    _pulseCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(_entranceEnd, 1, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.85, end: 1).animate(_scaleCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_slideCurve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disabled = MediaQuery.disableAnimationsOf(context);
    if (!_decided) {
      _decided = true;
      if (disabled || _entrancePlayed) {
        _controller.value = 1;
      } else {
        _entrancePlayed = true;
        _controller.forward();
      }
    } else if (disabled && _controller.isAnimating) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _scaleCurve.dispose();
    _slideCurve.dispose();
    _pulseCurve.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _glow =>
      _restGlow +
      (_peakGlow - _restGlow) * math.sin(math.pi * _pulseCurve.value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Color brand = context.appColors.brand;
    final bool disabled = MediaQuery.disableAnimationsOf(context);
    // The Scaffold may strip the insets from the body's MediaQuery, so the
    // view's own insets are checked as well.
    final bool keyboardOpen =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        (View.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;
    final double shown =
        keyboardOpen ? widget.size * _compactFactor : widget.size;
    final int cachePx =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).ceil();

    final Widget logo = AnimatedContainer(
      duration: disabled ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: shown,
      height: shown,
      child: FadeTransition(
        opacity: _fadeCurve,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedBuilder(
              animation: _controller,
              builder:
                  (context, _) =>
                      _LogoFace(glow: _glow, brand: brand, cachePx: cachePx),
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: AlignmentDirectional.center,
      child: Semantics(
        label: l10n.appTitle,
        image: true,
        child: ExcludeSemantics(
          child: Hero(
            tag: kAuthLogoHeroTag,
            flightShuttleBuilder: (
              flightContext,
              animation,
              direction,
              fromContext,
              toContext,
            ) {
              return _LogoFace(glow: _restGlow, brand: brand, cachePx: cachePx);
            },
            child: logo,
          ),
        ),
      ),
    );
  }
}

/// The picture with its shadow/glow. Fills the (tight) constraints it gets.
class _LogoFace extends StatelessWidget {
  const _LogoFace({
    required this.glow,
    required this.brand,
    required this.cachePx,
  });

  final double glow;
  final Color brand;
  final int cachePx;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = constraints.biggest.shortestSide;
        final double extent = side.isFinite ? side : 104;
        final BorderRadius radius = BorderRadius.circular(extent * 0.22);
        return Image.asset(
          kAuthLogoAsset,
          width: extent,
          height: extent,
          fit: BoxFit.cover,
          cacheWidth: cachePx,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null && !wasSynchronouslyLoaded) {
              return const SizedBox.shrink();
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: brand.withValues(alpha: glow),
                    blurRadius: extent * 0.30,
                    spreadRadius: extent * 0.01,
                    offset: Offset(0, extent * 0.08),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: extent * 0.12,
                    offset: Offset(0, extent * 0.04),
                  ),
                ],
              ),
              child: ClipRRect(borderRadius: radius, child: child),
            );
          },
          errorBuilder:
              (context, error, stackTrace) => SizedBox(
                key: AuthLogoHeader.fallbackKey,
                width: extent,
                height: extent,
              ),
        );
      },
    );
  }
}
