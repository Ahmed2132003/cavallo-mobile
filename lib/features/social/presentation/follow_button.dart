import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058: the real Follow / Following button for a business, plus its
/// followers count. Replaces the disabled stub button on the public business
/// profile screen (P-029).
///
/// State lives in `businessFollowProvider`, keyed by [businessId] only, so
/// every place that shows the same business (this button, any future card)
/// always agrees. This widget seeds that provider once from [followerCount]
/// (the real value the backend returned with the profile).
///
/// KNOWN GAP (flagged, not silently worked around): the backend does not yet
/// say whether the current user already follows this business (no
/// is_following field on the business serializer), so a fresh app session
/// always starts as "Follow". Only follows made in the current session are
/// remembered. Following twice is harmless because the backend toggle is
/// idempotent.
///
/// [onToggled], when given, runs after a follow or unfollow request
/// succeeded (never after a failed one). The profile screen uses it to
/// reload the profile so the count reflects the server's real value.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.businessId,
    required this.followerCount,
    this.onToggled,
  });

  final int businessId;
  final int followerCount;
  final VoidCallback? onToggled;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _seeded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Provider state can't be modified during the build phase, so defer.
    Future.microtask(() {
      if (!mounted) return;
      final current = ref.read(businessFollowProvider(widget.businessId));
      ref
          .read(businessFollowProvider(widget.businessId).notifier)
          .seed(
            // Keep whatever this session already knows about following.
            isFollowing: current.isFollowing,
            followersCount: widget.followerCount,
          );
      setState(() => _seeded = true);
    });
  }

  Future<void> _toggle() async {
    // Ignore a second tap while a request is in flight: two overlapping
    // follow/unfollow calls could reach the server in the wrong order.
    if (_busy) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(businessFollowProvider(widget.businessId).notifier)
          .toggleFollow();
      if (mounted) widget.onToggled?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(socialErrorMessage(e))));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessFollowProvider(widget.businessId));
    // Before the one-time seed lands, show the value we were given instead
    // of a flash of "0 followers".
    final count = _seeded ? state.followersCount : widget.followerCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: state.isFollowing ? 'Following' : 'Follow',
          onPressed: _toggle,
        ),
        const SizedBox(height: 6),
        Text(
          count == 1 ? '1 follower' : '$count followers',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}