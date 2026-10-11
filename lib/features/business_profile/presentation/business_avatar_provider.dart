import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_profile_public_provider.dart';

/// Profile photo URL of the business [id], or `null` while the profile is
/// loading / failed / has no photo (callers then show the initials).
///
/// Derived from [businessProfilePublicProvider], so it shares that provider's
/// fetch and cache with every other widget that shows the same business, and
/// updates when the owner changes the photo (the notifier invalidates it).
final businessAvatarUrlProvider = Provider.autoDispose.family<String?, int>((
  ref,
  id,
) {
  final async = ref.watch(businessProfilePublicProvider(id));
  return switch (async) {
    AsyncData(value: final profile) => profile?.avatarUrl,
    _ => null,
  };
});
