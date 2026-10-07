import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/story_public_repository.dart';
import '../domain/public_story_entity.dart';
import 'story_public_provider.dart';

/// Translucent shades of the fixed black / white media chrome of this screen
/// (scrim, progress track, secondary text). They are derived from Colors.black
/// and Colors.white, the two documented theme-independent colours of this
/// file, so no other palette colour is used (P-111 hardcoded-colour guard).
final Color _storyScrim = Colors.black.withValues(alpha: 0.54);
final Color _storyWhite70 = Colors.white.withValues(alpha: 0.7);
final Color _storyWhite54 = Colors.white.withValues(alpha: 0.54);
final Color _storyWhite24 = Colors.white.withValues(alpha: 0.24);
/// Part P-050 scope: the full-screen, tap-to-advance Story viewer behind
/// `/stories/:id` -- the customer-facing payoff of the story pipeline.
///
/// ## Architecture Section 13 -- the one rule this whole file exists to satisfy
///
/// ALL timer/progress/current-index state lives as plain fields on
/// `_StoryPlayerState` -- never as a Riverpod provider. A fresh state object is
/// built every time `StoryViewerScreen` is pushed, and `dispose()` tears its
/// `AnimationController` down on close.
///
/// `viewedStoriesProvider` IS a provider this screen writes to -- a
/// deliberately separate, narrower concern (a per-business "seen" set for
/// `StoryRingWidget` styling).
///
/// ## Part P-114 STEP 1 (presentation only)
///
/// * The screen stays full-screen BLACK in Light and Dark. Black and white are
///   the only fixed (non-token) colours of this file, on purpose: this is
///   theme-independent media chrome over a photo, not themed UI.
/// * Segmented progress bars grow from the reading START (right in Arabic).
/// * Header: shared [AppAvatar], business name, relative time of the current
///   story, close button with a localized tooltip.
/// * Tap zones follow the reading direction: see [storyTapAdvances]. In LTR a
///   tap on the right half goes forward and the left half goes back; in RTL it
///   is the other way round (the reading-start side always goes back).
/// * Hold (long press) pauses the timer; releasing resumes it.
/// * Swipe down closes (unchanged).
/// * Every text comes from the localization files.
///
/// NOT part of this step: a reply field, a Like button and a product/link chip.
/// The story data model and `StoryPublicRepository` have no like / reply /
/// product-link capability, and P-114 may not change repositories or DTOs.
class StoryViewerScreen extends ConsumerWidget {
  const StoryViewerScreen({
    super.key,
    required this.businessId,
    this.businessName,
  });

  /// The raw `:id` path parameter -- a business id -- parsed here rather than
  /// by the router, same convention as `PostDetailScreen.postId`.
  final String businessId;

  /// Passed via `context.pushNamed(..., extra: businessName)` from
  /// `StoryRingWidget`. `null` when this route is reached without it (a deep
  /// link, a restored location) -- falls back to a generic label.
  final String? businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(businessId);
    final l10n = context.l10n;

    final Widget body;
    if (id == null) {
      body = _EdgeStateView(
        child: EmptyStateWidget(
          message: l10n.storyViewerNotFound,
          icon: Icons.error_outline,
        ),
      );
    } else {
      final storiesAsync = ref.watch(businessStoriesProvider(id));
      body = switch (storiesAsync) {
        AsyncData(:final value) when value.isNotEmpty => _StoryPlayer(
          businessId: id,
          businessName: businessName ?? l10n.storyViewerDefaultName,
          stories: value,
        ),
        AsyncData() => _EdgeStateView(
          child: EmptyStateWidget(
            message: l10n.storyViewerEmpty,
            icon: Icons.auto_stories_outlined,
          ),
        ),
        AsyncError(:final error) => _EdgeStateView(
          child: _LoadErrorView(error: error, businessId: id),
        ),
        _ => const _EdgeStateView(child: LoadingIndicator()),
      };
    }

    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: body));
  }
}

/// True when a tap at horizontal position [dx] (0 .. [width]) must go to the
/// NEXT story, false when it must go to the PREVIOUS one.
///
/// LTR: right half forward, left half back (the P-050 behaviour).
/// RTL: left half forward, right half back -- the reading-START side always
/// goes back.
@visibleForTesting
bool storyTapAdvances({
  required double dx,
  required double width,
  required TextDirection direction,
}) {
  if (direction == TextDirection.rtl) {
    return dx < width / 2;
  }
  return dx > width / 2;
}

/// Forces a dark [Theme] for any non-player state, so the shared empty / error
/// widgets stay legible against this screen's black background.
class _EdgeStateView extends StatelessWidget {
  const _EdgeStateView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: ThemeData.dark(useMaterial3: true), child: child);
  }
}

