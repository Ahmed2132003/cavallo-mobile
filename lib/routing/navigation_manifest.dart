import '../features/auth/domain/user_entity.dart';
import 'route_names.dart';

/// Part P-113 (STEP 1): the navigation manifest.
///
/// ONE const data structure that answers, for every destination of the app
/// and for every account type, "which VISIBLE entry points open this?".
/// It is the single source of truth for navigation visibility:
///
/// * STEP 2 builds the bottom bar from it ([bottomTabsFor]).
/// * STEP 3 builds the Profile & Settings hub from its `profileHubRow`
///   entries, STEP 4 builds the create sheet from its `createSheet` entries.
/// * `test/routing/navigation_reachability_test.dart` reads it to prove that
///   no screen is reachable only by accident (no debug menu, no hidden path).
///
/// ## What the manifest is NOT
///
/// It never grants or removes access. Account-type gating stays in the
/// router `redirect` callback in `app_router.dart` (untouched by P-113).
/// `allowedFor` documents who the redirect lets in; the reachability test
/// then forces every allowed audience to have a visible way to get there.
///
/// ## Adding a route later (handoff rule)
///
/// A new `GoRoute` with a `name` that is not listed here makes the
/// reachability test fail. Add a [NavDestination] for it in the same commit.
///
/// ## Account types ("audiences")
///
/// Staff = `isModerator || isStaff` and wins over the account type, because
/// the locked P-113 table gives Staff its own bottom bar. See
/// [navAudienceForUser].
enum NavAudience { customer, business, staff }

/// How a destination is made visible to the user.
enum NavEntryKind {
  /// One of the five bottom-bar slots.
  bottomTab,

  /// An icon in the Home top bar (bell, chats).
  topBarAction,

  /// A row in the Profile & Settings hub.
  profileHubRow,

  /// An item of the Business "+" create sheet.
  createSheet,

  /// A tap target inside another screen (card, avatar, button, header).
  inContextLink,

  /// Not visible anywhere on purpose. Needs a documented reason and never
  /// counts as an entry point for the reachability test.
  deepLinkOnly,
}

class NavEntry {
  const NavEntry(this.kind, this.where, {this.tabSlot, this.reason});

  final NavEntryKind kind;

  /// Human description of the exact place (used in the walk-through).
  final String where;

  /// 1..5, only for [NavEntryKind.bottomTab].
  final int? tabSlot;

  /// Required for [NavEntryKind.deepLinkOnly].
  final String? reason;
}

class NavDestination {
  const NavDestination({
    required this.id,
    required this.allowedFor,
    required this.entries,
    this.routeName,
    this.authFlowReason,
  });

  /// Stable identifier. Equals [routeName] for real routes; for things that
  /// are not routes (create sheet, theme/language selectors, log out) it is
  /// a short descriptive id and [routeName] is null.
  final String id;

  /// The `RouteNames.*` route name, or null for non-route destinations.
  final String? routeName;

  /// Audiences the router lets in. Empty for auth-flow destinations.
  final Set<NavAudience> allowedFor;

  /// Visible entry points per audience.
  final Map<NavAudience, List<NavEntry>> entries;

  /// Non-null (with a reason) for destinations that belong to the auth flow
  /// guarded by the router redirect and are not part of the shell.
  final String? authFlowReason;

  bool get isAuthFlow => authFlowReason != null;
}

/// The audience a signed-in user belongs to. Staff wins over account type.
NavAudience navAudienceForUser(User user) {
  if (user.isModerator || user.isStaff) {
    return NavAudience.staff;
  }
  return switch (user.accountType) {
    AccountType.business => NavAudience.business,
    AccountType.customer => NavAudience.customer,
  };
}

/// Destinations that are not routes (no `GoRoute`). Their ids are used by
/// the shell and hub in later steps.
const String kNavCreateId = 'create';
const String kNavAppearanceId = 'appearance';
const String kNavLanguageId = 'language';
const String kNavLogoutId = 'logout';

const Set<NavAudience> _everyone = {
  NavAudience.customer,
  NavAudience.business,
  NavAudience.staff,
};
const Set<NavAudience> _businessOnly = {NavAudience.business};
const Set<NavAudience> _staffOnly = {NavAudience.staff};

