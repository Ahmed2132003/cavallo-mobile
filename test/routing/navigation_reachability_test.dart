import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/routing/app_router.dart';
import 'package:social_commerce_app/routing/navigation_manifest.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 1): the reachability test.
///
/// Rules it enforces (see `navigation_manifest.dart`):
///  1. every route named in the manifest exists in the real router;
///  2. no route exists in the router without a manifest decision;
///  3. every audience allowed to open a destination has at least one
///     VISIBLE (non deep-link) entry point to it;
///  4. the five bottom tabs of each audience match the locked P-113 table.
///
/// The checking logic is the pure function [findNavigationProblems] so the
/// "can it fail?" tests at the bottom can feed it broken data.
///
/// Honest scope: this proves the manifest is complete and consistent with
/// the router. That the UI really renders each entry point is proven by the
/// widget tests of later steps and by the manual three-account walk-through.

enum NavProblemKind {
  manifestRouteMissingInRouter,
  routerRouteMissingInManifest,
  noVisibleEntryPoint,
  malformedManifest,
}

class NavProblem {
  const NavProblem(this.kind, this.message);

  final NavProblemKind kind;
  final String message;

  @override
  String toString() => '${kind.name}: $message';
}

List<NavProblem> findNavigationProblems({
  required List<NavDestination> manifest,
  required Set<String> routerRouteNames,
}) {
  final problems = <NavProblem>[];
  final seenIds = <String>{};
  final seenRoutes = <String>{};

  for (final d in manifest) {
    if (!seenIds.add(d.id)) {
      problems.add(
        NavProblem(NavProblemKind.malformedManifest, 'duplicate id "${d.id}"'),
      );
    }

    final route = d.routeName;
    if (route != null) {
      if (!seenRoutes.add(route)) {
        problems.add(
          NavProblem(
            NavProblemKind.malformedManifest,
            'route "$route" listed twice',
          ),
        );
      }
      if (!routerRouteNames.contains(route)) {
        problems.add(
          NavProblem(
            NavProblemKind.manifestRouteMissingInRouter,
            '"${d.id}" names route "$route" but app_router.dart has no such route',
          ),
        );
      }
    }

    if (d.isAuthFlow) {
      if (d.authFlowReason!.trim().isEmpty) {
        problems.add(
          NavProblem(
            NavProblemKind.malformedManifest,
            '"${d.id}" is auth-flow without a reason',
          ),
        );
      }
      if (d.allowedFor.isNotEmpty || d.entries.isNotEmpty) {
        problems.add(
          NavProblem(
            NavProblemKind.malformedManifest,
            '"${d.id}" is auth-flow, so allowedFor and entries must be empty',
          ),
        );
      }
      continue;
    }

    if (d.allowedFor.isEmpty) {
      problems.add(
        NavProblem(
          NavProblemKind.malformedManifest,
          '"${d.id}" is allowed for nobody and is not auth-flow',
        ),
      );
    }

    for (final audience in d.allowedFor) {
      final entries = d.entries[audience] ?? const <NavEntry>[];
      final visible = entries.where(
        (e) => e.kind != NavEntryKind.deepLinkOnly,
      );
      if (visible.isEmpty) {
        problems.add(
          NavProblem(
            NavProblemKind.noVisibleEntryPoint,
            '"${d.id}" has no visible entry point for ${audience.name}',
          ),
        );
      }
    }

    for (final audience in d.entries.keys) {
      if (!d.allowedFor.contains(audience)) {
        problems.add(
          NavProblem(
            NavProblemKind.malformedManifest,
            '"${d.id}" has entries for ${audience.name}, who is not in allowedFor',
          ),
        );
      }
      for (final e in d.entries[audience]!) {
        if (e.kind == NavEntryKind.deepLinkOnly &&
            (e.reason == null || e.reason!.trim().isEmpty)) {
          problems.add(
            NavProblem(
              NavProblemKind.malformedManifest,
              '"${d.id}" has a deep-link-only entry without a reason',
            ),
          );
        }
        if (e.kind == NavEntryKind.bottomTab &&
            (e.tabSlot == null || e.tabSlot! < 1 || e.tabSlot! > 5)) {
          problems.add(
            NavProblem(
              NavProblemKind.malformedManifest,
              '"${d.id}" has a bottom tab without a slot in 1..5',
            ),
          );
        }
      }
    }
  }

  for (final name in routerRouteNames) {
    if (!seenRoutes.contains(name)) {
      problems.add(
        NavProblem(
          NavProblemKind.routerRouteMissingInManifest,
          'router route "$name" has no manifest entry. Add a NavDestination for it.',
        ),
      );
    }
  }

  return problems;
}

/// Collects the `name` of every [GoRoute] in the router, recursively
/// (including the branches of every `StatefulShellRoute`). An unnamed
/// route is reported as `unnamed:<path>` so it can never slip through.
Set<String> collectRouterRouteNames(List<RouteBase> routes) {
  final names = <String>{};
  void walk(List<RouteBase> list) {
    for (final route in list) {
      if (route is GoRoute) {
        names.add(route.name ?? 'unnamed:${route.path}');
      }
      walk(route.routes);
    }
  }

  walk(routes);
  return names;
}

class _FakeSessionNotifier extends SessionNotifier {
  @override
  Future<User?> build() async => null;
}

