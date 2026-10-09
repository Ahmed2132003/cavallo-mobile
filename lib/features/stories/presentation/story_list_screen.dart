import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../../business_console/presentation/console_row.dart';
import '../domain/own_story_entity.dart';
import 'own_stories_provider.dart';

/// The Business Console "Stories" tab: the signed-in business's own stories
/// (`ownStoriesProvider`) with an honest status per story.
/// (The long design notes of P-051/P-083 live in git history.)
///
/// Rules preserved exactly: the status shown is
/// `OwnStory.displayStatus(now)` (a story past `expiresAt` is Expired even if
/// the server still says published); a rejected story always shows its
/// reason; the FAB keeps its explicit hero tag (two default-tag FABs inside
/// the console IndexedStack make Flutter assert on push).
///
/// Part P-115 (STEP 5) restyle, presentation only: shared `ConsoleRow`
/// anatomy, shared `AppStatusChip` (icon + label, never colour alone),
/// localized strings. No provider, clock or navigation call changed.
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final storiesAsync = ref.watch(ownStoriesProvider);
    final now = ref.watch(storyListClockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consoleNavStories)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('story-list-create-button'),
        heroTag: 'story-list-create',
        onPressed: () {
          context.pushNamed(RouteNames.storyForm);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.consoleStoriesCreate),
      ),
      body: switch (storiesAsync) {
        AsyncData(value: final stories) when stories.isEmpty =>
          const _EmptyView(),
        AsyncData(value: final stories) => _StoryListView(
          stories: stories,
          now: now,
        ),
        AsyncError(:final error) => _LoadErrorView(error: error),
        _ => const LoadingIndicator(),
      },
    );
  }
}

/// Clock used to derive "Expired" and the time left. Overridable in tests.
final storyListClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

String _apiFailureMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(error: final ApiFailure failure) => failure.message,
    ApiFailure(:final message) => message,
    _ => fallback,
  };
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorStateWidget(
      key: const Key('story-list-error'),
      message: _apiFailureMessage(
        error,
        fallback: context.l10n.consoleStoriesLoadFailed,
      ),
      onRetry: () => ref.read(ownStoriesProvider.notifier).refresh(),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder:
            (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: EmptyStateWidget(
                    key: const Key('story-list-empty'),
                    message: l10n.consoleStoriesEmpty,
                    icon: Icons.auto_stories_outlined,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _StoryListView extends ConsumerWidget {
  const _StoryListView({required this.stories, required this.now});

  final List<OwnStory> stories;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(ownStoriesProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding keeps the last row clear of the extended FAB.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder:
            (context, index) => _StoryListItem(story: stories[index], now: now),
      ),
    );
  }
}

class _StoryListItem extends StatelessWidget {
  const _StoryListItem({required this.story, required this.now});

  final OwnStory story;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final displayStatus = story.displayStatus(now);
    final remaining = story.remaining(now);
    final reason = story.rejectionReason;
    final isVideo = _isVideoUrl(story.mediaUrl);

    return ConsoleRow(
      key: Key('story-list-item-${story.id}'),
      leading: ConsoleThumbnail(
        url: isVideo ? null : story.mediaUrl,
        placeholderIcon: Icons.videocam_outlined,
      ),
      title: l10n.consoleStoryNumber(story.id),
      meta: [
        if (remaining != null)
          Text(
            _formatRemaining(l10n, remaining),
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
      ],
      status: _StoryStatusChip(
        key: Key('story-status-${story.id}'),
        status: displayStatus,
      ),
      // The rejection reason is always visible to the business.
      footer:
          displayStatus == OwnStoryDisplayStatus.rejected && reason != null
              ? Text(
                l10n.consoleStoryReason(reason),
                style: text.bodySmall?.copyWith(color: colors.dangerText),
              )
              : null,
    );
  }
}

String _formatRemaining(AppLocalizations l10n, Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours >= 1) return l10n.consoleStoryTimeLeftHM(hours, minutes);
  if (minutes >= 1) return l10n.consoleStoryTimeLeftM(minutes);
  return l10n.consoleStoryTimeLeftLess;
}

class _StoryStatusChip extends StatelessWidget {
  const _StoryStatusChip({super.key, required this.status});

  final OwnStoryDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String label, IconData icon, AppStatusTone tone) = switch (status) {
      OwnStoryDisplayStatus.published => (
        l10n.consoleStoryPublished,
        Icons.check_circle_outline,
        AppStatusTone.success,
      ),
      OwnStoryDisplayStatus.pending => (
        l10n.consoleStoryPending,
        Icons.hourglass_bottom,
        AppStatusTone.warning,
      ),
      OwnStoryDisplayStatus.rejected => (
        l10n.consoleStoryRejected,
        Icons.cancel_outlined,
        AppStatusTone.danger,
      ),
      OwnStoryDisplayStatus.expired => (
        l10n.consoleStoryExpired,
        Icons.timer_off_outlined,
        AppStatusTone.neutral,
      ),
      OwnStoryDisplayStatus.unknown => (
        l10n.consoleStoryUnknown,
        Icons.help_outline,
        AppStatusTone.neutral,
      ),
    };
    return AppStatusChip(label: label, icon: icon, tone: tone);
  }
}

bool _isVideoUrl(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.webm');
}
