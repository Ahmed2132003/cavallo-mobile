import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_reporting.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/featured_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/navigation_manifest.dart';
import '../../../routing/route_names.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/domain/business_profile_entity.dart';
import '../../business_profile/presentation/business_profile_provider.dart';
import '../../moderation/domain/queue_item_entity.dart';
import '../../moderation/presentation/moderation_provider.dart';
import 'appearance_selector.dart';
import 'business_shortcuts.dart';
import 'language_selector.dart';
import 'settings_rows.dart';

/// Part P-113 (STEP 3A): the BUSINESS profile of the signed-in Business
/// account, or null (not a Business account, still loading, or no profile).
///
/// A thin derived provider so the hub does not care how the profile is
/// fetched, and so tests can replace it with a plain value.
final hubBusinessProfileProvider = Provider.autoDispose<BusinessProfile?>((
  Ref ref,
) {
  final AsyncValue<BusinessProfile?> profile = ref.watch(
    businessProfileProvider,
  );
  return switch (profile) {
    AsyncData(:final value) => value,
    _ => null,
  };
});

/// Part P-113 (STEP 3A): how many items wait in the moderation queue.
///
/// Derived from the existing `moderationQueueProvider` (which already returns
/// only pending items). No new request and no polling is added: the count is
/// whatever that provider holds, and it is 0 while loading or on error.
final hubModerationPendingCountProvider = Provider.autoDispose<int>((Ref ref) {
  final AsyncValue<List<QueueItem>> queue = ref.watch(
    moderationQueueProvider,
  );
  return switch (queue) {
    AsyncData(:final value) => value.length,
    _ => 0,
  };
});

