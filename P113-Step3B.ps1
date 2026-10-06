<#
.SYNOPSIS
  P-113 / STEP 3 / PART B - the real Saved screen (Posts / Reels / Products
  tabs, unsave in place, empty / error states, paging) replacing the STEP 1
  placeholder.

.DESCRIPTION
  Creates the new files (domain, data, provider, screen and their tests),
  replaces the STEP 1 placeholder lib\features\saved\presentation\saved_screen.dart,
  and appends the new "saved*" keys to the end of both ARB files (nothing else
  in the ARB files is touched). Then runs `flutter gen-l10n`.

  - Run it from anywhere; pass the Flutter project folder with -MobileRoot.
  - Safe to run twice: ARB keys already there are not added again, and files
    that already come from this step are simply rewritten.
  - Every file it overwrites is first copied to a backup folder NEXT TO the
    project folder (never inside the repository, so it cannot be committed).
  - It never touches app_router.dart, the navigation manifest, the shell, the
    hub, or any file that is not listed in the summary at the end.

.PARAMETER MobileRoot
  The Flutter project folder (the one that contains pubspec.yaml).

.PARAMETER SkipGenL10n
  Do not run `flutter gen-l10n` at the end (run it yourself afterwards).

.PARAMETER Force
  Overwrite files even when they do not look like the STEP 1 placeholder or an
  earlier run of this step.
#>
[CmdletBinding()]
param(
    [string]$MobileRoot = 'D:\Cavallo\social_commerce_app',
    [switch]$SkipGenL10n,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$path) {
    return [System.IO.File]::ReadAllText($path, $utf8NoBom)
}

function Save-Text([string]$path, [string]$text) {
    $t = $text -replace "`r`n", "`n"
    if (-not $t.EndsWith("`n")) { $t += "`n" }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($path, $t, $utf8NoBom)
}

# ---------------------------------------------------------------
# 0. Preflight: make sure this is the right project in the right state
# ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $MobileRoot)) {
    throw "MobileRoot not found: $MobileRoot  (pass -MobileRoot <flutter project folder>)"
}
$root = (Resolve-Path -LiteralPath $MobileRoot).Path

$pubspecPath = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) {
    throw "pubspec.yaml not found in $root"
}
if (-not ((Read-Text $pubspecPath) -match '(?m)^name:\s*social_commerce_app\s*$')) {
    throw "$pubspecPath is not the social_commerce_app project."
}

$required = @(
    'lib\routing\app_router.dart',
    'lib\routing\route_names.dart',
    'lib\core\shell\app_shell.dart',
    'lib\core\config\app_config.dart',
    'lib\core\l10n\error_messages.dart',
    'lib\core\l10n\l10n_context.dart',
    'lib\core\network\dio_client.dart',
    'lib\core\network\api_failure.dart',
    'lib\core\network\paginated_response.dart',
    'lib\core\theme\app_colors.dart',
    'lib\core\theme\app_theme.dart',
    'lib\core\widgets\empty_state_widget.dart',
    'lib\core\widgets\error_state_widget.dart',
    'lib\core\widgets\loading_indicator.dart',
    'lib\features\auth\domain\user_entity.dart',
    'lib\features\auth\presentation\session_provider.dart',
    'lib\features\social\data\social_interaction_repository_impl.dart',
    'lib\features\social\domain\social_interaction_repository.dart',
    'lib\features\profile_hub\presentation\profile_hub_screen.dart',
    'lib\features\saved\presentation\saved_screen.dart',
    'lib\l10n\app_en.arb',
    'lib\l10n\app_ar.arb'
)
$missing = @()
foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) { $missing += $rel }
}
if ($missing.Count -gt 0) {
    throw ("These files are missing, so the earlier steps of P-113 are not in this folder:`n  " + ($missing -join "`n  "))
}

$hubCurrent = Read-Text (Join-Path $root 'lib\features\profile_hub\presentation\profile_hub_screen.dart')
if ((-not $hubCurrent.Contains('Part P-113 (STEP 3A)')) -and (-not $Force)) {
    throw "profile_hub_screen.dart is not the STEP 3A file, so STEP 3 / PART A has not been applied here. Nothing was changed. Use -Force to continue anyway."
}

$savedPath = Join-Path $root 'lib\features\saved\presentation\saved_screen.dart'
$savedCurrent = Read-Text $savedPath
$savedIsPlaceholder = $savedCurrent.Contains('TEMPORARY (P-113 STEP 1 fix)')
$savedIsStep3B = $savedCurrent.Contains('Part P-113 (STEP 3B)')
if ((-not $savedIsPlaceholder) -and (-not $savedIsStep3B) -and (-not $Force)) {
    throw "saved_screen.dart is neither the STEP 1 placeholder nor a STEP 3B file. Nothing was changed. Use -Force to overwrite it anyway."
}

$enPath = Join-Path $root 'lib\l10n\app_en.arb'
$arPath = Join-Path $root 'lib\l10n\app_ar.arb'
$enText = Read-Text $enPath
$arText = Read-Text $arPath
$enHas = $enText.Contains('"savedTabPosts"')
$arHas = $arText.Contains('"savedTabPosts"')
if ($enHas -ne $arHas) {
    throw "app_en.arb and app_ar.arb disagree about the saved keys (savedTabPosts is in only one of them). Nothing was changed."
}
$arbAlreadyDone = $enHas

# ---------------------------------------------------------------
# Embedded content
# ---------------------------------------------------------------
$arbEn = @'
  "savedTabPosts": "Posts",
  "@savedTabPosts": {
    "description": "Tab of the Saved screen: saved posts."
  },
  "savedTabReels": "Reels",
  "@savedTabReels": {
    "description": "Tab of the Saved screen: saved reels."
  },
  "savedTabProducts": "Products",
  "@savedTabProducts": {
    "description": "Tab of the Saved screen: saved products."
  },
  "savedEmptyPosts": "No saved posts yet. Tap the bookmark on a post to keep it here.",
  "@savedEmptyPosts": {
    "description": "Empty state of the Saved screen, Posts tab."
  },
  "savedEmptyReels": "No saved reels yet. Tap the bookmark on a reel to keep it here.",
  "@savedEmptyReels": {
    "description": "Empty state of the Saved screen, Reels tab."
  },
  "savedEmptyProducts": "No saved products yet. Tap the bookmark on a product to keep it here.",
  "@savedEmptyProducts": {
    "description": "Empty state of the Saved screen, Products tab."
  },
  "savedUnsave": "Remove from saved",
  "@savedUnsave": {
    "description": "Tooltip of the bookmark button that removes an item from Saved."
  },
  "savedUnavailable": "This item is no longer available",
  "@savedUnavailable": {
    "description": "Shown instead of the preview when a saved item no longer exists."
  },
  "savedNoPreviewText": "Saved item",
  "@savedNoPreviewText": {
    "description": "Title of a saved item whose preview text is empty (for example an image-only post)."
  },
  "savedUnsaveFailed": "Couldn't remove it from saved. Please try again.",
  "@savedUnsaveFailed": {
    "description": "SnackBar shown when removing an item from Saved fails."
  },
  "savedLoadMoreFailed": "Couldn't load more saved items.",
  "@savedLoadMoreFailed": {
    "description": "Shown when loading the next page of the Saved list fails, next to a Retry button."
  }
'@

