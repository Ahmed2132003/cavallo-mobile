import 'package:flutter/material.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';

import '../../../core/widgets/app_status_chip.dart';
import '../domain/queue_item_entity.dart';
import '../domain/queue_sla.dart';

/// Part P-040 scope: small presentation pieces shared by the queue list
/// and the review screen - kept in one file so a queue row and the review
/// screen can never drift apart in how they show priority, age or a
/// preview.
///
/// Part P-115 (STEP 7A) restyle, presentation only: colours come from the
/// AppColors tokens, and the age chip is the shared [AppStatusChip] (same
/// chip language as the Business Console). No text, key, SLA rule or
/// behaviour changed.

/// Human-readable wait time for the age chip:
/// `<1 min`, `12 min`, `2 h 5 min`, `1 d 3 h`. A negative [age] (clock
/// skew between server and device can't produce one - `age` is computed
/// server-side and clamped at 0 - but this stays safe regardless) is
/// treated as zero.
String formatQueueAge(Duration age) {
  final totalMinutes = age.isNegative ? 0 : age.inMinutes;
  if (totalMinutes < 1) {
    return '<1 min';
  }
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final totalHours = totalMinutes ~/ 60;
  if (totalHours < 24) {
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$totalHours h' : '$totalHours h $minutes min';
  }
  final days = totalHours ~/ 24;
  final hours = totalHours % 24;
  return hours == 0 ? '$days d' : '$days d $hours h';
}

/// Display label for the backend's content-type model name
/// (`"post"` -> `"Post"`). Deliberately generic - no per-type table - so a
/// content type added in Phase 7/8 needs no change here.
String contentTypeLabel(String contentType) {
  if (contentType.isEmpty) {
    return 'Unknown';
  }
  return contentType[0].toUpperCase() + contentType.substring(1);
}

/// Priority badge. `fast_path` is filled with the brand colour and carries a
/// bolt icon so it stands out in a scan; `normal` is a quiet outline. The
/// green/amber/red palette stays reserved for [QueueAgeChip], so the two
/// signals never get confused.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final QueuePriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    if (priority == QueuePriority.fastPath) {
      return Container(
        key: const ValueKey('priority-badge-fast'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.brand,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: colors.onBrand),
            const SizedBox(width: 2),
            Text(
              'Fast path',
              style: textTheme.labelSmall?.copyWith(
                color: colors.onBrand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('priority-badge-normal'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Normal',
        style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// How long the item has waited, coloured by [ModerationSla.urgencyFor]:
/// green (on track) -> amber (approaching the SLA) -> red (past it).
/// Colour is never the only signal - the icon changes too, and a breached
/// item says so in words.
///
/// The age shown is the server's snapshot at the last fetch (see
/// `QueueItem.ageDuration`) - it does not tick while the screen is open.
class QueueAgeChip extends StatelessWidget {
  const QueueAgeChip({super.key, required this.priority, required this.age});

  final QueuePriority priority;
  final Duration age;

  @override
  Widget build(BuildContext context) {
    final urgency = ModerationSla.urgencyFor(priority: priority, age: age);

    final label =
        urgency == QueueUrgency.breached
            ? '${formatQueueAge(age)} \u00B7 overdue'
            : formatQueueAge(age);

    final (IconData icon, AppStatusTone tone) = switch (urgency) {
      QueueUrgency.onTrack => (Icons.schedule, AppStatusTone.success),
      QueueUrgency.approaching => (
        Icons.hourglass_bottom,
        AppStatusTone.warning,
      ),
      QueueUrgency.breached => (
        Icons.warning_amber_rounded,
        AppStatusTone.danger,
      ),
    };

    return AppStatusChip(
      key: ValueKey('age-chip-${urgency.name}'),
      label: label,
      icon: icon,
      tone: tone,
    );
  }
}

/// Square preview image, or a neutral placeholder when the item has no
/// image (the backend's generic default preview never has one) or the
/// image fails to load.
class QueuePreviewThumbnail extends StatelessWidget {
  const QueuePreviewThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 56,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) {
      return _placeholder(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colors.textSecondary,
      ),
    );
  }
}
