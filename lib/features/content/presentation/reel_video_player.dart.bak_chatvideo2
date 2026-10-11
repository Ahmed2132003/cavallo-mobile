/// Instagram-style video surface for Reels: real playback (autoplay when the
/// page becomes active, loop, tap to pause/resume, thin progress bar you can
/// scrub, spinner while buffering, retry on failure).
///
/// This replaces the old "Video playback - Coming soon" stub on
/// `ReelDetailScreen`. The project had no video package at all before this
/// (`video_player` is now in `pubspec.yaml`).
///
/// Design notes:
/// * The controller is created only while [isActive] is true and disposed as
///   soon as the page goes off-screen, so a long swipe session never keeps
///   more than one hardware decoder alive.
/// * The thumbnail is shown as a poster until the first frame is ready.
/// * Portrait videos fill the screen (cover); landscape/square videos are
///   letterboxed (contain) so nothing important is cropped.
/// * Backend media URLs are presigned and expire after one hour. If playback
///   fails, Retry first asks [onRefreshUrl] for a fresh URL (when provided)
///   and then re-initialises the player.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_context.dart';

/// Builds the controller for a network [uri]. Injectable so tests never have
/// to touch the real platform video plugin.
typedef ReelControllerFactory = VideoPlayerController Function(Uri uri);

VideoPlayerController _defaultControllerFactory(Uri uri) {
  return VideoPlayerController.networkUrl(uri);
}

class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isActive,
    this.thumbnailUrl,
    this.muted = false,
    this.onRefreshUrl,
    this.controllerFactory,
  });

  final String? videoUrl;
  final String? thumbnailUrl;

  /// Only the active page plays. Becoming inactive disposes the controller.
  final bool isActive;

  final bool muted;

  /// Optional: returns a fresh (not yet expired) video URL, or null.
  final Future<String?> Function()? onRefreshUrl;

  final ReelControllerFactory? controllerFactory;

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _url;

  bool _starting = false;
  bool _failed = false;
  bool _buffering = false;
  bool _playing = false;
  bool _userPaused = false;
  bool _foreground = true;

  // Bumped on every stop/restart so results of an in-flight initialise()
  // that belong to an older controller are ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _url = widget.videoUrl;
    if (widget.isActive) {
      unawaited(_start());
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl != oldWidget.videoUrl) {
      _url = widget.videoUrl;
      _stop();
      _failed = false;
      _userPaused = false;
      if (widget.isActive) {
        unawaited(_start());
      }
      return;
    }

    if (widget.isActive != oldWidget.isActive) {
      _userPaused = false;
      if (widget.isActive) {
        unawaited(_start());
      } else {
        _stop();
      }
    }

    if (widget.muted != oldWidget.muted) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.setVolume(widget.muted ? 0.0 : 1.0));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _applyPlayback();
  }

  /// Creates and initialises the controller. Synchronous part only assigns
  /// fields (safe from initState/didUpdateWidget, a build always follows);
  /// everything after the first await goes through setState guarded by
  /// [_generation].
  Future<void> _start() async {
    if (_controller != null) {
      _applyPlayback();
      return;
    }

    final url = _url;
    final uri = (url == null || url.isEmpty) ? null : Uri.tryParse(url);
    if (uri == null) {
      _failed = true;
      return;
    }

    final generation = ++_generation;
    _failed = false;
    _starting = true;

    final factory = widget.controllerFactory ?? _defaultControllerFactory;
    final controller = factory(uri);
    _controller = controller;

    try {
      await controller.initialize();
      if (generation != _generation) return;

      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);
      if (generation != _generation) return;

      controller.addListener(_onControllerTick);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = controller.value.hasError;
      });
      _applyPlayback();
    } catch (_) {
      if (generation != _generation) return;
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = true;
      });
    }
  }

  /// Tears the controller down (no setState: callers are either about to
  /// rebuild anyway or are disposing).
  void _stop() {
    _generation++;
    _starting = false;
    _buffering = false;
    _playing = false;

    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_onControllerTick);
      unawaited(old.dispose().catchError((Object _) {}));
    }
  }

  void _applyPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (widget.isActive && !_userPaused && _foreground) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _onControllerTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final value = controller.value;
    final buffering = value.isBuffering;
    final playing = value.isPlaying;
    final failed = value.hasError;

    if (buffering != _buffering || playing != _playing || failed != _failed) {
      setState(() {
        _buffering = buffering;
        _playing = playing;
        _failed = failed;
      });
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      setState(() => _userPaused = true);
      unawaited(controller.pause());
    } else {
      setState(() => _userPaused = false);
      unawaited(controller.play());
    }
  }

  Future<void> _retry() async {
    String? fresh;
    final refresh = widget.onRefreshUrl;
    if (refresh != null) {
      try {
        fresh = await refresh();
      } catch (_) {
        fresh = null;
      }
    }
    if (!mounted) return;

    _stop();
    if (fresh != null && fresh.isNotEmpty) {
      _url = fresh;
    }
    setState(() {
      _failed = false;
      _userPaused = false;
    });
    if (widget.isActive) {
      unawaited(_start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready =
        controller != null && controller.value.isInitialized && !_failed;
    final thumbnail = widget.thumbnailUrl;
    final showSpinner = !_failed && (_starting || (ready && _buffering));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (!ready && thumbnail != null && thumbnail.isNotEmpty)
            Image.network(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          if (ready) _buildVideo(controller),
          if (showSpinner)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          if (ready)
            IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _userPaused ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          if (_failed) _buildError(),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.isEmpty) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    final landscape = size.width > size.height;
    return FittedBox(
      fit: landscape ? BoxFit.contain : BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(
            context.l10n.reelPlayerError,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('reelPlayer_retryButton'),
            onPressed: _retry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
