import 'package:flutter/material.dart';

/// Part P-045 addition (not explicitly named in the part's own file
/// list, but required by its own Architecture Rule: "Like/comment/share
/// stub icons must be visually honest about being inactive ... rather
/// than silently doing nothing"). Factored into one shared widget
/// rather than duplicated across PostCard/ReelCard/PostDetailScreen/
/// ReelDetailScreen so the four copies can't drift out of sync the
/// first time Phase 9 wires real functionality into them.
class ContentStubActionRow extends StatelessWidget {
  const ContentStubActionRow({super.key});

  static const _comingSoon = 'Coming soon';

  void _showComingSoon(BuildContext context, String action) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action — $_comingSoon')));
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.4);

    Widget stubIcon(IconData icon, String label) {
      return IconButton(
        icon: Icon(icon, color: iconColor),
        tooltip: '$label ($_comingSoon)',
        onPressed: () => _showComingSoon(context, label),
      );
    }

    return Row(
      children: [
        stubIcon(Icons.favorite_border, 'Like'),
        stubIcon(Icons.mode_comment_outlined, 'Comment'),
        stubIcon(Icons.share_outlined, 'Share'),
      ],
    );
  }
}