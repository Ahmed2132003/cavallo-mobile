import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../social/presentation/comments_section.dart';
import '../../social/presentation/content_action_row.dart';
import '../../social/presentation/content_overflow_menu.dart';
import '../data/dtos/reel_public_response_dto.dart';
import '../data/reel_public_repository.dart';
import '../domain/public_reel_entity.dart';
import 'content_public_providers.dart';
import 'reel_video_player.dart';

/// The customer-facing Reel screen behind `/reel/:id`.
///
/// Reels playback fix: this screen used to show the thumbnail with a fake
/// play button ("coming soon") because the project had no video package. It
/// is now an Instagram-style Reels viewer:
///
/// * Full-screen vertical pager. The reel you tapped is page 0; more
///   published reels (`GET /api/v1/reels/public/`, cursor-paginated) are
///   appended below it and loaded lazily while you swipe.
/// * The active page autoplays with sound, loops, tap pauses/resumes, a thin
///   progress bar can be scrubbed, a mute button sits in the top bar.
/// * Like / comment / share / save reuse the app's own [ContentActionRow]
///   (same optimistic state as the cards), comments open in the existing
///   bottom sheet ([showCommentsSheet]), Report stays in the "..." menu.
///
/// Not-found / error / loading states are unchanged.
class ReelDetailScreen extends ConsumerWidget {
  const ReelDetailScreen({super.key, required this.reelId});

  /// The raw `:id` path parameter, as `go_router` hands it over.
  final String reelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(reelId);
    if (id == null) {
      return Scaffold(
        appBar: CavalloAppBar(title: Text(context.l10n.consoleTypeReel)),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final reelAsync = ref.watch(reelPublicDetailProvider(id));

    if (reelAsync case AsyncData(value: final PublicReel reel)) {
      return _ReelViewer(initialReel: reel);
    }

    return Scaffold(
      appBar: CavalloAppBar(title: Text(context.l10n.consoleTypeReel)),
      body: switch (reelAsync) {
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Injection points (tests override these; production uses the defaults).
// ---------------------------------------------------------------------------

/// Loads one page of the public reels list. `cursorUrl == null` is the first
/// page; afterwards the `next` URL of the previous page is passed back as is.
typedef ReelFeedLoader =
    Future<PaginatedResponse<PublicReel>> Function({String? cursorUrl});

final reelFeedLoaderProvider = Provider<ReelFeedLoader>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ({String? cursorUrl}) async {
    final response = await dio.get<Map<String, dynamic>>(
      cursorUrl ?? '/api/v1/reels/public/',
    );
    return PaginatedResponse.fromJson<PublicReel>(
      response.data!,
      (json) => ReelPublicResponseDto.fromJson(json).toEntity(),
    );
  };
});

/// Everything the video surface of one page needs.
class ReelPlayerArgs {
  const ReelPlayerArgs({
    required this.reel,
    required this.isActive,
    required this.muted,
    required this.onRefreshUrl,
  });

  final PublicReel reel;
  final bool isActive;
  final bool muted;
  final Future<String?> Function() onRefreshUrl;
}

typedef ReelPlayerBuilder =
    Widget Function(BuildContext context, ReelPlayerArgs args);

/// Builds the video surface of a page. Overridden in widget tests so they
/// never touch the platform video plugin.
final reelPlayerBuilderProvider = Provider<ReelPlayerBuilder>((ref) {
  return (context, args) => ReelVideoPlayer(
    key: ValueKey('reelPlayer_${args.reel.id}'),
    videoUrl: args.reel.videoUrl,
    thumbnailUrl: args.reel.thumbnailUrl,
    isActive: args.isActive,
    muted: args.muted,
    onRefreshUrl: args.onRefreshUrl,
  );
});

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.contentReelNotFound,
      icon: Icons.movie_outlined,
    );
  }
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => context.l10n.reelLoadError,
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(reelPublicDetailProvider(id)),
    );
  }
}

// ---------------------------------------------------------------------------
// The vertical pager
// ---------------------------------------------------------------------------

class _ReelViewer extends ConsumerStatefulWidget {
  const _ReelViewer({required this.initialReel});

  final PublicReel initialReel;

  @override
  ConsumerState<_ReelViewer> createState() => _ReelViewerState();
}