// --- Reusable entry lists -------------------------------------------------

const List<NavEntry> _inContextCards = [
  NavEntry(
    NavEntryKind.inContextLink,
    'Cards in feed, profile tabs, search, saved, notifications, shared chat cards',
  ),
];

const List<NavEntry> _hubRow = [
  NavEntry(NavEntryKind.profileHubRow, 'Profile & Settings hub row'),
];

const List<NavEntry> _homeTab = [
  NavEntry(NavEntryKind.bottomTab, 'Bottom bar, tab 1', tabSlot: 1),
];

const List<NavEntry> _exploreTab = [
  NavEntry(NavEntryKind.bottomTab, 'Bottom bar, tab 2', tabSlot: 2),
];

const List<NavEntry> _chatsTabAndTopBar = [
  NavEntry(NavEntryKind.bottomTab, 'Bottom bar, tab 4', tabSlot: 4),
  NavEntry(NavEntryKind.topBarAction, 'Home top bar, chats icon'),
];

const List<NavEntry> _profileTab = [
  NavEntry(NavEntryKind.bottomTab, 'Bottom bar, tab 5', tabSlot: 5),
];

const List<NavEntry> _consoleHubAndHeader = [
  NavEntry(NavEntryKind.profileHubRow, 'Hub, Business tools group'),
  NavEntry(NavEntryKind.inContextLink, 'Tab 5 header shortcuts'),
];