/// A genuine fetch failure -- retryable.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => localizedApiError(
        l10n,
        failure,
      ),
      ApiFailure() => localizedApiError(l10n, error),
      _ => l10n.storyViewerLoadFailed,
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessStoriesProvider(businessId)),
    );
  }
}

/// The actual tap / auto-advance / hold / swipe-dismiss player -- built only
/// once [StoryViewerScreen] confirms a non-empty story list.
class _StoryPlayer extends ConsumerStatefulWidget {
  const _StoryPlayer({
    required this.businessId,
    required this.businessName,
    required this.stories,
  });

  final int businessId;
  final String businessName;
  final List<PublicStory> stories;

  @override
  ConsumerState<_StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends ConsumerState<_StoryPlayer>
    with SingleTickerProviderStateMixin {
  /// Fixed duration for every Story (image or video).
  static const _storyDuration = Duration(seconds: 5);

  // --- Everything below is Architecture-Section-13-protected local state:
  // plain fields on this State object, never a Riverpod provider. ---
  late final AnimationController _controller;
  int _currentIndex = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener(_onAnimationStatus)
      ..forward();
    _recordCurrentView();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _advance();
    }
  }

  void _recordCurrentView() {
    final story = widget.stories[_currentIndex];

    // Fire-and-forget: `StoryPublicRepositoryImpl.recordView` already swallows
    // its own failures via reportError.
    unawaited(ref.read(storyPublicRepositoryProvider).recordView(story.id));

    // Local-only "seen" bookkeeping for StoryRingWidget's styling, deferred to
    // a microtask because the first call happens from initState() (Riverpod
    // rejects provider writes while the widget tree is building).
    Future.microtask(() {
      if (!mounted) return;
      final notifier = ref.read(
        viewedStoriesProvider(widget.businessId).notifier,
      );
      notifier.state = {...notifier.state, story.id};
    });
  }

  void _restartTimer() {
    _paused = false;
    _controller
      ..reset()
      ..forward();
  }

  void _advance() {
    if (_currentIndex >= widget.stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentIndex++);
    _restartTimer();
    _recordCurrentView();
  }

  void _goToPrevious() {
    if (_currentIndex == 0) {
      // Nothing before the first story: silently restart its timer.
      _restartTimer();
      return;
    }
    setState(() => _currentIndex--);
    _restartTimer();
    _recordCurrentView();
  }

  void _handleTapUp(TapUpDetails details, double width, TextDirection dir) {
    final bool forward = storyTapAdvances(
      dx: details.localPosition.dx,
      width: width,
      direction: dir,
    );
    if (forward) {
      _advance();
    } else {
      _goToPrevious();
    }
  }

  /// Hold: stop the timer where it is.
  void _pause() {
    if (_paused) return;
    _paused = true;
    _controller.stop();
  }

  /// Release: continue from where the timer stopped.
  void _resume() {
    if (!_paused) return;
    _paused = false;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final TextDirection direction = Directionality.of(context);
    final AppFormatters formatters = AppFormatters(context.l10n);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) {
          Navigator.of(context).pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp:
                (details) =>
                    _handleTapUp(details, constraints.maxWidth, direction),
            onLongPressStart: (_) => _pause(),
            onLongPressEnd: (_) => _resume(),
            onLongPressCancel: _resume,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  story.mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder:
                      (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: LoadingIndicator()),
                  errorBuilder:
                      (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _storyWhite54,
                          size: 56,
                        ),
                      ),
                ),
                // Soft dark scrim under the header so white text stays legible
                // on bright photos. Ignores touches.
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: 96,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_storyScrim, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  end: 8,
                  child: _ProgressBars(
                    count: widget.stories.length,
                    currentIndex: _currentIndex,
                    controller: _controller,
                  ),
                ),
                PositionedDirectional(
                  top: 20,
                  start: 12,
                  end: 4,
                  child: Row(
                    children: [
                      AppAvatar(name: widget.businessName, size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.businessName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatters.relativeTime(story.publishedAt),
                              style: TextStyle(
                                color: _storyWhite70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: context.l10n.storyViewerClose,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The row of per-story progress segments. `AnimatedWidget` rebuilds only
/// itself on every animation tick, listening directly to the player's
/// [AnimationController]. Segments fill from the reading START.
class _ProgressBars extends AnimatedWidget {
  const _ProgressBars({
    required this.count,
    required this.currentIndex,
    required AnimationController controller,
  }) : super(listenable: controller);

  final int count;
  final int currentIndex;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final fillFraction =
            index < currentIndex
                ? 1.0
                : index == currentIndex
                ? _animation.value
                : 0.0;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _storyWhite24,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fillFraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}