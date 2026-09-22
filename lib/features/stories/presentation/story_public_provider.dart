import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/story_public_repository.dart';
import '../domain/public_story_entity.dart';

/// Part P-050 scope: the first page of one business's currently-visible
/// (published, not-yet-expired) Stories -- `GET
/// /api/v1/stories/public/?business_id=...` (`StoryPublicListView`,
/// Part P-048). Same "first page only, no load-more UI, autoDispose +
/// disabled retry" scope decision as `businessPostsProvider`/
/// `businessReelsProvider` (`content_public_providers.dart`, Part
/// P-045):
///
/// * `AsyncLoading` -- request in flight.
/// * `AsyncData([])` -- a real, renderable state: the business has no
///   currently-visible Stories right now (none created, or all
///   expired). `StoryRingWidget` (this part, next step) simply doesn't
///   render for a business whose list here is empty -- this is NOT an
///   error.
/// * `AsyncData(non-empty)` -- the sequence `StoryViewerScreen` (this
///   part, later step) plays through, in the order the backend
///   returns them (most-recent-first, `StandardCursorPagination`'s
///   default ordering).
/// * `AsyncError` -- a genuine failure; a caller shows `ErrorStateWidget`
///   with Retry.
final businessStoriesProvider = FutureProvider.autoDispose
    .family<List<PublicStory>, int>((ref, businessId) async {
      final page = await ref
          .watch(storyPublicRepositoryProvider)
          .fetchBusinessStories(businessId);
      return page.results;
    }, retry: (retryCount, error) => null);

/// Part P-050 scope: which of one business's Stories THIS device has
/// already viewed during the current app session -- purely local,
/// in-memory bookkeeping for `StoryRingWidget`'s "has unviewed
/// stories" vs. "all viewed" ring styling. Matches the master plan's
/// own spec verbatim: "a simple local `Set` of viewed story ids held
/// in a screen-scoped provider is fine for MVP, don't over-engineer
/// persistent viewed-tracking across app sessions."
///
/// `StateProvider` (via `package:flutter_riverpod/legacy.dart`) is
/// used HERE ON PURPOSE -- the one and only use of the legacy Riverpod
/// API anywhere in this app (every other provider in this codebase is
/// a plain `AsyncNotifierProvider`/`FutureProvider`, no code-gen). A
/// hand-written `Notifier`/`FamilyNotifier` class for nothing more
/// than "hold a mutable set of ints" would itself be exactly the
/// over-engineering the spec line above explicitly warns against --
/// `StateProvider` is Riverpod's own purpose-built tool for precisely
/// this shape of state, and its move to `legacy.dart` in
/// `flutter_riverpod: 3.3.2` (this project's pinned version, confirmed
/// via a real `flutter analyze` failure on the real machine) is a
/// packaging change, not a deprecation of the type itself.
///
/// NOTE: deliberately a DIFFERENT, NARROWER concern from the
/// architecture-Section-13-protected timer/progress state
/// `StoryViewerScreen` owns (this part, later step). That state is
/// scoped to a single viewing session and must never leak into ANY
/// provider outside the viewer's own widget tree, full stop -- this
/// provider is not that: it is a per-business set of already-seen
/// story ids, kept only long enough to style a ring while it's on
/// screen, and `autoDispose` means it's discarded -- not persisted
/// anywhere, not even across the ring being scrolled off and back on
/// screen in the same session -- the instant nothing is watching this
/// business's ring anymore. Reopening it later starts with an empty
/// set again, exactly as the spec's "don't over-engineer persistent
/// tracking" instruction requires.
///
/// `StoryViewerScreen` adds a story's id to this set as it comes into
/// view -- see that screen's own doc (a later step) for exactly when.
final viewedStoriesProvider = StateProvider.autoDispose
    .family<Set<int>, int>((ref, businessId) => <int>{});