/// The manifest. Order is irrelevant to behavior; it follows the P-113
/// reachability matrix for readability.
const List<NavDestination> kNavigationManifest = [
  // --- Shell tabs ---------------------------------------------------------
  NavDestination(
    id: RouteNames.home,
    routeName: RouteNames.home,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _homeTab,
      NavAudience.business: _homeTab,
      NavAudience.staff: _homeTab,
    },
  ),
  NavDestination(
    id: RouteNames.discover,
    routeName: RouteNames.discover,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _exploreTab,
      NavAudience.business: _exploreTab,
      NavAudience.staff: _exploreTab,
    },
  ),
  NavDestination(
    id: RouteNames.search,
    routeName: RouteNames.search,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _searchEntries,
      NavAudience.business: _searchEntries,
      NavAudience.staff: _searchEntries,
    },
  ),
  NavDestination(
    id: RouteNames.chatList,
    routeName: RouteNames.chatList,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _chatsTabAndTopBar,
      NavAudience.business: _chatsTabAndTopBar,
      NavAudience.staff: _chatsTabAndTopBar,
    },
  ),
  NavDestination(
    id: RouteNames.profile,
    routeName: RouteNames.profile,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _profileTab,
      NavAudience.business: _profileTab,
      NavAudience.staff: _profileTab,
    },
  ),
  NavDestination(
    id: RouteNames.saved,
    routeName: RouteNames.saved,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: [
        NavEntry(NavEntryKind.bottomTab, 'Bottom bar, tab 3', tabSlot: 3),
        NavEntry(NavEntryKind.profileHubRow, 'Hub row'),
      ],
      NavAudience.business: _hubRow,
      NavAudience.staff: _hubRow,
    },
  ),
  NavDestination(
    id: kNavCreateId,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(
          NavEntryKind.bottomTab,
          'Bottom bar, tab 3 (+), opens the create sheet',
          tabSlot: 3,
        ),
      ],
    },
  ),
  NavDestination(
    id: RouteNames.moderation,
    routeName: RouteNames.moderation,
    allowedFor: _staffOnly,
    entries: {
      NavAudience.staff: [
        NavEntry(
          NavEntryKind.bottomTab,
          'Bottom bar, tab 3 (pending badge)',
          tabSlot: 3,
        ),
        NavEntry(NavEntryKind.profileHubRow, 'Hub, Moderation group'),
      ],
    },
  ),

  // --- Social / content detail screens -----------------------------------
  NavDestination(
    id: RouteNames.businessProfile,
    routeName: RouteNames.businessProfile,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _avatarLinks,
      NavAudience.business: _avatarLinks,
      NavAudience.staff: _avatarLinks,
    },
  ),
  NavDestination(
    id: RouteNames.productDetail,
    routeName: RouteNames.productDetail,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _inContextCards,
      NavAudience.business: _inContextCards,
      NavAudience.staff: _inContextCards,
    },
  ),
  NavDestination(
    id: RouteNames.postDetail,
    routeName: RouteNames.postDetail,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _inContextCards,
      NavAudience.business: _inContextCards,
      NavAudience.staff: _inContextCards,
    },
  ),
  NavDestination(
    id: RouteNames.reelDetail,
    routeName: RouteNames.reelDetail,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _inContextCards,
      NavAudience.business: _inContextCards,
      NavAudience.staff: _inContextCards,
    },
  ),
  NavDestination(
    id: RouteNames.storyViewer,
    routeName: RouteNames.storyViewer,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _storyRings,
      NavAudience.business: _storyRings,
      NavAudience.staff: _storyRings,
    },
  ),
  NavDestination(
    id: RouteNames.chatThread,
    routeName: RouteNames.chatThread,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _threadLinks,
      NavAudience.business: _threadLinks,
      NavAudience.staff: _threadLinks,
    },
  ),

  // --- Notifications ------------------------------------------------------
  NavDestination(
    id: RouteNames.notifications,
    routeName: RouteNames.notifications,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _bellEntries,
      NavAudience.business: _bellEntries,
      NavAudience.staff: _bellEntries,
    },
  ),
  NavDestination(
    id: RouteNames.notificationPreferences,
    routeName: RouteNames.notificationPreferences,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _prefsEntries,
      NavAudience.business: _prefsEntries,
      NavAudience.staff: _prefsEntries,
    },
  ),

  // --- Settings actions that are not routes -------------------------------
  NavDestination(
    id: kNavAppearanceId,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _hubRow,
      NavAudience.business: _hubRow,
      NavAudience.staff: _hubRow,
    },
  ),
  NavDestination(
    id: kNavLanguageId,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _hubRow,
      NavAudience.business: _hubRow,
      NavAudience.staff: _hubRow,
    },
  ),
  NavDestination(
    id: kNavLogoutId,
    allowedFor: _everyone,
    entries: {
      NavAudience.customer: _hubRow,
      NavAudience.business: _hubRow,
      NavAudience.staff: _hubRow,
    },
  ),

  // --- Business only ------------------------------------------------------
  NavDestination(
    id: RouteNames.businessProfileEdit,
    routeName: RouteNames.businessProfileEdit,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(NavEntryKind.profileHubRow, 'Hub, Business tools group'),
        NavEntry(
          NavEntryKind.inContextLink,
          'Edit button on the Business public profile',
        ),
      ],
    },
  ),
  NavDestination(
    id: RouteNames.businessConsole,
    routeName: RouteNames.businessConsole,
    allowedFor: _businessOnly,
    entries: {NavAudience.business: _consoleHubAndHeader},
  ),
  NavDestination(
    id: RouteNames.productList,
    routeName: RouteNames.productList,
    allowedFor: _businessOnly,
    entries: {NavAudience.business: _consoleHubAndHeader},
  ),
  NavDestination(
    id: RouteNames.contentList,
    routeName: RouteNames.contentList,
    allowedFor: _businessOnly,
    entries: {NavAudience.business: _consoleHubAndHeader},
  ),
  NavDestination(
    id: RouteNames.storyList,
    routeName: RouteNames.storyList,
    allowedFor: _businessOnly,
    entries: {NavAudience.business: _consoleHubAndHeader},
  ),
  NavDestination(
    id: RouteNames.businessAnalytics,
    routeName: RouteNames.businessAnalytics,
    allowedFor: _businessOnly,
    entries: {NavAudience.business: _consoleHubAndHeader},
  ),
  NavDestination(
    id: RouteNames.productForm,
    routeName: RouteNames.productForm,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(NavEntryKind.createSheet, 'Create sheet, Product'),
        NavEntry(NavEntryKind.inContextLink, 'Add button in the products list'),
      ],
    },
  ),
  NavDestination(
    id: RouteNames.postForm,
    routeName: RouteNames.postForm,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(NavEntryKind.createSheet, 'Create sheet, Post'),
        NavEntry(NavEntryKind.inContextLink, 'Add button in the content list'),
      ],
    },
  ),
  NavDestination(
    id: RouteNames.reelForm,
    routeName: RouteNames.reelForm,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(NavEntryKind.createSheet, 'Create sheet, Reel'),
        NavEntry(NavEntryKind.inContextLink, 'Add button in the content list'),
      ],
    },
  ),
  NavDestination(
    id: RouteNames.storyForm,
    routeName: RouteNames.storyForm,
    allowedFor: _businessOnly,
    entries: {
      NavAudience.business: [
        NavEntry(NavEntryKind.createSheet, 'Create sheet, Story'),
        NavEntry(NavEntryKind.inContextLink, 'Add button in the stories list'),
      ],
    },
  ),

  // --- Staff only ---------------------------------------------------------
  NavDestination(
    id: RouteNames.moderationReview,
    routeName: RouteNames.moderationReview,
    allowedFor: _staffOnly,
    entries: {
      NavAudience.staff: [
        NavEntry(NavEntryKind.inContextLink, 'Item row in the moderation queue'),
      ],
    },
  ),

  // --- Auth flow (guarded by the router redirect, not part of the shell) ---
  NavDestination(
    id: RouteNames.splash,
    routeName: RouteNames.splash,
    allowedFor: {},
    entries: {},
    authFlowReason:
        'Cold-start route. The redirect sends it to /login or /home.',
  ),
  NavDestination(
    id: RouteNames.login,
    routeName: RouteNames.login,
    allowedFor: {},
    entries: {},
    authFlowReason: 'Signed-out entry. Signed-in users are redirected to /home.',
  ),
  NavDestination(
    id: RouteNames.register,
    routeName: RouteNames.register,
    allowedFor: {},
    entries: {},
    authFlowReason:
        'Signed-out entry, linked from the login screen. Signed-in users are redirected to /home.',
  ),
  NavDestination(
    id: RouteNames.businessOnboarding,
    routeName: RouteNames.businessOnboarding,
    allowedFor: {},
    entries: {},
    authFlowReason:
        'Forced by the redirect for a Business account that has no BusinessProfile yet.',
  ),
];