$arbAr = @'
  "savedTabPosts": "\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a",
  "savedTabReels": "\u0627\u0644\u0631\u064a\u0644\u0632",
  "savedTabProducts": "\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a",
  "savedEmptyPosts": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u0634\u0648\u0631\u0627\u062a \u0645\u062d\u0641\u0648\u0638\u0629 \u0628\u0639\u062f. \u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0639\u0644\u0627\u0645\u0629 \u0627\u0644\u062d\u0641\u0638 \u0641\u064a \u0623\u064a \u0645\u0646\u0634\u0648\u0631 \u0644\u064a\u0638\u0647\u0631 \u0647\u0646\u0627.",
  "savedEmptyReels": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0631\u064a\u0644\u0632 \u0645\u062d\u0641\u0648\u0638\u0629 \u0628\u0639\u062f. \u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0639\u0644\u0627\u0645\u0629 \u0627\u0644\u062d\u0641\u0638 \u0641\u064a \u0623\u064a \u0631\u064a\u0644 \u0644\u064a\u0638\u0647\u0631 \u0647\u0646\u0627.",
  "savedEmptyProducts": "\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u062d\u0641\u0648\u0638\u0629 \u0628\u0639\u062f. \u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0639\u0644\u0627\u0645\u0629 \u0627\u0644\u062d\u0641\u0638 \u0641\u064a \u0623\u064a \u0645\u0646\u062a\u062c \u0644\u064a\u0638\u0647\u0631 \u0647\u0646\u0627.",
  "savedUnsave": "\u0625\u0632\u0627\u0644\u0629 \u0645\u0646 \u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0627\u062a",
  "savedUnavailable": "\u0647\u0630\u0627 \u0627\u0644\u0639\u0646\u0635\u0631 \u0644\u0645 \u064a\u0639\u062f \u0645\u062a\u0627\u062d\u064b\u0627",
  "savedNoPreviewText": "\u0639\u0646\u0635\u0631 \u0645\u062d\u0641\u0648\u0638",
  "savedUnsaveFailed": "\u062a\u0639\u0630\u0651\u0631\u062a \u0627\u0644\u0625\u0632\u0627\u0644\u0629 \u0645\u0646 \u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0627\u062a. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "savedLoadMoreFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0632\u064a\u062f \u0645\u0646 \u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0627\u062a."
'@