Iterable<NavProblem> _of(List<NavProblem> all, NavProblemKind kind) =>
    all.where((p) => p.kind == kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> routerNames;

  setUpAll(() async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSessionNotifier()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final router = container.read(appRouterProvider);
    routerNames = collectRouterRouteNames(router.configuration.routes);
  });

  group('navigation manifest vs the real router', () {
    test('every route named in the manifest exists in the router', () {
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: routerNames,
      );
      expect(
        _of(problems, NavProblemKind.manifestRouteMissingInRouter),
        isEmpty,
        reason: 'The manifest lists a route the router does not have.',
      );
    });

    test('no router route exists outside the manifest', () {
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: routerNames,
      );
      expect(
        _of(problems, NavProblemKind.routerRouteMissingInManifest),
        isEmpty,
        reason: 'New routes force a manifest decision.',
      );
    });

    test('every allowed audience has a visible entry point to every route', () {
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: routerNames,
      );
      expect(_of(problems, NavProblemKind.noVisibleEntryPoint), isEmpty);
    });

    test('the manifest itself is well formed', () {
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: routerNames,
      );
      expect(_of(problems, NavProblemKind.malformedManifest), isEmpty);
    });
  });

  group('locked bottom navigation layout', () {
    List<String> idsFor(NavAudience audience) => [
      for (final tab in bottomTabsFor(audience)) tab.key.id,
    ];

    test('Customer: Home, Explore, Saved, Chats, Profile', () {
      expect(idsFor(NavAudience.customer), [
        RouteNames.home,
        RouteNames.discover,
        RouteNames.saved,
        RouteNames.chatList,
        RouteNames.profile,
      ]);
    });

    test('Business: Home, Explore, Create (+), Chats, Profile', () {
      expect(idsFor(NavAudience.business), [
        RouteNames.home,
        RouteNames.discover,
        kNavCreateId,
        RouteNames.chatList,
        RouteNames.profile,
      ]);
    });

    test('Staff: Home, Explore, Moderation, Chats, Profile', () {
      expect(idsFor(NavAudience.staff), [
        RouteNames.home,
        RouteNames.discover,
        RouteNames.moderation,
        RouteNames.chatList,
        RouteNames.profile,
      ]);
    });

    test('slots are exactly 1..5 for every audience', () {
      for (final audience in NavAudience.values) {
        expect([
          for (final tab in bottomTabsFor(audience)) tab.value.tabSlot,
        ], [1, 2, 3, 4, 5], reason: audience.name);
      }
    });
  });

  group('navAudienceForUser', () {
    User user({
      required AccountType type,
      bool moderator = false,
      bool staff = false,
    }) => User(
      id: 1,
      email: 'a@example.com',
      accountType: type,
      isModerator: moderator,
      isStaff: staff,
    );

    test('plain customer and business', () {
      expect(
        navAudienceForUser(user(type: AccountType.customer)),
        NavAudience.customer,
      );
      expect(
        navAudienceForUser(user(type: AccountType.business)),
        NavAudience.business,
      );
    });

    test('moderator or staff wins over the account type', () {
      expect(
        navAudienceForUser(user(type: AccountType.customer, moderator: true)),
        NavAudience.staff,
      );
      expect(
        navAudienceForUser(user(type: AccountType.business, staff: true)),
        NavAudience.staff,
      );
    });
  });

  group('the checker can fail (meta tests)', () {
    Set<String> manifestRoutes() => {
      for (final d in kNavigationManifest)
        if (d.routeName != null) d.routeName!,
    };

    test('a consistent manifest and router produce no problems', () {
      expect(
        findNavigationProblems(
          manifest: kNavigationManifest,
          routerRouteNames: manifestRoutes(),
        ),
        isEmpty,
      );
    });

    test('a route removed from the router is reported', () {
      final names = manifestRoutes()..remove(RouteNames.productList);
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: names,
      );
      expect(
        _of(problems, NavProblemKind.manifestRouteMissingInRouter),
        isNotEmpty,
      );
    });

    test('a route added to the router without the manifest is reported', () {
      final names = manifestRoutes()..add('ghostScreen');
      final problems = findNavigationProblems(
        manifest: kNavigationManifest,
        routerRouteNames: names,
      );
      expect(
        _of(problems, NavProblemKind.routerRouteMissingInManifest).single
            .message,
        contains('ghostScreen'),
      );
    });

    test('an allowed audience with zero entry points is reported', () {
      const broken = NavDestination(
        id: 'broken',
        routeName: 'broken',
        allowedFor: {NavAudience.customer},
        entries: {NavAudience.customer: []},
      );
      final problems = findNavigationProblems(
        manifest: const [broken],
        routerRouteNames: const {'broken'},
      );
      expect(_of(problems, NavProblemKind.noVisibleEntryPoint), hasLength(1));
    });

    test('a deep-link-only entry does not count as visible', () {
      const hidden = NavDestination(
        id: 'hidden',
        routeName: 'hidden',
        allowedFor: {NavAudience.business},
        entries: {
          NavAudience.business: [
            NavEntry(
              NavEntryKind.deepLinkOnly,
              'debug menu',
              reason: 'only reachable from a debug menu',
            ),
          ],
        },
      );
      final problems = findNavigationProblems(
        manifest: const [hidden],
        routerRouteNames: const {'hidden'},
      );
      expect(_of(problems, NavProblemKind.noVisibleEntryPoint), hasLength(1));
    });

    test('a deep-link-only entry without a reason is malformed', () {
      const noReason = NavDestination(
        id: 'noReason',
        routeName: 'noReason',
        allowedFor: {NavAudience.staff},
        entries: {
          NavAudience.staff: [
            NavEntry(NavEntryKind.inContextLink, 'somewhere'),
            NavEntry(NavEntryKind.deepLinkOnly, 'x'),
          ],
        },
      );
      final problems = findNavigationProblems(
        manifest: const [noReason],
        routerRouteNames: const {'noReason'},
      );
      expect(_of(problems, NavProblemKind.malformedManifest), hasLength(1));
    });
  });
}