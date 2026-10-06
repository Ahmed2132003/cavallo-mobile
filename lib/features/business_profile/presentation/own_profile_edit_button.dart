import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../routing/route_names.dart';
import 'own_business_id_provider.dart';

/// Part P-113 (STEP 4B): the owner's Edit action on the public Business
/// profile.
///
/// It is an app bar action. It draws an Edit icon ONLY when [businessId] is
/// the signed-in user's own business ([ownBusinessIdProvider]); for everybody
/// else (customers, staff, other businesses, signed-out, still loading) it
/// draws nothing and takes no space.
///
/// A tap pushes [RouteNames.businessProfileEdit] above the current screen, so
/// back returns to the public profile. Who may open the edit screen is still
/// decided by the router redirect guards, not by this button.
class OwnProfileEditButton extends ConsumerWidget {
  const OwnProfileEditButton({required this.businessId, super.key});

  static const Key buttonKey = Key('own-profile-edit-button');

  /// The business whose public profile is on screen.
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? ownId = ref.watch(ownBusinessIdProvider);
    if (ownId == null || ownId != businessId) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: buttonKey,
      icon: const Icon(Icons.edit_outlined),
      tooltip: context.l10n.hubEditBusinessProfile,
      onPressed: () => context.pushNamed(RouteNames.businessProfileEdit),
    );
  }
}