$sources = @(
    @{ Path = 'lib\features\saved\domain\saved_item.dart'; Replaces = $false; Content = @'
/// Part P-113 (STEP 3B): what the Saved screen knows about one bookmark.
///
/// The backend (`SaveSerializer`, social/serializers.py) returns, for every
/// row of `GET /api/v1/saves/me/`:
///
/// ```json
/// {
///   "id": 12,
///   "content_type": "post" | "reel" | "product",
///   "object_id": 345,
///   "preview": {"preview_text": "...", "preview_image_url": "..." | null}
///             | null,
///   "created_at": "2026-10-05T10:00:00Z"
/// }
/// ```
///
/// `preview` is `null` when the saved target no longer exists. Such an item is
/// [isUnavailable]: the screen shows it as "no longer available" and does not
/// open anything when it is tapped.
enum SavedContentType {
  post('post'),
  reel('reel'),
  product('product');

  const SavedContentType(this.wireValue);

  /// The exact `content_type` string the backend sends and accepts
  /// (`SAVE_ALLOWED_CONTENT_TYPES`).
  final String wireValue;

  /// The type for a backend `content_type` string, or null for a value this
  /// app does not know (a future backend type must not crash the screen).
  static SavedContentType? fromWire(Object? value) {
    for (final SavedContentType type in SavedContentType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}

class SavedItem {
  const SavedItem({
    required this.id,
    required this.contentType,
    required this.objectId,
    this.previewText,
    this.previewImageUrl,
    this.createdAt,
  });

  /// The id of the Save row (not of the saved content).
  final int id;

  final SavedContentType contentType;

  /// The id of the saved Post, Reel or Product. Used for the detail route and
  /// for unsaving.
  final int objectId;

  /// `preview.preview_text`; null only when the whole `preview` is null.
  final String? previewText;

  final String? previewImageUrl;

  final DateTime? createdAt;

  /// True when the backend sent `preview: null` (the target is gone).
  bool get isUnavailable => previewText == null;

  /// Parses one row of the saved list. Returns null (the row is skipped) when
  /// the row is malformed or its `content_type` is not one this app knows.
  static SavedItem? tryFromJson(Map<String, dynamic> json) {
    final SavedContentType? type = SavedContentType.fromWire(
      json['content_type'],
    );
    final Object? id = json['id'];
    final Object? objectId = json['object_id'];
    if (type == null || id is! int || objectId is! int) {
      return null;
    }

    String? text;
    String? imageUrl;
    final Object? preview = json['preview'];
    if (preview is Map<String, dynamic>) {
      text = preview['preview_text'] as String? ?? '';
      final String? rawUrl = preview['preview_image_url'] as String?;
      imageUrl = (rawUrl == null || rawUrl.isEmpty) ? null : rawUrl;
    }

    return SavedItem(
      id: id,
      contentType: type,
      objectId: objectId,
      previewText: text,
      previewImageUrl: imageUrl,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedItem &&
          other.id == id &&
          other.contentType == contentType &&
          other.objectId == objectId &&
          other.previewText == previewText &&
          other.previewImageUrl == previewImageUrl &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    contentType,
    objectId,
    previewText,
    previewImageUrl,
    createdAt,
  );

  @override
  String toString() =>
      'SavedItem(id: $id, ${contentType.wireValue}:$objectId, '
      'unavailable: $isUnavailable)';
}
'@ }
    @{ Path = 'lib\features\saved\domain\saved_repository.dart'; Replaces = $false; Content = @'
import '../../../core/network/paginated_response.dart';
import 'saved_item.dart';

/// Part P-113 (STEP 3B): reading the signed-in user's saved items.
///
/// Only the LIST lives here. Saving and unsaving already exist in
/// `SocialInteractionRepository` (`saveContent` / `unsaveContent`, P-058), so
/// the Saved screen reuses that one instead of adding a second implementation.
abstract class SavedRepository {
  /// `GET /api/v1/saves/me/`, newest first, mixed Posts / Reels / Products,
  /// standard `{results, next, previous}` cursor pagination.
  ///
  /// [cursor], when given, is the exact `next` URL of the previous page and is
  /// passed to Dio verbatim, never rebuilt (same rule as every other list).
  /// Rows whose `content_type` this app does not know are dropped.
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor});
}
'@ }
    @{ Path = 'lib\features\saved\data\saved_repository_impl.dart'; Replaces = $false; Content = @'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../domain/saved_item.dart';
import '../domain/saved_repository.dart';

/// Part P-113 (STEP 3B): [SavedRepository] over the shared Dio client (so the
/// Authorization header and the silent token refresh come for free).
///
/// Error convention: same as `NotificationRepositoryImpl` - catch
/// [DioException] and rethrow the typed [ApiFailure] that `ErrorInterceptor`
/// stored on `.error`, so callers only ever catch [ApiFailure].
class SavedRepositoryImpl implements SavedRepository {
  SavedRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String listPath = '/api/v1/saves/me/';

  @override
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor}) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(cursor ?? listPath);
      final Map<String, dynamic> json = response.data!;
      final List<dynamic> rawResults = json['results'] as List<dynamic>;

      final List<SavedItem> items = <SavedItem>[];
      for (final dynamic raw in rawResults) {
        final SavedItem? item = SavedItem.tryFromJson(
          raw as Map<String, dynamic>,
        );
        if (item != null) {
          items.add(item);
        }
      }

      return PaginatedResponse<SavedItem>(
        results: items,
        next: json['next'] as String?,
        previous: json['previous'] as String?,
      );
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  Never _rethrowTyped(DioException e) {
    final Object? error = e.error;
    if (error is ApiFailure) {
      throw error;
    }
    throw e;
  }
}

final Provider<SavedRepository> savedRepositoryProvider =
    Provider<SavedRepository>((Ref ref) {
      return SavedRepositoryImpl(dio: ref.watch(dioClientProvider));
    });
'@ }
    @{ Path = 'lib\features\saved\presentation\saved_list_provider.dart'; Replaces = $false; Content = @'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../social/data/social_interaction_repository_impl.dart';
import '../data/saved_repository_impl.dart';
import '../domain/saved_item.dart';

/// Part P-113 (STEP 3B): `savedListProvider` - the Saved screen's list and its
/// pagination position. Plain Riverpod `AsyncNotifier`, same convention as
/// `notificationListProvider` and `homeFeedProvider`.
///
/// ### One list, three tabs
/// `GET /api/v1/saves/me/` has no content-type filter, so the notifier holds
/// ONE mixed, newest-first list and each tab filters it with
/// [SavedListState.itemsOf]. A tab may therefore be short or empty while the
/// server still has more pages; the screen keeps loading pages until the tab
/// has enough rows or the list ends.
///
/// ### Unsave in place
/// [SavedListNotifier.unsave] removes the row immediately, calls the EXISTING
/// `SocialInteractionRepository.unsaveContent` (P-058, idempotent), and puts
/// the row back at its old position if the call fails.
///
/// ### Account changes
/// `build()` watches the signed-in user id, so a different account never sees
/// the previous account's list. The provider is `autoDispose` as well.
class SavedListState {
  const SavedListState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<SavedItem> items;

  /// The `next` URL of the last loaded page, or null when the list has ended.
  final String? nextCursor;

  final bool isLoadingMore;

  /// The last attempt to load another page failed. While true the screen does
  /// not retry on its own (no request loop); the user's retry clears it.
  final bool loadMoreFailed;

  bool get hasMore => nextCursor != null;

  /// The loaded items of one tab, in the server's (newest-first) order.
  List<SavedItem> itemsOf(SavedContentType type) => <SavedItem>[
    for (final SavedItem item in items)
      if (item.contentType == type) item,
  ];

  SavedListState copyWith({
    List<SavedItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return SavedListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

class SavedListNotifier extends AsyncNotifier<SavedListState> {
  @override
  Future<SavedListState> build() async {
    // A different signed-in account rebuilds this notifier, which drops the
    // old account's list.
    ref.watch(
      sessionProvider.select(
        (AsyncValue<User?> session) => switch (session) {
          AsyncData(:final value) => value?.id,
          _ => null,
        },
      ),
    );

    final page = await ref.watch(savedRepositoryProvider).listSaved();
    return SavedListState(items: page.results, nextCursor: page.next);
  }

  /// Discards the local list and fetches a genuine fresh first page (the
  /// screen shows its loading state meanwhile). A failure settles into
  /// `AsyncError` without rethrowing, so the screen can offer "Retry".
  Future<void> refresh() async {
    state = const AsyncValue<SavedListState>.loading();
    state = await AsyncValue.guard<SavedListState>(() async {
      final page = await ref.read(savedRepositoryProvider).listSaved();
      return SavedListState(items: page.results, nextCursor: page.next);
    });
  }

  /// Fetches a fresh first page WITHOUT clearing the screen: used for
  /// pull-to-refresh and when the Saved tab is selected again (the user may
  /// have saved something elsewhere meanwhile). On failure the list on screen
  /// is simply kept. When there is no list yet (error state), it falls back
  /// to [refresh].
  Future<void> refreshSilently() async {
    final current = state.value;
    if (current == null) {
      if (state.hasError) {
        await refresh();
      }
      return;
    }
    if (current.isLoadingMore) {
      return;
    }
    try {
      final page = await ref.read(savedRepositoryProvider).listSaved();
      if (!ref.mounted) return;
      state = AsyncData(
        SavedListState(items: page.results, nextCursor: page.next),
      );
    } catch (_) {
      // Keep the list that is already on screen.
    }
  }

  /// Appends the next page. No-op when there is no cursor or a load is
  /// already running. On failure the loaded items are kept, `loadMoreFailed`
  /// is set and the error is rethrown to the caller.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.nextCursor == null || current.isLoadingMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final page = await ref
          .read(savedRepositoryProvider)
          .listSaved(cursor: current.nextCursor);
      if (!ref.mounted) return;

      // Re-read: an unsave may have changed the list while the page loaded.
      final latest = state.value ?? current;
      final knownIds = latest.items.map((SavedItem i) => i.id).toSet();
      state = AsyncData(
        latest.copyWith(
          items: <SavedItem>[
            ...latest.items,
            ...page.results.where((SavedItem i) => !knownIds.contains(i.id)),
          ],
          nextCursor: page.next,
          clearNextCursor: page.next == null,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
      rethrow;
    }
  }

  /// Removes [item] from the list at once, then unsaves it on the server. If
  /// the server call fails the item returns to its old position and the error
  /// is rethrown (the screen shows a SnackBar).
  Future<void> unsave(SavedItem item) async {
    final current = state.value;
    if (current == null) return;
    final int index = current.items.indexWhere(
      (SavedItem i) => i.id == item.id,
    );
    if (index < 0) return;

    state = AsyncData(
      current.copyWith(
        items: <SavedItem>[
          for (final SavedItem i in current.items)
            if (i.id != item.id) i,
        ],
      ),
    );

    try {
      await ref
          .read(socialInteractionRepositoryProvider)
          .unsaveContent(
            contentType: item.contentType.wireValue,
            objectId: item.objectId,
          );
    } catch (_) {
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null &&
            !latest.items.any((SavedItem i) => i.id == item.id)) {
          final List<SavedItem> restored = List<SavedItem>.of(latest.items);
          restored.insert(
            index > restored.length ? restored.length : index,
            item,
          );
          state = AsyncData(latest.copyWith(items: restored));
        }
      }
      rethrow;
    }
  }
}

final savedListProvider =
    AsyncNotifierProvider.autoDispose<SavedListNotifier, SavedListState>(
      SavedListNotifier.new,
      retry: (retryCount, error) => null,
    );
'@ }
    @{ Path = 'lib\features\saved\presentation\saved_screen.dart'; Replaces = $true; Content = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_names.dart';
import '../domain/saved_item.dart';
import 'saved_list_provider.dart';

/// Part P-113 (STEP 3B): the Saved screen - tab 3 of the Customer bottom bar
/// and a Profile hub row for every account type. It replaces the STEP 1
/// placeholder.
///
/// ## What it shows
/// Three tabs (Posts, Reels, Products) over ONE list from
/// `GET /api/v1/saves/me/` ([savedListProvider]). Every row has a thumbnail,
/// the preview text and a filled bookmark button that unsaves it in place.
/// Tapping a row opens the existing Post / Reel / Product detail route, the
/// same way a shared chat card does. A row whose target no longer exists
/// reads "no longer available" and opens nothing (it can still be removed).
///
/// ## States
/// * loading: spinner; error: the shared error state with Retry;
/// * a tab with no items: its own empty message (pull down to refresh);
/// * more pages: loaded when the user scrolls near the end, and also
///   automatically while a tab has fewer than [minRowsPerTab] rows (the
///   endpoint cannot filter by type, so a tab can be short on page one);
/// * a failed page load shows a retry row and is never retried in a loop.
///
/// ## Staying fresh
/// The shell keeps this screen alive while another tab is showing. When the
/// tab becomes active again the list is refreshed silently (the branch's
/// `TickerMode` flips from disabled to enabled), so something saved from Home
/// in the meantime appears without a manual refresh.
///
/// Texts come from the ARB files, colours from the theme tokens, and layout
/// uses directional widgets only.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  /// Pages are loaded automatically until a tab has at least this many rows.
  static const int minRowsPerTab = 6;

  static const Key tabBarKey = Key('saved-tab-bar');

  static Key tabKey(SavedContentType type) => Key('saved-tab-${type.name}');

  static Key emptyKey(SavedContentType type) => Key('saved-empty-${type.name}');

  static Key itemKey(SavedContentType type, int objectId) =>
      Key('saved-item-${type.name}-$objectId');

  static Key unsaveKey(SavedContentType type, int objectId) =>
      Key('saved-unsave-${type.name}-$objectId');

  static const Key retryMoreKey = Key('saved-retry-more');

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  bool? _wasActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `TickerMode` is disabled by the shell for a tab that is not showing.
    final bool active = TickerMode.of(context);
    if (_wasActive == false && active) {
      // Not during build: providers must not change while the tree builds.
      Future<void>.microtask(() {
        if (mounted) {
          unawaited(ref.read(savedListProvider.notifier).refreshSilently());
        }
      });
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SavedListState> async = ref.watch(savedListProvider);

    final Widget body = switch (async) {
      AsyncData(:final value) => TabBarView(
        children: <Widget>[
          for (final SavedContentType type in SavedContentType.values)
            _SavedTab(type: type, state: value),
        ],
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: localizedApiError(l10n, error),
        onRetry: () => unawaited(ref.read(savedListProvider.notifier).refresh()),
      ),
      _ => const LoadingIndicator(),
    };

    return DefaultTabController(
      length: SavedContentType.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hubSaved),
          bottom: TabBar(
            key: SavedScreen.tabBarKey,
            tabs: <Widget>[
              Tab(
                key: SavedScreen.tabKey(SavedContentType.post),
                text: l10n.savedTabPosts,
              ),
              Tab(
                key: SavedScreen.tabKey(SavedContentType.reel),
                text: l10n.savedTabReels,
              ),
              Tab(
                key: SavedScreen.tabKey(SavedContentType.product),
                text: l10n.savedTabProducts,
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

void _loadMoreQuietly(WidgetRef ref) {
  unawaited(
    ref.read(savedListProvider.notifier).loadMore().catchError((Object _) {}),
  );
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab({required this.type, required this.state});

  final SavedContentType type;
  final SavedListState state;

  String _emptyMessage(AppLocalizations l10n) => switch (type) {
    SavedContentType.post => l10n.savedEmptyPosts,
    SavedContentType.reel => l10n.savedEmptyReels,
    SavedContentType.product => l10n.savedEmptyProducts,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<SavedItem> items = state.itemsOf(type);

    final bool canAutoLoad =
        state.hasMore && !state.isLoadingMore && !state.loadMoreFailed;
    if (canAutoLoad && items.length < SavedScreen.minRowsPerTab) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (context.mounted) {
          _loadMoreQuietly(ref);
        }
      });
    }

    Future<void> refresh() =>
        ref.read(savedListProvider.notifier).refreshSilently();

    if (items.isEmpty) {
      if (state.hasMore) {
        // Other pages may still hold items of this type.
        if (state.loadMoreFailed) {
          return ErrorStateWidget(
            message: l10n.savedLoadMoreFailed,
            onRetry: () => _loadMoreQuietly(ref),
          );
        }
        return const LoadingIndicator();
      }
      return RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                SizedBox(
                  height: constraints.maxHeight,
                  child: EmptyStateWidget(
                    key: SavedScreen.emptyKey(type),
                    icon: Icons.bookmark_border,
                    message: _emptyMessage(l10n),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bool showFooter = state.isLoadingMore || state.loadMoreFailed;

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          final ScrollMetrics metrics = notification.metrics;
          if (metrics.axis == Axis.vertical &&
              metrics.extentAfter < 300 &&
              state.hasMore &&
              !state.isLoadingMore &&
              !state.loadMoreFailed) {
            _loadMoreQuietly(ref);
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (showFooter ? 1 : 0),
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            if (index >= items.length) {
              return _LoadMoreFooter(
                failed: state.loadMoreFailed,
                onRetry: () => _loadMoreQuietly(ref),
              );
            }
            return _SavedItemTile(item: items[index]);
          },
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (!failed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 24, child: LoadingIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.savedLoadMoreFailed,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            key: SavedScreen.retryMoreKey,
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _SavedItemTile extends ConsumerWidget {
  const _SavedItemTile({required this.item});

  final SavedItem item;

  void _open(BuildContext context) {
    final Map<String, String> params = <String, String>{
      RouteNames.idParam: '${item.objectId}',
    };
    switch (item.contentType) {
      case SavedContentType.post:
        context.pushNamed(RouteNames.postDetail, pathParameters: params);
      case SavedContentType.reel:
        context.pushNamed(RouteNames.reelDetail, pathParameters: params);
      case SavedContentType.product:
        context.pushNamed(RouteNames.productDetail, pathParameters: params);
    }
  }

  Future<void> _unsave(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    try {
      await ref.read(savedListProvider.notifier).unsave(item);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.savedUnsaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final bool unavailable = item.isUnavailable;
    final String preview = item.previewText ?? '';

    return ListTile(
      key: SavedScreen.itemKey(item.contentType, item.objectId),
      leading: _SavedThumbnail(
        url: item.previewImageUrl,
        type: item.contentType,
      ),
      title: Text(
        unavailable
            ? l10n.savedUnavailable
            : (preview.isEmpty ? l10n.savedNoPreviewText : preview),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: unavailable ? TextStyle(color: colors.textSecondary) : null,
      ),
      trailing: IconButton(
        key: SavedScreen.unsaveKey(item.contentType, item.objectId),
        icon: Icon(Icons.bookmark, color: colors.brand),
        tooltip: l10n.savedUnsave,
        onPressed: () => unawaited(_unsave(context, ref)),
      ),
      onTap: unavailable ? null : () => _open(context),
    );
  }
}

class _SavedThumbnail extends StatelessWidget {
  const _SavedThumbnail({required this.url, required this.type});

  final String? url;
  final SavedContentType type;

  static const double size = 56;

  IconData get _icon => switch (type) {
    SavedContentType.post => Icons.image_outlined,
    SavedContentType.reel => Icons.play_circle_outline,
    SavedContentType.product => Icons.shopping_bag_outlined,
  };

  /// The backend may return a path (`/media/...`) when the file storage is
  /// local; make it absolute against the API host.
  static String _absolute(String raw) {
    final Uri uri = Uri.parse(raw);
    if (uri.hasScheme) {
      return raw;
    }
    return Uri.parse(AppConfig.apiBaseUrl).resolve(raw).toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final BorderRadius radius = BorderRadius.circular(8);

    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: radius),
      child: Icon(_icon, color: colors.textSecondary),
    );

    final String? imageUrl = url;
    if (imageUrl == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        _absolute(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                placeholder,
      ),
    );
  }
}
'@ }
    @{ Path = 'test\features\saved\domain\saved_item_test.dart'; Replaces = $false; Content = @'
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';

/// Part P-113 (STEP 3B): parsing one row of `GET /api/v1/saves/me/`.
void main() {
  group('SavedContentType', () {
    test('wire values are exactly the backend whitelist', () {
      expect(
        SavedContentType.values.map((SavedContentType t) => t.wireValue),
        <String>['post', 'reel', 'product'],
      );
    });

    test('fromWire maps known values and returns null for unknown ones', () {
      expect(SavedContentType.fromWire('post'), SavedContentType.post);
      expect(SavedContentType.fromWire('reel'), SavedContentType.reel);
      expect(SavedContentType.fromWire('product'), SavedContentType.product);
      expect(SavedContentType.fromWire('story'), isNull);
      expect(SavedContentType.fromWire(null), isNull);
    });
  });

  group('SavedItem.tryFromJson', () {
    test('parses a full row', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 12,
        'content_type': 'reel',
        'object_id': 345,
        'preview': <String, dynamic>{
          'preview_text': 'Factory tour',
          'preview_image_url': 'https://cdn.example.com/t.jpg',
        },
        'created_at': '2026-10-05T10:00:00Z',
      });

      expect(item, isNotNull);
      expect(item!.id, 12);
      expect(item.contentType, SavedContentType.reel);
      expect(item.objectId, 345);
      expect(item.previewText, 'Factory tour');
      expect(item.previewImageUrl, 'https://cdn.example.com/t.jpg');
      expect(item.createdAt, DateTime.utc(2026, 10, 5, 10));
      expect(item.isUnavailable, isFalse);
    });

    test('preview null means the target is gone (unavailable)', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 1,
        'content_type': 'post',
        'object_id': 2,
        'preview': null,
        'created_at': '2026-10-05T10:00:00Z',
      });

      expect(item, isNotNull);
      expect(item!.isUnavailable, isTrue);
      expect(item.previewText, isNull);
      expect(item.previewImageUrl, isNull);
    });

    test('an empty image URL becomes null and empty text stays available', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 1,
        'content_type': 'post',
        'object_id': 2,
        'preview': <String, dynamic>{
          'preview_text': '',
          'preview_image_url': '',
        },
        'created_at': 'not-a-date',
      });

      expect(item!.previewImageUrl, isNull);
      expect(item.previewText, '');
      expect(item.isUnavailable, isFalse);
      expect(item.createdAt, isNull);
    });

    test('an unknown content type or a malformed row is skipped', () {
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 1,
          'content_type': 'story',
          'object_id': 2,
          'preview': null,
        }),
        isNull,
      );
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 'x',
          'content_type': 'post',
          'object_id': 2,
        }),
        isNull,
      );
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 1,
          'content_type': 'post',
        }),
        isNull,
      );
    });
  });
}
'@ }
    @{ Path = 'test\features\saved\data\saved_repository_test.dart'; Replaces = $false; Content = @'
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';

/// Part P-113 (STEP 3B): the one read the Saved screen makes,
/// `GET /api/v1/saves/me/`.

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return dio;
}

