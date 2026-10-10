import 'package:flutter/material.dart';

import 'cavallo_logo.dart';

/// A drop-in replacement for [AppBar] that also shows the Cavallo logo.
///
/// Every screen of the app builds this instead of a plain [AppBar], so no
/// screen is without the logo. It takes the same arguments the app's screens
/// already pass to [AppBar] and hands them to a real [AppBar] unchanged, so
/// the title, the back button, the bottom tab bar, the height and every theme
/// value stay exactly as they were.
///
/// ## Where the logo goes
/// The logo is added as the FIRST entry of `actions`: it sits next to the
/// title, and the screen's own action icons keep their place at the end of
/// the bar. In Arabic (RTL) the bar mirrors like any other [AppBar].
///
/// The Home tab does not use this widget: `HomeTopBar` already shows the logo
/// at the start of its bar.
///
/// A test (`cavallo_app_bar_test.dart`) fails if any screen builds a plain
/// [AppBar] again.
class CavalloAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CavalloAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.bottom,
    this.titleSpacing,
    this.centerTitle,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;
  final bool? centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final List<Widget> screenActions = actions ?? const <Widget>[];
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title,
      titleSpacing: titleSpacing,
      centerTitle: centerTitle,
      bottom: bottom,
      actions: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: 8,
            end: screenActions.isEmpty ? 16 : 4,
          ),
          child: const CavalloLogo(),
        ),
        ...screenActions,
      ],
    );
  }
}