class _ReelViewerState extends ConsumerState<_ReelViewer> {
  final PageController _pageController = PageController();
  late final List<PublicReel> _reels;

  String? _nextCursor;
  bool _loadingMore = false;
  bool _exhausted = false;
  int _index = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _reels = [widget.initialReel];
    Future.microtask(_loadMore);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted || !mounted) return;
    _loadingMore = true;
    try {
      final page = await ref.read(reelFeedLoaderProvider)(
        cursorUrl: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        final known = _reels.map((r) => r.id).toSet();
        for (final reel in page.results) {
          final hasVideo = (reel.videoUrl ?? '').isNotEmpty;
          if (hasVideo && known.add(reel.id)) {
            _reels.add(reel);
          }
        }
        _nextCursor = page.next;
        _exhausted = page.next == null;
      });
    } catch (_) {
      // Best effort: the tapped reel is already playable. The next page
      // change tries again.
    } finally {
      _loadingMore = false;
    }
  }

  /// Media URLs are presigned and expire; re-fetching the reel gives a fresh
  /// one for the player's Retry button.
  Future<String?> _refreshUrl(int reelId) async {
    final fresh = await ref
        .read(reelPublicRepositoryProvider)
        .fetchPublicReel(reelId);
    return fresh?.videoUrl;
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index >= _reels.length - 2) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentReel = _reels[_index];
    final canPop = Navigator.of(context).canPop();
    final l10n = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final reel = _reels[index];
                return _ReelPage(
                  key: ValueKey('reelPage_${reel.id}'),
                  reel: reel,
                  isActive: index == _index,
                  muted: _muted,
                  onRefreshUrl: () => _refreshUrl(reel.id),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      if (canPop)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _muted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        tooltip: _muted
                            ? l10n.reelPlayerUnmute
                            : l10n.reelPlayerMute,
                        onPressed: () => setState(() => _muted = !_muted),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            onSurfaceVariant: Colors.white,
                          ),
                        ),
                        child: ContentOverflowMenu(
                          contentType: 'reel',
                          objectId: currentReel.id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One page = video + gradient + info + action row
// ---------------------------------------------------------------------------

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.muted,
    required this.onRefreshUrl,
  });

  final PublicReel reel;
  final bool isActive;
  final bool muted;
  final Future<String?> Function() onRefreshUrl;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage>
    with AutomaticKeepAliveClientMixin {
  bool _captionExpanded = false;

  // Keeps the page (and its like/save state) alive while scrolled away. The
  // video controller itself is disposed by the player when the page becomes
  // inactive.
  @override
  bool get wantKeepAlive => true;

  void _openComments() {
    showCommentsSheet(
      context,
      contentType: 'reel',
      objectId: widget.reel.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final reel = widget.reel;
    final playerBuilder = ref.watch(reelPlayerBuilderProvider);
    final theme = Theme.of(context);
    const shadow = [Shadow(blurRadius: 4, color: Colors.black54)];

    final profileAsync = ref.watch(
      businessProfilePublicProvider(reel.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.businessName ?? '',
      _ => '',
    };

    final captionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      shadows: shadow,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        playerBuilder(
          context,
          ReelPlayerArgs(
            reel: reel,
            isActive: widget.isActive,
            muted: widget.muted,
            onRefreshUrl: widget.onRefreshUrl,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (businessName.isNotEmpty)
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  shadows: shadow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (reel.caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(
                            () => _captionExpanded = !_captionExpanded,
                          ),
                          child: _captionExpanded
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 160,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      reel.caption,
                                      style: captionStyle,
                                    ),
                                  ),
                                )
                              : Text(
                                  reel.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // The app's own action row, recoloured for a dark surface.
                Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      onSurfaceVariant: Colors.white,
                      onSurface: Colors.white,
                    ),
                    textTheme: theme.textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ContentActionRow(
                      contentType: 'reel',
                      objectId: reel.id,
                      onCommentTap: _openComments,
                      isLiked: reel.isLiked,
                      isSaved: reel.isSaved,
                      likesCount: reel.likesCount,
                      commentsCount: reel.commentsCount,
                      sharesCount: reel.sharesCount,
                      updatedAt: reel.updatedAt,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