const String _page = '''
{
  "next": "http://localhost/api/v1/saves/me/?cursor=abc",
  "previous": null,
  "results": [
    {"id": 3, "content_type": "post", "object_id": 30,
     "preview": {"preview_text": "A post", "preview_image_url": null},
     "created_at": "2026-10-05T10:00:00Z"},
    {"id": 2, "content_type": "story", "object_id": 20,
     "preview": null, "created_at": "2026-10-05T09:00:00Z"},
    {"id": 1, "content_type": "product", "object_id": 10,
     "preview": null, "created_at": "2026-10-05T08:00:00Z"}
  ]
}
''';

void main() {
  test('first page: GET /api/v1/saves/me/ and rows are parsed', () async {
    final _Adapter adapter = _Adapter(_page);
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(adapter),
    );

    final PaginatedResponse<SavedItem> page = await repository.listSaved();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, SavedRepositoryImpl.listPath);
    expect(SavedRepositoryImpl.listPath, '/api/v1/saves/me/');

    // The unknown "story" row is dropped; the others keep the server order.
    expect(page.results.map((SavedItem i) => i.id), <int>[3, 1]);
    expect(page.results.first.contentType, SavedContentType.post);
    expect(page.results.first.previewText, 'A post');
    expect(page.results.last.isUnavailable, isTrue);
    expect(page.next, 'http://localhost/api/v1/saves/me/?cursor=abc');
    expect(page.previous, isNull);
  });

  test('next page: the cursor URL is passed to Dio verbatim', () async {
    final _Adapter adapter = _Adapter(_page);
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(adapter),
    );

    await repository.listSaved(
      cursor: 'http://localhost/api/v1/saves/me/?cursor=abc',
    );

    expect(
      adapter.requests.single.uri.toString(),
      'http://localhost/api/v1/saves/me/?cursor=abc',
    );
  });

  test('an error status surfaces as an exception, not as an empty list', () {
    final SavedRepositoryImpl repository = SavedRepositoryImpl(
      dio: _dio(_Adapter('{}', statusCode: 500)),
    );

    expect(repository.listSaved(), throwsA(isA<DioException>()));
  });
}
'@ }
    @{ Path = 'test\features\saved\presentation\saved_test_support.dart'; Replaces = $false; Content = @'
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/domain/saved_repository.dart';
import 'package:social_commerce_app/features/social/domain/social_interaction_repository.dart';

/// Part P-113 (STEP 3B): shared fakes of the Saved provider and screen tests.

const User savedTestCustomer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User savedTestOtherCustomer = User(
  id: 2,
  email: 'other@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

SavedItem savedTestItem(
  int id,
  SavedContentType type, {
  int? objectId,
  String? text,
  bool unavailable = false,
}) {
  return SavedItem(
    id: id,
    contentType: type,
    objectId: objectId ?? id * 10,
    previewText: unavailable ? null : (text ?? 'Item $id'),
  );
}

/// Pages are addressed by index: the first request (no cursor) returns
/// `pages[0]`, a request with cursor `'1'` returns `pages[1]`, and so on.
/// Every page but the last carries `next` = the index of the following page.
class FakeSavedRepository implements SavedRepository {
  FakeSavedRepository(this.pages);

  final List<List<SavedItem>> pages;
  final List<String?> requestedCursors = <String?>[];

  /// When set, the next call throws this and clears it.
  Object? failNext;

  /// When set, every call with exactly this cursor throws (until cleared).
  String? failOnCursor;

  @override
  Future<PaginatedResponse<SavedItem>> listSaved({String? cursor}) async {
    requestedCursors.add(cursor);
    if (failOnCursor != null && cursor == failOnCursor) {
      throw StateError('page $cursor failed');
    }
    final Object? failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final int index = cursor == null ? 0 : int.parse(cursor);
    return PaginatedResponse<SavedItem>(
      results: pages.isEmpty ? <SavedItem>[] : pages[index],
      next: index + 1 < pages.length ? '${index + 1}' : null,
      previous: null,
    );
  }
}

/// Only [unsaveContent] is used by the Saved screen; everything else of the
/// interface would throw if called.
class FakeSocialInteractionRepository implements SocialInteractionRepository {
  final List<({String contentType, int objectId})> unsaved =
      <({String contentType, int objectId})>[];

  /// When set, [unsaveContent] waits for it before returning.
  Completer<void>? hold;

  bool fail = false;

  @override
  Future<bool> unsaveContent({
    required String contentType,
    required int objectId,
  }) async {
    unsaved.add((contentType: contentType, objectId: objectId));
    if (hold != null) {
      await hold!.future;
    }
    if (fail) {
      throw StateError('unsave failed');
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSavedSession extends SessionNotifier {
  FakeSavedSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;

  void signInAs(User user) {
    state = AsyncValue<User?>.data(user);
  }
}
'@ }
    @{ Path = 'test\features\saved\presentation\saved_list_provider_test.dart'; Replaces = $false; Content = @'
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/presentation/saved_list_provider.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import 'saved_test_support.dart';

/// Part P-113 (STEP 3B): the Saved list notifier - paging, unsave in place
/// (optimistic, with rollback) and account changes.

class _Harness {
  _Harness({
    required this.saved,
    required this.social,
    required this.session,
    required this.container,
  });

  final FakeSavedRepository saved;
  final FakeSocialInteractionRepository social;
  final FakeSavedSession session;
  final ProviderContainer container;

  SavedListNotifier get notifier => container.read(savedListProvider.notifier);

  SavedListState get state => container.read(savedListProvider).requireValue;
}

Future<_Harness> _start(List<List<SavedItem>> pages) async {
  final FakeSavedRepository saved = FakeSavedRepository(pages);
  final FakeSocialInteractionRepository social =
      FakeSocialInteractionRepository();
  final FakeSavedSession session = FakeSavedSession(savedTestCustomer);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => session),
      savedRepositoryProvider.overrideWithValue(saved),
      socialInteractionRepositoryProvider.overrideWithValue(social),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose: keep the provider alive for the whole test.
  final ProviderSubscription<AsyncValue<SavedListState>> sub = container
      .listen(savedListProvider, (previous, next) {});
  addTearDown(sub.close);
  await container.read(savedListProvider.future);
  return _Harness(
    saved: saved,
    social: social,
    session: session,
    container: container,
  );
}

void main() {
  group('first page', () {
    test('loads the first page and filters it per tab', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(3, SavedContentType.product),
          savedTestItem(2, SavedContentType.reel),
          savedTestItem(1, SavedContentType.post),
        ],
      ]);

      expect(h.saved.requestedCursors, <String?>[null]);
      expect(h.state.items, hasLength(3));
      expect(h.state.hasMore, isFalse);
      expect(
        h.state.itemsOf(SavedContentType.post).map((SavedItem i) => i.id),
        <int>[1],
      );
      expect(
        h.state.itemsOf(SavedContentType.reel).map((SavedItem i) => i.id),
        <int>[2],
      );
      expect(
        h.state.itemsOf(SavedContentType.product).map((SavedItem i) => i.id),
        <int>[3],
      );
    });
  });

  group('loadMore', () {
    test('appends the next page, skips known ids and clears the cursor', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(3, SavedContentType.post)],
        <SavedItem>[
          savedTestItem(3, SavedContentType.post), // already loaded
          savedTestItem(2, SavedContentType.reel),
        ],
      ]);
      expect(h.state.hasMore, isTrue);

      await h.notifier.loadMore();

      expect(h.saved.requestedCursors, <String?>[null, '1']);
      expect(h.state.items.map((SavedItem i) => i.id), <int>[3, 2]);
      expect(h.state.hasMore, isFalse);
      expect(h.state.isLoadingMore, isFalse);
    });

    test('does nothing when there is no next page', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);

      await h.notifier.loadMore();

      expect(h.saved.requestedCursors, <String?>[null]);
    });

    test('a failure keeps the items, flags it and rethrows; retry works', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(2, SavedContentType.post)],
        <SavedItem>[savedTestItem(1, SavedContentType.reel)],
      ]);
      h.saved.failNext = StateError('boom');

      await expectLater(h.notifier.loadMore(), throwsA(isA<StateError>()));

      expect(h.state.items.map((SavedItem i) => i.id), <int>[2]);
      expect(h.state.loadMoreFailed, isTrue);
      expect(h.state.isLoadingMore, isFalse);
      expect(h.state.hasMore, isTrue);

      await h.notifier.loadMore();

      expect(h.state.items.map((SavedItem i) => i.id), <int>[2, 1]);
      expect(h.state.loadMoreFailed, isFalse);
      expect(h.state.hasMore, isFalse);
    });
  });

  group('unsave', () {
    test('removes the item at once, then calls the existing unsave API', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(2, SavedContentType.product, objectId: 77),
          savedTestItem(1, SavedContentType.post, objectId: 55),
        ],
      ]);
      h.social.hold = Completer<void>();

      final Future<void> pending = h.notifier.unsave(h.state.items.first);

      // Optimistic: gone before the server answered.
      expect(h.state.items.map((SavedItem i) => i.id), <int>[1]);
      await Future<void>.delayed(Duration.zero);
      expect(h.social.unsaved, hasLength(1));
      expect(h.social.unsaved.single.contentType, 'product');
      expect(h.social.unsaved.single.objectId, 77);

      h.social.hold!.complete();
      await pending;
      expect(h.state.items.map((SavedItem i) => i.id), <int>[1]);
    });

    test('a failed unsave puts the item back at its old position', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[
          savedTestItem(3, SavedContentType.post),
          savedTestItem(2, SavedContentType.post),
          savedTestItem(1, SavedContentType.post),
        ],
      ]);
      h.social.fail = true;
      final SavedItem middle = h.state.items[1];

      await expectLater(h.notifier.unsave(middle), throwsA(isA<StateError>()));

      expect(h.state.items.map((SavedItem i) => i.id), <int>[3, 2, 1]);
    });

    test('unsaving an item that is not in the list does nothing', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);

      await h.notifier.unsave(savedTestItem(99, SavedContentType.post));

      expect(h.social.unsaved, isEmpty);
      expect(h.state.items, hasLength(1));
    });
  });

  group('refresh', () {
    test('refreshSilently replaces the list and keeps it on failure', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      h.saved.pages
        ..clear()
        ..add(<SavedItem>[
          savedTestItem(5, SavedContentType.reel),
          savedTestItem(1, SavedContentType.post),
        ]);

      await h.notifier.refreshSilently();
      expect(h.state.items.map((SavedItem i) => i.id), <int>[5, 1]);

      h.saved.failNext = StateError('offline');
      await h.notifier.refreshSilently();
      expect(h.state.items.map((SavedItem i) => i.id), <int>[5, 1]);
    });

    test('refresh settles into an error state instead of throwing', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      h.saved.failNext = StateError('down');

      await h.notifier.refresh();

      expect(h.container.read(savedListProvider).hasError, isTrue);

      await h.notifier.refresh();
      expect(h.container.read(savedListProvider).hasError, isFalse);
      expect(h.state.items, hasLength(1));
    });
  });

  group('account change', () {
    test('another signed-in user gets a freshly loaded list', () async {
      final _Harness h = await _start(<List<SavedItem>>[
        <SavedItem>[savedTestItem(1, SavedContentType.post)],
      ]);
      expect(h.saved.requestedCursors, hasLength(1));

      h.session.signInAs(savedTestOtherCustomer);
      await h.container.read(savedListProvider.future);

      expect(h.saved.requestedCursors, hasLength(2));
    });
  });
}
'@ }
    @{ Path = 'test\features\saved\presentation\saved_screen_test.dart'; Replaces = $false; Content = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/saved/data/saved_repository_impl.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';
import 'package:social_commerce_app/features/saved/presentation/saved_screen.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import 'saved_test_support.dart';

/// Part P-113 (STEP 3B): widget tests of the Saved screen.
///
/// * three tabs, each showing only its own type;
/// * rows open the existing Post / Reel / Product detail route;
/// * a row whose target is gone says so and opens nothing;
/// * unsave in place, with a message and a rollback when it fails;
/// * empty and error states;
/// * pages are loaded automatically while a tab is short;
/// * the list is refreshed when the tab becomes active again;
/// * Arabic labels.

const String _arPosts = '\u0627\u0644\u0645\u0646\u0634\u0648\u0631\u0627\u062a';
const String _arProducts =
    '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a';

GoRouter _router(ValueNotifier<bool> tabActive) {
  GoRoute stub(String name, String path) {
    return GoRoute(
      path: path,
      name: name,
      builder:
          (BuildContext context, GoRouterState state) => Scaffold(
            appBar: AppBar(),
            body: Text('stub:$name:${state.pathParameters[RouteNames.idParam]}'),
          ),
    );
  }

  return GoRouter(
    initialLocation: RouteNames.savedPath,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.savedPath,
        name: RouteNames.saved,
        builder:
            (BuildContext context, GoRouterState state) =>
                ValueListenableBuilder<bool>(
                  valueListenable: tabActive,
                  builder:
                      (BuildContext context, bool active, Widget? child) =>
                          TickerMode(enabled: active, child: child!),
                  child: const SavedScreen(),
                ),
      ),
      stub(RouteNames.postDetail, RouteNames.postDetailPath),
      stub(RouteNames.reelDetail, RouteNames.reelDetailPath),
      stub(RouteNames.productDetail, RouteNames.productDetailPath),
    ],
  );
}

