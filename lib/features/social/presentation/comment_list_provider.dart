import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/social_interaction_repository_impl.dart';
import '../domain/comment_entity.dart';
import 'content_interaction_key.dart';
import 'social_error_message.dart';

/// Part P-058: state of one content item's comment list.
class CommentListState {
  const CommentListState({
    this.items = const [],
    this.nextUrl,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<CommentEntity> items;

  /// Exact `next` cursor URL from the last page, passed back to the
  /// repository verbatim. `null` means there are no more pages.
  final String? nextUrl;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  CommentListState copyWith({
    List<CommentEntity>? items,
    String? nextUrl,
    bool clearNextUrl = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return CommentListState(
      items: items ?? this.items,
      nextUrl: clearNextUrl ? null : (nextUrl ?? this.nextUrl),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Part P-058: loads and paginates comments for ONE Post/Reel.
///
/// Visibility is decided entirely by the backend (P-055): a hidden comment
/// is only ever returned to its own author or a moderator. This notifier
/// applies NO client-side filtering and keeps the list exactly as returned.
class CommentListNotifier extends Notifier<CommentListState> {
  CommentListNotifier(this.key);

  final ContentInteractionKey key;

  @override
  CommentListState build() => const CommentListState(isLoading: true);

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(socialInteractionRepositoryProvider)
          .listComments(contentType: key.contentType, objectId: key.objectId);
      if (!ref.mounted) return;
      state = CommentListState(items: page.results, nextUrl: page.next);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: socialErrorMessage(e));
    }
  }

  Future<void> loadMore() async {
    final url = state.nextUrl;
    if (url == null || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(socialInteractionRepositoryProvider)
          .listComments(
            contentType: key.contentType,
            objectId: key.objectId,
            pageUrl: url,
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page.results],
        nextUrl: page.next,
        clearNextUrl: page.next == null,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: socialErrorMessage(e),
      );
    }
  }

  /// Called after a successful createComment. The list is newest-first, so
  /// the new comment goes on top.
  void addCreated(CommentEntity comment) {
    if (state.items.any((c) => c.id == comment.id)) return;
    state = state.copyWith(items: [comment, ...state.items]);
  }
}

final commentListProvider = NotifierProvider.family<CommentListNotifier, CommentListState, ContentInteractionKey>((key) => CommentListNotifier(key));