/// Part P-113 (STEP 3A): the Profile & Settings hub, tab 5 of the app shell.
///
/// Layout: a header (avatar, name or email, account-type chip), then grouped
/// rows in this order: Saved, Notification preferences, Appearance, Language,
/// Business tools (Business accounts), Moderation (Staff accounts, with the
/// pending count), About, Log out.
///
/// ## The manifest decides which rows exist
///
/// A row is drawn only when `hubRowIdsFor(audience)` (the
/// `NavEntryKind.profileHubRow` entries of the navigation manifest) contains
/// its id. The hub never shows a row the manifest does not list for that
/// account type, and `profile_hub_screen_test.dart` fails if the manifest
/// lists a hub row this screen does not draw. Two rows are NOT manifest
/// destinations and are drawn without a manifest entry: "Featured status"
/// (display only, Business accounts) and "About" (a dialog, not a route).
///
/// ## What it does NOT do
///
/// * It does not decide who may open a route. Account-type gating stays in the
///   router `redirect`; hiding a row is only a convenience on top of it.
/// * It adds no polling and no new request. It reads the existing session,
///   business profile and moderation queue providers.
/// * Saved and Moderation are tabs of the shell, so their rows switch tab
///   (`goNamed`). Every other row opens its screen above the shell
///   (`pushNamed`), so back returns to the hub.
class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  /// Key of the row of destination [id] (a manifest id).
  static Key rowKey(String id) => Key('hub-row-$id');

  /// Id and key of the "About" row (not a manifest destination).
  static const String aboutId = 'about';

  static const Key headerKey = Key('hub-header');
  static const Key accountTypeChipKey = Key('hub-account-type');
  static const Key featuredStatusKey = Key('hub-featured-status');
  static const Key moderationBadgeKey = Key('hub-moderation-badge');
  static const Key logoutDialogKey = Key('hub-logout-dialog');
  static const Key logoutCancelKey = Key('hub-logout-cancel');
  static const Key logoutConfirmKey = Key('hub-logout-confirm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;

    final AsyncValue<User?> session = ref.watch(sessionProvider);
    final User? user = switch (session) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (user == null) {
      // A login or logout is in flight; the router redirect is about to move
      // the user. Draw an empty page instead of guessing a layout.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.hubTitle)),
        body: const SizedBox.shrink(),
      );
    }

    final NavAudience audience = navAudienceForUser(user);
    final Set<String> ids = hubRowIdsFor(audience);
    final BusinessProfile? business =
        audience == NavAudience.business
            ? ref.watch(hubBusinessProfileProvider)
            : null;
    final int pendingCount =
        audience == NavAudience.staff
            ? ref.watch(hubModerationPendingCountProvider)
            : 0;

    Widget navRow(
      String id,
      IconData icon,
      String title,
      VoidCallback onTap, {
      Widget? trailing,
    }) {
      return SettingsRow(
        key: rowKey(id),
        icon: icon,
        title: title,
        trailing: trailing,
        onTap: onTap,
      );
    }

    final List<Widget> libraryRows = <Widget>[
      if (ids.contains(RouteNames.saved))
        navRow(
          RouteNames.saved,
          Icons.bookmark_border,
          l10n.hubSaved,
          () => context.goNamed(RouteNames.saved),
        ),
      if (ids.contains(RouteNames.notificationPreferences))
        navRow(
          RouteNames.notificationPreferences,
          Icons.notifications_none,
          l10n.hubNotificationPreferences,
          () => context.pushNamed(RouteNames.notificationPreferences),
        ),
    ];

    final List<Widget> settingsRows = <Widget>[
      if (ids.contains(kNavAppearanceId))
        SettingsSelectorRow(
          key: rowKey(kNavAppearanceId),
          icon: Icons.brightness_6_outlined,
          title: l10n.hubAppearance,
          child: const AppearanceSelector(),
        ),
      if (ids.contains(kNavLanguageId))
        SettingsSelectorRow(
          key: rowKey(kNavLanguageId),
          icon: Icons.language,
          title: l10n.hubLanguage,
          child: const LanguageSelector(),
        ),
    ];

    final List<Widget> businessRows = <Widget>[
      if (ids.contains(RouteNames.businessConsole))
        navRow(
          RouteNames.businessConsole,
          Icons.dashboard_outlined,
          l10n.hubBusinessConsole,
          () => context.pushNamed(RouteNames.businessConsole),
        ),
      if (ids.contains(RouteNames.businessProfileEdit))
        navRow(
          RouteNames.businessProfileEdit,
          Icons.storefront_outlined,
          l10n.hubEditBusinessProfile,
          () => context.pushNamed(RouteNames.businessProfileEdit),
        ),
      if (ids.contains(RouteNames.productList))
        navRow(
          RouteNames.productList,
          Icons.inventory_2_outlined,
          l10n.hubProducts,
          () => context.pushNamed(RouteNames.productList),
        ),
      if (ids.contains(RouteNames.contentList))
        navRow(
          RouteNames.contentList,
          Icons.photo_library_outlined,
          l10n.hubContent,
          () => context.pushNamed(RouteNames.contentList),
        ),
      if (ids.contains(RouteNames.storyList))
        navRow(
          RouteNames.storyList,
          Icons.auto_stories_outlined,
          l10n.hubStories,
          () => context.pushNamed(RouteNames.storyList),
        ),
      if (ids.contains(RouteNames.businessAnalytics))
        navRow(
          RouteNames.businessAnalytics,
          Icons.insights_outlined,
          l10n.hubAnalytics,
          () => context.pushNamed(RouteNames.businessAnalytics),
        ),
      // Display only (ADR-006): Featured is bought on the Web Dashboard, never
      // inside this app, so this row has no tap action.
      if (audience == NavAudience.business && business != null)
        SettingsRow(
          key: featuredStatusKey,
          icon: Icons.star_outline,
          title: l10n.hubFeaturedStatus,
          trailing:
              business.isFeatured
                  ? const FeaturedBadge()
                  : Text(
                    l10n.hubFeaturedNo,
                    style: TextStyle(color: colors.textSecondary),
                  ),
        ),
    ];

    final List<Widget> moderationRows = <Widget>[
      if (ids.contains(RouteNames.moderation))
        navRow(
          RouteNames.moderation,
          Icons.shield_outlined,
          l10n.hubModerationQueue,
          () => context.goNamed(RouteNames.moderation),
          trailing: _ModerationTrailing(count: pendingCount),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hubTitle)),
      body: ListView(
        children: <Widget>[
          _HubHeader(user: user, audience: audience, business: business),
          if (audience == NavAudience.business) const BusinessShortcuts(),
          if (libraryRows.isNotEmpty) SettingsGroup(children: libraryRows),
          if (settingsRows.isNotEmpty)
            SettingsGroup(title: l10n.hubSettingsGroup, children: settingsRows),
          if (businessRows.isNotEmpty)
            SettingsGroup(
              title: l10n.hubBusinessTools,
              children: businessRows,
            ),
          if (moderationRows.isNotEmpty)
            SettingsGroup(title: l10n.hubModeration, children: moderationRows),
          SettingsGroup(
            children: <Widget>[
              SettingsRow(
                key: rowKey(aboutId),
                icon: Icons.info_outline,
                title: l10n.hubAbout,
                onTap:
                    () => showAboutDialog(
                      context: context,
                      applicationName: l10n.appTitle,
                    ),
              ),
            ],
          ),
          if (ids.contains(kNavLogoutId))
            SettingsGroup(
              children: <Widget>[
                SettingsRow(
                  key: rowKey(kNavLogoutId),
                  icon: Icons.logout,
                  title: l10n.hubLogOut,
                  destructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Asks for confirmation, then signs out through the session provider. The
  /// router redirect moves the user to the login screen as soon as the session
  /// becomes empty. A failing server call is reported, never shown: the local
  /// session is cleared either way (see `SessionNotifier.logout`).
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            key: logoutDialogKey,
            title: Text(l10n.hubLogOutConfirmTitle),
            content: Text(l10n.hubLogOutConfirmMessage),
            actions: <Widget>[
              TextButton(
                key: logoutCancelKey,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.hubCancel),
              ),
              TextButton(
                key: logoutConfirmKey,
                style: TextButton.styleFrom(
                  foregroundColor: dialogContext.appColors.dangerText,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.hubLogOut),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (error, stack) {
      reportError(error, stack);
    }
  }
}

/// Header of the hub: avatar, name (the business name for a Business account,
/// otherwise the email), the email under a business name, and the account-type
/// chip.
class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.user,
    required this.audience,
    required this.business,
  });

  final User user;
  final NavAudience audience;
  final BusinessProfile? business;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final String? businessName = business?.businessName;
    final String title =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName
            : user.email;
    final bool showEmailLine = title != user.email;

    final String typeLabel = switch (audience) {
      NavAudience.customer => l10n.hubAccountTypeCustomer,
      NavAudience.business => l10n.hubAccountTypeBusiness,
      NavAudience.staff => l10n.hubAccountTypeStaff,
    };

    return Padding(
      key: ProfileHubScreen.headerKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Row(
        children: <Widget>[
          AppAvatar(name: title, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showEmailLine)
                  Text(
                    user.email,
                    style: text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Container(
                  key: ProfileHubScreen.accountTypeChipKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(typeLabel, style: text.labelMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing part of the Moderation row: the pending count in a brand-blue
/// badge (only when above zero), then the direction-aware chevron.
class _ModerationTrailing extends StatelessWidget {
  const _ModerationTrailing({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final AppFormatters formatters = AppFormatters(context.l10n);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (count > 0) ...<Widget>[
          Badge(
            key: ProfileHubScreen.moderationBadgeKey,
            backgroundColor: colors.brand,
            textColor: colors.onBrand,
            label: Text(formatters.compactCount(count)),
          ),
          const SizedBox(width: 8),
        ],
        DirectionalIcon(Icons.chevron_right, color: colors.textSecondary),
      ],
    );
  }
}
