import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_provider.dart';

/// Part P-113 (STEP 4B): the id of the signed-in user's OWN business, or null.
///
/// Null when nobody is signed in, when the account is not a Business account,
/// or while the own profile is loading, missing or failed. It is derived from
/// the two providers that already exist ([sessionProvider] and
/// [businessProfileProvider]); it adds no request and no polling.
///
/// The public Business profile uses it to decide whether to show the owner's
/// Edit button. It never grants access: the route behind the button is still
/// protected by the router redirect guards.
final ownBusinessIdProvider = Provider.autoDispose<int?>((Ref ref) {
  final AsyncValue<User?> session = ref.watch(sessionProvider);
  final User? user = switch (session) {
    AsyncData(:final value) => value,
    _ => null,
  };
  if (user == null || user.accountType != AccountType.business) {
    return null;
  }

  final AsyncValue<BusinessProfile?> profile = ref.watch(
    businessProfileProvider,
  );
  return switch (profile) {
    AsyncData(:final value) => value?.id,
    _ => null,
  };
});