Future<ValueNotifier<bool>> _pump(
  WidgetTester tester, {
  required FakeSavedRepository saved,
  required FakeSocialInteractionRepository social,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ValueNotifier<bool> tabActive = ValueNotifier<bool>(true);
  addTearDown(tabActive.dispose);
  final GoRouter router = _router(tabActive);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => FakeSavedSession(savedTestCustomer)),
        savedRepositoryProvider.overrideWithValue(saved),
        socialInteractionRepositoryProvider.overrideWithValue(social),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tabActive;
}

Future<void> _selectTab(WidgetTester tester, SavedContentType type) async {
  await tester.tap(find.byKey(SavedScreen.tabKey(type)));
  await tester.pumpAndSettle();
}

Finder _item(SavedContentType type, int objectId) =>
    find.byKey(SavedScreen.itemKey(type, objectId));

Finder _unsaveButton(SavedContentType type, int objectId) =>
    find.byKey(SavedScreen.unsaveKey(type, objectId));

FakeSavedRepository _mixedRepository() {
  return FakeSavedRepository(<List<SavedItem>>[
    <SavedItem>[
      savedTestItem(5, SavedContentType.post, objectId: 105, text: 'Linen shirt'),
      savedTestItem(4, SavedContentType.reel, objectId: 204, text: 'Factory tour'),
      savedTestItem(3, SavedContentType.product, objectId: 303, text: 'Cotton roll'),
      savedTestItem(2, SavedContentType.post, objectId: 102, unavailable: true),
      savedTestItem(1, SavedContentType.post, objectId: 101, text: 'Denim lookbook'),
    ],
  ]);
}

