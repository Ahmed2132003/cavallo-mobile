import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/public_story_entity.dart';
import 'story_public_provider.dart';

/// Part P-050 scope: the full-screen, tap-to-advance Story viewer
/// behind `/stories/:id` -- the primary customer-facing payoff of the
/// Phase 6-8 moderation+Story pipeline (P-046-P-049).
///
/// ## Architecture Section 13 -- the one rule this whole file exists to satisfy
///
/// ALL timer/progress/current-index state lives as plain fields on
/// `_StoryPlayerState` (`State<_StoryPlayer>`, below) -- never as a
/// Riverpod provider of any kind, global or otherwise. This is the
/// simplest possible way to satisfy "must not leak into any global
/// provider": there is nothing to leak, because nothing beyond this
/// one `State` object's own fields (`_currentIndex`, `_controller`)
/// is ever created to hold it. A fresh `_StoryPlayerState` is built
/// every time `StoryViewerScreen` is pushed, and `dispose()` tears its
/// `AnimationController` down completely on close -- exactly the
/// "created fresh per viewing session, disposed when closed" contract
/// this part's own spec requires.
///
/// `viewedStoriesProvider` (`story_public_provider.dart`) IS a
/// Riverpod provider this screen writes to -- see that provider's own
/// doc for why it is a deliberately separate, narrower concern (a
/// per-business "seen" set for `StoryRingWidget` styling) from the
/// timer/progress state this rule protects.
///
/// ## States
///
/// A non-numeric `:id` resolves to a not-found state with zero network
/// calls, same convention as `PostDetailScreen`. `AsyncData([])` (a
/// real, renderable "nothing to show" state -- reachable only via a
/// deep link/stale link, since `StoryRingWidget` never navigates here
/// for an empty list) and a genuine `AsyncError` both use
/// `EmptyStateWidget`/`ErrorStateWidget` wrapped in a forced dark
/// `Theme` (see `_EdgeStateView`) so they stay legible against this
/// screen's black background.
class StoryViewerScreen extends ConsumerWidget {
  const StoryViewerScreen({
    super.key,
    required this.businessId,
    this.businessName,
  });

  /// The raw `:id` path parameter -- a business id, per `RouteNames
  /// .storyViewer`'s own doc -- parsed here rather than by the router,
  /// same convention as `PostDetailScreen.postId`.
  final String businessId;

  /// Passed via `context.pushNamed(..., extra: businessName)` from
  /// `StoryRingWidget` (a plain `String`, not an object, since that's
  /// all `StoryRingWidget` itself has). `null` when this route is
  /// reached without it (a deep link, a restored location) -- falls
  /// back to a generic label rather than redirecting away, since a
  /// missing display name is genuinely cosmetic here, unlike
  /// `moderationReviewPath`'s missing `QueueItem` (which the screen
  /// cannot function without at all).
  final String? businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(businessId);

    final Widget body;
    if (id == null) {
      body = const _EdgeStateView(
        child: EmptyStateWidget(
          message: 'Story not found.',
          icon: Icons.error_outline,
        ),
      );
    } else {
      final storiesAsync = ref.watch(businessStoriesProvider(id));
      body = switch (storiesAsync) {
        AsyncData(:final value) when value.isNotEmpty => _StoryPlayer(
          businessId: id,
          businessName: businessName ?? 'Business',
          stories: value,
        ),
        AsyncData() => const _EdgeStateView(
          child: EmptyStateWidget(
            message: 'No stories to show right now.',
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

/// Forces a dark [Theme] for any non-player state -- see
/// `StoryViewerScreen`'s own "States" doc section for why.
class _EdgeStateView extends StatelessWidget {
  const _EdgeStateView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: ThemeData.dark(useMaterial3: true), child: child);
  }
}

/// A genuine fetch failure -- retryable. Same DioException/ApiFailure
/// pattern-match as `PostDetailScreen`'s own `_LoadErrorView`
/// (Part P-045).
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.businessId});

  final Object error;
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load stories.',
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(businessStoriesProvider(businessId)),
    );
  }
}

/// The actual tap/auto-advance/swipe-dismiss player -- built only once
/// [StoryViewerScreen] confirms a non-empty story list, so it never
/// has to handle an empty-sequence edge case itself.
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
  /// Fixed duration for every Story (image or video) -- see this
  /// file's module-level "scope decision" note on why video doesn't
  /// get its own real-duration timing in this part.
  static const _storyDuration = Duration(seconds: 5);

  // --- Everything below is Architecture-Section-13-protected local
  // state: plain fields on this State object, never a Riverpod
  // provider of any kind. See this file's module-level doc. ---
  late final AnimationController _controller;
  int _currentIndex = 0;

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
    // Tears the local timer state down completely on close -- the
    // concrete proof (this part's own acceptance criteria) that
    // reopening the viewer later starts with fresh state: nothing
    // survives past this call for this session to leak from.
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

    // Fire-and-forget per this part's own spec ("don't await/block the
    // UI on this call's completion"). StoryPublicRepositoryImpl
    // .recordView already swallows its own failures via reportError
    // (see that method's own doc) -- nothing here needs a try/catch.
    unawaited(ref.read(storyPublicRepositoryProvider).recordView(story.id));

    // Local-only "seen" bookkeeping for StoryRingWidget's styling --
    // a deliberately separate, narrower concern from this widget's own
    // timer/progress state above. See viewedStoriesProvider's own doc.
    final notifier = ref.read(
      viewedStoriesProvider(widget.businessId).notifier,
    );
    notifier.state = {...notifier.state, story.id};
  }

  void _advance() {
    if (_currentIndex >= widget.stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentIndex++);
    _controller
      ..reset()
      ..forward();
    _recordCurrentView();
  }

  void _goToPrevious() {
    if (_currentIndex == 0) {
      // Spec: "tap on the left half ... goes to the previous story" --
      // silently restarts the first story's timer rather than closing,
      // since there's nothing before it to go back to.
      _controller
        ..reset()
        ..forward();
      return;
    }
    setState(() => _currentIndex--);
    _controller
      ..reset()
      ..forward();
    _recordCurrentView();
  }

  void _handleTapUp(TapUpDetails details, double width) {
    if (details.localPosition.dx > width / 2) {
      _advance();
    } else {
      _goToPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

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
            onTapUp: (details) =>
                _handleTapUp(details, constraints.maxWidth),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  story.mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                      ? child
                      : const Center(child: LoadingIndicator()),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 56,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _ProgressBars(
                    count: widget.stories.length,
                    currentIndex: _currentIndex,
                    controller: _controller,
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 12,
                  right: 4,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          widget.businessName.isNotEmpty
                              ? widget.businessName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
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
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
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

/// The Instagram/Snapchat-style row of per-story progress segments.
/// `AnimatedWidget` rebuilds only itself on every animation tick
/// (not the whole `_StoryPlayer`), listening directly to
/// `_StoryPlayerState`'s [AnimationController].
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
        final fillFraction = index < currentIndex
            ? 1.0
            : index == currentIndex
            ? _animation.value
            : 0.0;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
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