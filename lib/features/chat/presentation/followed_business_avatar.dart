import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../business_profile/presentation/business_avatar_provider.dart';
import '../domain/followed_business.dart';

/// Avatar of a business in the "New chat" picker. The followed-businesses
/// endpoint carries no photo, so it is resolved per row from the public
/// profile (same lookup the feed rows use); initials show until it arrives.
class FollowedBusinessAvatar extends ConsumerWidget {
  const FollowedBusinessAvatar({super.key, required this.business});

  final FollowedBusiness business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAvatar(
      imageUrl: ref.watch(businessAvatarUrlProvider(business.businessId)),
      name: business.businessName,
      size: 44,
    );
  }
}
