import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../domain/notification_preferences.dart';
import 'notification_preferences_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-082 (STEP 5): the notification preferences screen.
///
/// Three switches, one per [NotificationCategory]. Each change goes
/// through [NotificationPreferencesNotifier.setEnabled], which flips the
/// switch immediately, sends ONE PATCH for that category only, and puts
/// that category back (then rethrows) if the request fails. This screen
/// only shows a message in that case.
///
/// `system_announcement` has no switch: it is always delivered, and the
/// footer says so.
///
/// Part P-115 (STEP 4): restyle only. The three switches sit in one rounded
/// group with hairline dividers, all colours come from the design tokens and
/// all text from the ARB files. The provider and the toggle logic are
/// unchanged, and each switch keeps its `notification-preference-<name>` key.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  static const List<({NotificationCategory category, IconData icon})> _tiles =
      <({NotificationCategory category, IconData icon})>[
        (category: NotificationCategory.chat, icon: Icons.chat_bubble_outline),
        (
          category: NotificationCategory.moderation,
          icon: Icons.shield_outlined,
        ),
        (category: NotificationCategory.social, icon: Icons.favorite_border),
      ];

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
    bool enabled,
  ) async {
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setEnabled(category, enabled);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.notifPrefsSaveFailed)),
        );
    }
  }

  String _titleFor(
    BuildContext context,
    NotificationCategory category,
  ) => switch (category) {
    NotificationCategory.chat => context.l10n.notifPrefChatTitle,
    NotificationCategory.moderation => context.l10n.notifPrefModerationTitle,
    NotificationCategory.social => context.l10n.notifPrefSocialTitle,
  };

  String _subtitleFor(
    BuildContext context,
    NotificationCategory category,
  ) => switch (category) {
    NotificationCategory.chat => context.l10n.notifPrefChatSubtitle,
    NotificationCategory.moderation => context.l10n.notifPrefModerationSubtitle,
    NotificationCategory.social => context.l10n.notifPrefSocialSubtitle,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final AppColors colors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: CavalloAppBar(title: Text(context.l10n.notifSettingsTitle)),
      body: switch (preferencesAsync) {
        AsyncData(value: final preferences) => ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
              child: Text(
                context.l10n.notifPrefsSectionHeader,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outline),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _tiles.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colors.outline,
                      ),
                    SwitchListTile(
                      key: ValueKey(
                        'notification-preference-${_tiles[i].category.name}',
                      ),
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        16,
                        4,
                      ),
                      secondary: Icon(
                        _tiles[i].icon,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        _titleFor(context, _tiles[i].category),
                        style: (textTheme.titleSmall ?? const TextStyle())
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                      subtitle: Text(
                        _subtitleFor(context, _tiles[i].category),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      value: preferences.isEnabled(_tiles[i].category),
                      onChanged:
                          (value) => unawaited(
                            _toggle(context, ref, _tiles[i].category, value),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
              child: Text(
                context.l10n.notifPrefsSystemFooter,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        AsyncError() => ErrorStateWidget(
          message: context.l10n.notifPrefsLoadFailed,
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        _ => const _PreferencesSkeleton(),
      },
    );
  }
}

/// Skeleton for the preferences group while the server values load.
class _PreferencesSkeleton extends StatelessWidget {
  const _PreferencesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.notifLoadingLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
        children: const [
          AppShimmerBox(height: 72, borderRadius: 16),
          SizedBox(height: 12),
          AppShimmerBox(height: 72, borderRadius: 16),
          SizedBox(height: 12),
          AppShimmerBox(height: 72, borderRadius: 16),
        ],
      ),
    );
  }
}
