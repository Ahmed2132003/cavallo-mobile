import 'package:flutter/material.dart';

import '../domain/public_post_entity.dart';
import 'content_stub_action_row.dart';

/// Part P-045 scope: a reusable, customer-facing presentation of a
/// single published [PublicPost] — used by the business profile
/// screen's Posts/Reels section (this part, STEP 7), and designed so
/// Phase 10's Feed (Part P-061) can drop it into a scrollable list with
/// zero modification: no hardcoded width assumption beyond ordinary
/// responsive behavior, no dependency on any specific parent screen's
/// state — every value this widget needs (the post, the business's
/// display name, the tap callback) is passed in by the caller.
///
/// `businessAvatarUrl` was in the master plan's UI mockup but is
/// deliberately NOT a parameter here: `BusinessProfile` has no
/// logo/avatar field on the backend at all yet (confirmed from
/// `business_profile_entity.dart`'s own docstring, "No logo/cover
/// image" — P-029's `_ProfileHeader` is text-only for the same reason).
/// Business identity is shown as [businessName] text only, same
/// precedent.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.businessName,
    this.onTap,
  });

  final PublicPost post;
  final String businessName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostImage(imageUrl: post.imageUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      businessName,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                post.caption,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const ContentStubActionRow(),
          ],
        ),
      ),
    );
  }
}

/// Media area with a neutral fallback for "no image" and for a URL
/// that fails to load. Deliberately a local, duplicated widget rather
/// than a shared one — same precedent as
/// `business_profile_public_screen.dart`'s own `_ProductThumbnail`
/// (flagged there as a deliberate duplication, not an oversight).
class _PostImage extends StatelessWidget {
  const _PostImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final url = imageUrl;

    Widget placeholder(IconData icon) => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(icon, size: 40),
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: (url == null || url.isEmpty)
          ? placeholder(Icons.image_outlined)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  placeholder(Icons.broken_image_outlined),
            ),
    );
  }
}