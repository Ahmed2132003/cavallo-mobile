import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Opens the full-screen chat video player.
///
/// Pass [networkUrl] for a received / already-sent video (the presigned URL
/// from the backend) or [localPath] for a video that is still queued on this
/// phone. Before this screen existed a chat video bubble was only a static
/// placeholder, so tapping a video did nothing.
Future<void> openChatVideoViewer(
  BuildContext context, {
  String? networkUrl,
  String? localPath,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder:
          (_) => ChatVideoViewerScreen(
            networkUrl: networkUrl,
            localPath: localPath,
          ),
    ),
  );
}

/// Builds the controller. Injectable so tests never touch the real plugin.
typedef ChatVideoControllerFactory =
    VideoPlayerController Function({String? networkUrl, String? localPath});

/// Full-screen video player for a chat message: autoplay, tap to pause /
/// resume, scrubbable progress bar, retry on failure, and an "open in another
/// app" fallback for videos whose codec this phone cannot decode in-app (the
/// backend stores chat videos exactly as uploaded, in any format).
class ChatVideoViewerScreen extends StatefulWidget {
  const ChatVideoViewerScreen({
    super.key,
    this.networkUrl,
    this.localPath,
    this.controllerFactory,
  }) : assert(networkUrl != null || localPath != null);

  final String? networkUrl;
  final String? localPath;
  final ChatVideoControllerFactory? controllerFactory;

  @override
  State<ChatVideoViewerScreen> createState() => _ChatVideoViewerScreenState();
}

class _ChatVideoViewerScreenState extends State<ChatVideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  // Bumped on every (re)start and on dispose so the result of an in-flight
  // initialize() that belongs to an older attempt is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start(notify: false));
  }

  @override
  void dispose() {
    _generation++;
    _releaseController();
    super.dispose();
  }

  void _releaseController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      unawaited(_safeDispose(controller));
    }
  }

  Future<void> _safeDispose(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('ChatVideoViewer: dispose failed: $error');
    }
  }

  VideoPlayerController _createController() {
    final factory = widget.controllerFactory;
    if (factory != null) {
      return factory(
        networkUrl: widget.networkUrl,
        localPath: widget.localPath,
      );
    }
    final path = widget.localPath;
    if (path != null) {
      return VideoPlayerController.file(File(path));
    }
    return VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));
  }

  Future<void> _start({required bool notify}) async {
    final generation = ++_generation;
    _releaseController();
    if (notify && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    VideoPlayerController? controller;
    try {
      controller = _createController();
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await _safeDispose(controller);
        return;
      }
      controller.addListener(_onControllerChanged);
      _controller = controller;
      await controller.play();
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
    } catch (error) {
      debugPrint('ChatVideoViewer: failed to start playback: $error');
      if (controller != null) {
        await _safeDispose(controller);
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.value.hasError && !_failed) {
      setState(() => _failed = true);
      return;
    }
    // Position / play-state changes: rebuild the controls.
    setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
      return;
    }
    final atEnd =
        value.duration > Duration.zero && value.position >= value.duration;
    if (atEnd) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _openExternally() async {
    final url = widget.networkUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('ChatVideoViewer: could not open externally: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The viewer is always dark: force a black app bar around the shared
    // CavalloAppBar so the Cavallo logo stays on every screen.
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        key: const ValueKey('chatVideoViewer'),
        backgroundColor: Colors.black,
        appBar: const CavalloAppBar(),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;

    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.chatVideoCannotPlay,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    key: const ValueKey('chatVideoRetry'),
                    onPressed: () => unawaited(_start(notify: true)),
                    child: Text(l10n.chatVideoRetry),
                  ),
                  if (widget.networkUrl != null)
                    OutlinedButton(
                      key: const ValueKey('chatVideoOpenExternal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => unawaited(_openExternally()),
                      child: Text(l10n.chatVideoOpenExternal),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (_loading || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final value = controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              key: const ValueKey('chatVideoSurface'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_togglePlay()),
              child: AspectRatio(
                aspectRatio: aspect,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('chatVideoPlayPause'),
                color: Colors.white,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => unawaited(_togglePlay()),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatDuration(value.position)} / '
                '${_formatDuration(value.duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
