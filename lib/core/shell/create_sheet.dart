import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../routing/route_names.dart';
import '../l10n/l10n_context.dart';

/// Part P-113 (STEP 4A): the Business "+" create sheet.
///
/// Four options, each routing to a form that already exists:
/// Post ([RouteNames.postForm]), Reel ([RouteNames.reelForm]),
/// Story ([RouteNames.storyForm]) and Product ([RouteNames.productForm],
/// create mode: no `extra`).
///
/// The sheet itself never navigates. It pops with the chosen route name and
/// [showCreateSheet] pushes it afterwards, using the router captured BEFORE
/// the sheet opened, so nothing depends on a context that was just popped.
/// The forms are top-level routes, so they open above the shell and back
/// returns to the tab the user was on.
///
/// Who may open these forms is still decided by the router redirect guards,
/// not by this sheet. The sheet is only reachable from the Business "+" tab.
class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  static const Key titleKey = Key('create-sheet-title');

  /// Key of the option that opens [routeName].
  static Key optionKey(String routeName) => Key('create-sheet-$routeName');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    Widget option(String routeName, IconData icon, String label) {
      return ListTile(
        key: optionKey(routeName),
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(routeName),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Text(
              l10n.createSheetTitle,
              key: titleKey,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          option(RouteNames.postForm, Icons.image_outlined, l10n.createSheetPost),
          option(
            RouteNames.reelForm,
            Icons.play_circle_outline,
            l10n.createSheetReel,
          ),
          option(
            RouteNames.storyForm,
            Icons.auto_stories_outlined,
            l10n.createSheetStory,
          ),
          option(
            RouteNames.productForm,
            Icons.inventory_2_outlined,
            l10n.createSheetProduct,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Opens the create sheet and, if an option was chosen, pushes its form.
Future<void> showCreateSheet(BuildContext context) async {
  final GoRouter router = GoRouter.of(context);
  final String? routeName = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const CreateSheet(),
  );
  if (routeName != null) {
    router.pushNamed(routeName);
  }
}