const List<NavEntry> _searchEntries = [
  NavEntry(NavEntryKind.inContextLink, 'Explore tab search bar'),
  NavEntry(NavEntryKind.inContextLink, 'Search icon in empty states'),
];

const List<NavEntry> _avatarLinks = [
  NavEntry(
    NavEntryKind.inContextLink,
    'Avatar or name in feed, search, story header, chat header, saved, notifications',
  ),
];

const List<NavEntry> _storyRings = [
  NavEntry(
    NavEntryKind.inContextLink,
    'Story rings in the Home tray and in the Explore tab stories bar',
  ),
];

const List<NavEntry> _threadLinks = [
  NavEntry(NavEntryKind.inContextLink, 'Row in the chats list (tab 4)'),
  NavEntry(NavEntryKind.inContextLink, 'Message button on a Business profile'),
  NavEntry(NavEntryKind.inContextLink, 'Chat notification'),
];

const List<NavEntry> _bellEntries = [
  NavEntry(NavEntryKind.topBarAction, 'Home top bar, bell icon'),
];

const List<NavEntry> _prefsEntries = [
  NavEntry(NavEntryKind.profileHubRow, 'Hub row'),
  NavEntry(NavEntryKind.inContextLink, 'Notification center header'),
];

/// The bottom-bar entries of [audience], ordered by slot (1..5).
///
/// Used by the shell in P-113 STEP 3 and by the locked-layout test.
List<MapEntry<NavDestination, NavEntry>> bottomTabsFor(NavAudience audience) {
  final tabs = <MapEntry<NavDestination, NavEntry>>[];
  for (final destination in kNavigationManifest) {
    for (final entry in destination.entries[audience] ?? const <NavEntry>[]) {
      if (entry.kind == NavEntryKind.bottomTab) {
        tabs.add(MapEntry(destination, entry));
      }
    }
  }
  tabs.sort((a, b) => a.value.tabSlot!.compareTo(b.value.tabSlot!));
  return tabs;
}