void main() {
  testWidgets('each tab shows only its own type', (WidgetTester tester) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);

    // Posts tab (selected first).
    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(find.text('Linen shirt'), findsOneWidget);
    expect(find.text('Denim lookbook'), findsOneWidget);
    expect(_item(SavedContentType.reel, 204), findsNothing);

    await _selectTab(tester, SavedContentType.reel);
    expect(_item(SavedContentType.reel, 204), findsOneWidget);
    expect(find.text('Factory tour'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);

    await _selectTab(tester, SavedContentType.product);
    expect(_item(SavedContentType.product, 303), findsOneWidget);
    expect(find.text('Cotton roll'), findsOneWidget);
  });

  testWidgets('tapping a row opens the matching detail route', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    await tester.tap(_item(SavedContentType.post, 105));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.postDetail}:105'), findsOneWidget);

    // Back to the Saved screen, then a Reel and a Product.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _selectTab(tester, SavedContentType.reel);
    await tester.tap(_item(SavedContentType.reel, 204));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.reelDetail}:204'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _selectTab(tester, SavedContentType.product);
    await tester.tap(_item(SavedContentType.product, 303));
    await tester.pumpAndSettle();
    expect(find.text('stub:${RouteNames.productDetail}:303'), findsOneWidget);
  });

  testWidgets('an item whose target is gone says so and opens nothing', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('This item is no longer available'), findsOneWidget);

    await tester.tap(_item(SavedContentType.post, 102));
    await tester.pumpAndSettle();

    expect(find.textContaining('stub:'), findsNothing);
    expect(find.byKey(SavedScreen.tabBarKey), findsOneWidget);
  });

  testWidgets('unsave removes the row in place and calls the unsave API', (
    WidgetTester tester,
  ) async {
    final FakeSocialInteractionRepository social =
        FakeSocialInteractionRepository();
    await _pump(tester, saved: _mixedRepository(), social: social);
    expect(_item(SavedContentType.post, 105), findsOneWidget);

    await tester.tap(_unsaveButton(SavedContentType.post, 105));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsNothing);
    expect(_item(SavedContentType.post, 101), findsOneWidget);
    expect(social.unsaved, hasLength(1));
    expect(social.unsaved.single.contentType, 'post');
    expect(social.unsaved.single.objectId, 105);
  });

  testWidgets('a failed unsave keeps the row and tells the user', (
    WidgetTester tester,
  ) async {
    final FakeSocialInteractionRepository social =
        FakeSocialInteractionRepository()..fail = true;
    await _pump(tester, saved: _mixedRepository(), social: social);

    await tester.tap(_unsaveButton(SavedContentType.post, 105));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(
      find.text("Couldn't remove it from saved. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('every tab has its own empty message', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      saved: FakeSavedRepository(<List<SavedItem>>[<SavedItem>[]]),
      social: FakeSocialInteractionRepository(),
    );

    expect(find.byKey(SavedScreen.emptyKey(SavedContentType.post)), findsOneWidget);
    expect(
      find.text('No saved posts yet. Tap the bookmark on a post to keep it here.'),
      findsOneWidget,
    );

    await _selectTab(tester, SavedContentType.reel);
    expect(find.byKey(SavedScreen.emptyKey(SavedContentType.reel)), findsOneWidget);
    expect(
      find.text('No saved reels yet. Tap the bookmark on a reel to keep it here.'),
      findsOneWidget,
    );

    await _selectTab(tester, SavedContentType.product);
    expect(
      find.byKey(SavedScreen.emptyKey(SavedContentType.product)),
      findsOneWidget,
    );
    expect(
      find.text(
        'No saved products yet. Tap the bookmark on a product to keep it here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed first load shows Retry and Retry reloads', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = _mixedRepository()
      ..failNext = StateError('offline');
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(_item(SavedContentType.post, 105), findsOneWidget);
  });

  testWidgets('pages are loaded automatically while a tab is short', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = FakeSavedRepository(<List<SavedItem>>[
      <SavedItem>[savedTestItem(2, SavedContentType.post, objectId: 102)],
      <SavedItem>[savedTestItem(1, SavedContentType.product, objectId: 301)],
    ]);
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    // The Posts tab has one row (< minRowsPerTab) and the server has more.
    expect(saved.requestedCursors, <String?>[null, '1']);

    await _selectTab(tester, SavedContentType.product);
    expect(_item(SavedContentType.product, 301), findsOneWidget);
  });

  testWidgets('a failed page load shows a retry row and does not loop', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = FakeSavedRepository(<List<SavedItem>>[
      <SavedItem>[savedTestItem(2, SavedContentType.post, objectId: 102)],
      <SavedItem>[savedTestItem(1, SavedContentType.post, objectId: 101)],
    ])..failOnCursor = '1';
    await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );

    // The automatic page load failed once and was NOT retried in a loop.
    expect(saved.requestedCursors, <String?>[null, '1']);
    expect(_item(SavedContentType.post, 102), findsOneWidget);
    expect(find.byKey(SavedScreen.retryMoreKey), findsOneWidget);
    expect(find.text("Couldn't load more saved items."), findsOneWidget);

    saved.failOnCursor = null;
    await tester.tap(find.byKey(SavedScreen.retryMoreKey));
    await tester.pumpAndSettle();

    expect(saved.requestedCursors, <String?>[null, '1', '1']);
    expect(_item(SavedContentType.post, 101), findsOneWidget);
    expect(find.byKey(SavedScreen.retryMoreKey), findsNothing);
  });

  testWidgets('the list is refreshed when the tab becomes active again', (
    WidgetTester tester,
  ) async {
    final FakeSavedRepository saved = _mixedRepository();
    final ValueNotifier<bool> tabActive = await _pump(
      tester,
      saved: saved,
      social: FakeSocialInteractionRepository(),
    );
    expect(saved.requestedCursors, <String?>[null]);

    // Another tab is shown: no request.
    tabActive.value = false;
    await tester.pumpAndSettle();
    expect(saved.requestedCursors, <String?>[null]);

    // The Saved tab is shown again: one silent refresh.
    saved.pages
      ..clear()
      ..add(<SavedItem>[
        savedTestItem(9, SavedContentType.post, objectId: 909, text: 'Fresh save'),
      ]);
    tabActive.value = true;
    await tester.pumpAndSettle();

    expect(saved.requestedCursors, <String?>[null, null]);
    expect(find.text('Fresh save'), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsNothing);
  });

  testWidgets('works in Arabic', (WidgetTester tester) async {
    await _pump(
      tester,
      saved: _mixedRepository(),
      social: FakeSocialInteractionRepository(),
      locale: const Locale('ar'),
    );

    expect(find.text(_arPosts), findsOneWidget);
    expect(find.text(_arProducts), findsOneWidget);
    expect(_item(SavedContentType.post, 105), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(SavedScreen.tabBarKey))),
      TextDirection.rtl,
    );
  });
}
'@ }
)

