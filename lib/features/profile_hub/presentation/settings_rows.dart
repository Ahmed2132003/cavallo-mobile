import 'package:flutter/material.dart';

import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/navigation_manifest.dart';

/// Part P-113 (STEP 3A): the building blocks of the Profile & Settings hub.
///
/// Presentation only: no routing, no providers. The hub screen decides which
/// rows exist and what a tap does.

/// The ids of the destinations the navigation manifest shows as a hub row for
/// [audience] (entries of kind `NavEntryKind.profileHubRow`).
///
/// The manifest is the single source of truth for navigation visibility, so
/// the hub renders a row only when its id is in this set, and a test fails if
/// the manifest lists a hub row the hub does not draw.
Set<String> hubRowIdsFor(NavAudience audience) {
  final Set<String> ids = <String>{};
  for (final NavDestination destination in kNavigationManifest) {
    final List<NavEntry> entries =
        destination.entries[audience] ?? const <NavEntry>[];
    for (final NavEntry entry in entries) {
      if (entry.kind == NavEntryKind.profileHubRow) {
        ids.add(destination.id);
      }
    }
  }
  return ids;
}

/// A titled block of rows on a surface card, with hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, this.title, super.key});

  /// Small caption above the card. Null draws no caption.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: colors.outline));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
            child: Text(
              title!,
              style: text.titleSmall?.copyWith(color: colors.textSecondary),
            ),
          )
        else
          const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.symmetric(
              horizontal: BorderSide(color: colors.outline),
            ),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// One tappable row: icon, title, optional subtitle and trailing widget.
///
/// With an [onTap] and no [trailing], a chevron that points the right way in
/// both directions is drawn. [destructive] paints the row in the danger colour
/// (Log out).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color tint = destructive ? colors.dangerText : colors.textPrimary;

    Widget? end = trailing;
    if (end == null && onTap != null) {
      end = DirectionalIcon(Icons.chevron_right, color: colors.textSecondary);
    }

    return ListTile(
      leading: Icon(icon, color: destructive ? colors.dangerText : null),
      title: Text(title, style: TextStyle(color: tint)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: end,
      onTap: onTap,
    );
  }
}

/// A row whose control lives under the title (Appearance, Language): icon and
/// title on the first line, the [child] selector below, full width.
class SettingsSelectorRow extends StatelessWidget {
  const SettingsSelectorRow({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: text.bodyLarge)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
