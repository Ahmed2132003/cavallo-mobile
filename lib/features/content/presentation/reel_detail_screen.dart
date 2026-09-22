import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../domain/public_reel_entity.dart';
import 'content_public_providers.dart';
import 'content_stub_action_row.dart';

/// Part P-045 scope: the customer-facing, READ-ONLY Reel detail screen
/// behind `/reel/:id`. Same route-newness, states, and "no business
/// name/avatar" reasoning as `PostDetailScreen` (this part) — see that
/// file's class docstring, all of which applies here unchanged.
///
/// ## ⚠️ No actual video playback — flagged, not silent
///
/// This project has no video-playback package in `pubspec.yaml` (no
/// `video_player`/`chewie`/equivalent — confirmed by reading the real
/// file, not assumed), and P-045's own spec never lists adding one as
/// in-scope. So this screen — like `ReelCard`'s thumbnail (this part,
/// STEP 3) — shows the Reel's `thumbnailUrl` with a play-icon overlay
/// that is honest about being a stub: tapping it shows a "coming soon"
/// affordance via a `SnackBar`, the same convention
/// `ContentStubActionRow` uses for like/comment/share, rather than
/// silently doing nothing OR pretending to play video it cannot
/// actually play. `videoUrl` is still fetched and held on the
/// [PublicReel] entity regardless (STEP 1), so wiring real playback
/// later needs no repository/entity change — only a video package plus
/// this screen's play button.
///
/// **Decision point for Ahmed**: add a video-playback package now (this
/// part) so this screen plays the real video, or keep this honest stub
/// here and wire real playback in a later, dedicated part. Per this
/// project's "no architecture change without asking" rule, this part
/// does NOT add the dependency on its own — flagged here and in the
/// PROGRESS update instead of silently deciding either way.
class ReelDetailScreen extends ConsumerWidget {
  const ReelDetailScreen({super.key, required this.reelId});

  /// The raw `:id` path parameter, as `go_router` hands it over — a
  /// [String], parsed here rather than by the router.
  final String reelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The backend route is `<int:pk>/`, so a non-numeric id can never
    // identify a Reel — nothing to fetch. Same early-exit as
    // PostDetailScreen/ProductDetailScreen.
    final id = int.tryParse(reelId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reel')),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final reelAsync = ref.watch(reelPublicDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Reel')),
      body: switch (reelAsync) {
        AsyncData(value: final PublicReel reel) => _ReelDetailView(
          reel: reel,
        ),
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// "This reel doesn't exist (or is no longer available)" — an
/// [EmptyStateWidget], not [ErrorStateWidget]: nothing to retry.
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      message: 'Reel not found.\nIt may have been removed.',
      icon: Icons.movie_outlined,
    );
  }
}

/// A genuine fetch failure — retryable, unlike [_NotFoundView].
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same dual-shape handling as PostDetailScreen/ProductDetailScreen's
    // own `_LoadErrorView` — see either for why both shapes are checked.
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => 'Could not load this reel.',
    };

    return ErrorStateWidget(
      message: message,
      // Automatic retry is disabled on the provider by design, so this
      // button is the only thing that retries.
      onRetry: () => ref.invalidate(reelPublicDetailProvider(id)),
    );
  }
}

class _ReelDetailView extends StatelessWidget {
  const _ReelDetailView({required this.reel});

  final PublicReel reel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = reel.durationSeconds;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReelDetailMedia(thumbnailUrl: reel.thumbnailUrl),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (duration != null) ...[
                  Text(
                    _formatDuration(duration),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  reel.caption.isEmpty ? 'No caption.' : reel.caption,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                const ContentStubActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `mm:ss` — good enough for this MVP's short-form Reels (never
/// expected to reach an hour). `Duration.toString()` isn't used
/// directly since it always includes a leading `0:` hour segment and a
/// microseconds suffix this UI has no use for.
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Larger, full-width version of `ReelCard`'s `_ReelThumbnail` (STEP 3)
/// — same neutral-fallback + play-icon-overlay convention, deliberately
/// duplicated rather than shared (this project's `_ProductThumbnail`
/// precedent for local, per-screen duplication). Tapping the play icon
/// shows the same honest "coming soon" affordance described in this
/// file's class docstring — see there for why there is no real
/// playback yet.
class _ReelDetailMedia extends StatelessWidget {
  const _ReelDetailMedia({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = thumbnailUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 56),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          (url == null || url.isEmpty)
              ? placeholder(Icons.movie_outlined)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      placeholder(Icons.broken_image_outlined),
                ),
          const _PlayStubButton(),
        ],
      ),
    );
  }
}

/// Same "visually honest inactive stub" rule this part's Architecture
/// Rules section states for the like/comment/share row — applied here
/// to the play button itself, for the reason given in this file's class
/// docstring (no video-playback package in this project yet).
class _PlayStubButton extends StatelessWidget {
  const _PlayStubButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video playback — Coming soon')),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(14),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}