# ---------------------------------------------------------------
# 1. Second preflight: never overwrite a file that is not ours
# ---------------------------------------------------------------
if (-not $arbAlreadyDone) {
    $newKeys = @()
    foreach ($m in [regex]::Matches($arbEn, '(?m)^  "(saved[A-Za-z0-9]+)":')) {
        $newKeys += $m.Groups[1].Value
    }
    $clashes = @()
    foreach ($k in $newKeys) {
        if ($enText.Contains('"' + $k + '"') -or $arText.Contains('"' + $k + '"')) { $clashes += $k }
    }
    if ($clashes.Count -gt 0) {
        throw ("These ARB keys already exist, so the new keys would collide: " + ($clashes -join ', ') + ". Nothing was changed.")
    }
}

foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    if ((Test-Path -LiteralPath $target) -and (-not $s.Replaces) -and (-not $Force)) {
        $existing = Read-Text $target
        if (-not $existing.Contains('STEP 3B')) {
            throw "$($s.Path) already exists and is not a STEP 3B file. Nothing was changed. Use -Force to overwrite it."
        }
    }
}

# ---------------------------------------------------------------
# 2. Backup of every file that will be overwritten or patched
# ---------------------------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path (Split-Path -Parent $root) ("_p113_step3b_backup_" + $stamp)
$backedUp = @()

function Backup-File([string]$fullPath) {
    if (-not (Test-Path -LiteralPath $fullPath)) { return }
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    $dest = Join-Path $backupRoot $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $fullPath -Destination $dest -Force
    $script:backedUp += $rel
}

foreach ($s in $sources) { Backup-File (Join-Path $root $s.Path) }
if (-not $arbAlreadyDone) {
    Backup-File $enPath
    Backup-File $arPath
}

# ---------------------------------------------------------------
# 3. Write the Dart files
# ---------------------------------------------------------------
$created = @()
$replaced = @()
foreach ($s in $sources) {
    $target = Join-Path $root $s.Path
    $existed = Test-Path -LiteralPath $target
    Save-Text $target $s.Content
    if ($existed) { $replaced += $s.Path } else { $created += $s.Path }
    Write-Host ("  wrote " + $s.Path)
}

# ---------------------------------------------------------------
# 4. ARB files: append the new keys at the very end, change nothing else
# ---------------------------------------------------------------
function Add-ArbEntries([string]$path, [string]$entries) {
    $text = Read-Text $path
    $nl = "`n"
    if ($text.Contains("`r`n")) { $nl = "`r`n" }

    $trimmed = $text.TrimEnd()
    if (-not $trimmed.EndsWith('}')) {
        throw "$path does not end with '}', refusing to patch it."
    }
    $body = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
    if ($body.EndsWith(',')) {
        throw "$path has a trailing comma before the closing brace, refusing to patch it."
    }

    $block = $entries -replace "`r`n", "`n"
    $block = $block.TrimEnd() -replace "`n", $nl
    $patched = $body + ',' + $nl + $block + $nl + '}' + $nl

    # The result must still be valid JSON before it is written.
    try { $null = $patched | ConvertFrom-Json } catch {
        throw "Patched $path is not valid JSON, nothing was written to it: $($_.Exception.Message)"
    }
    [System.IO.File]::WriteAllText($path, $patched, $utf8NoBom)
}

$arbPatched = @()
if ($arbAlreadyDone) {
    Write-Host '  ARB keys already present, skipped.'
} else {
    Add-ArbEntries $enPath $arbEn
    Add-ArbEntries $arPath $arbAr
    $arbPatched += 'lib\l10n\app_en.arb'
    $arbPatched += 'lib\l10n\app_ar.arb'
    Write-Host '  appended saved keys to app_en.arb and app_ar.arb'
}

# ---------------------------------------------------------------
# 5. Regenerate AppLocalizations (committed generated files)
# ---------------------------------------------------------------
$genStatus = 'skipped (-SkipGenL10n)'
if (-not $SkipGenL10n) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $genStatus = 'NOT RUN: flutter is not on PATH'
        Write-Warning 'flutter is not on PATH. Run "flutter gen-l10n" yourself from the project folder.'
    } else {
        # Windows PowerShell 5.1 turns any stderr line of a native command into
        # a terminating error when ErrorActionPreference is 'Stop', so relax it
        # for this one call and judge by the exit code instead.
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        Push-Location $root
        try {
            & flutter gen-l10n
            $genExit = $LASTEXITCODE
        } finally {
            Pop-Location
            $ErrorActionPreference = $previousPreference
        }
        if ($genExit -ne 0) { throw "flutter gen-l10n failed with exit code $genExit" }
        $gen = Read-Text (Join-Path $root 'lib\l10n\app_localizations.dart')
        if (-not $gen.Contains('savedTabPosts')) {
            throw 'flutter gen-l10n finished but app_localizations.dart has no savedTabPosts. Check l10n.yaml.'
        }
        $genStatus = 'done (lib\l10n\app_localizations*.dart regenerated)'
    }
}

# ---------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------
Write-Host ''
Write-Host '================ P-113 STEP 3 / PART B - done ================'
Write-Host 'Created:'
foreach ($p in $created) { Write-Host ("  + " + $p) }
Write-Host 'Replaced (STEP 1 placeholder or a previous run of this step):'
foreach ($p in $replaced) { Write-Host ("  ~ " + $p) }
Write-Host 'Patched (new keys appended at the end only):'
foreach ($p in $arbPatched) { Write-Host ("  ~ " + $p) }
Write-Host ("gen-l10n: " + $genStatus)
if ($backedUp.Count -gt 0) { Write-Host ("Backup of replaced files: " + $backupRoot) }
Write-Host ''
Write-Host 'Next, from the project folder:'
Write-Host '  flutter analyze'
Write-Host '  flutter test test\features\saved test\features\profile_hub test\l10n test\routing test\core\shell'