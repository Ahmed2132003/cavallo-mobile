import 'package:flutter/material.dart';

import '../domain/queue_item_entity.dart';
import '../domain/queue_sla.dart';

/// Part P-040 scope: small presentation pieces shared by the queue list
/// (this step) and the review screen (a later step) — kept in one file so
/// a queue row and the review screen can never drift apart in how they
/// show priority, age or a preview.

/// Human-readable wait time for the age chip:
/// `<1 min`, `12 min`, `2 h 5 min`, `1 d 3 h`. A negative [age] (clock
/// skew between server and device can't produce one — `age` is computed
/// server-side and clamped at 0 — but this stays safe regardless) is
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
/// (`"post"` → `"Post"`). Deliberately generic — no per-type table — so a
/// content type added in Phase 7/8 needs no change here.
String contentTypeLabel(String contentType) {
  if (contentType.isEmpty) {
    return 'Unknown';
  }
  return contentType[0].toUpperCase() + contentType.substring(1);
}

/// Priority badge. `fast_path` is filled and carries a bolt icon so it
/// stands out in a scan; `normal` is a quiet outline. Its colors come
/// from the theme's primary colors on purpose — the green/amber/red
/// palette is reserved for [QueueAgeChip], so the two signals never get
/// confused.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final QueuePriority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (priority == QueuePriority.fastPath) {
      return Container(
        key: const ValueKey('priority-badge-fast'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: scheme.onPrimary),
            const SizedBox(width: 2),
            Text(
              'Fast path',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
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
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Normal', style: textTheme.labelSmall),
    );
  }
}

/// How long the item has waited, colored by [ModerationSla.urgencyFor]:
/// green (on track) → amber (approaching the SLA) → red (past it).
/// Color is never the only signal — the icon changes too, and a breached
/// item says so in words.
///
/// The age shown is the server's snapshot at the last fetch (see
/// `QueueItem.ageDuration`) — it does not tick while the screen is open.
class QueueAgeChip extends StatelessWidget {
  const QueueAgeChip({super.key, required this.priority, required this.age});

  final QueuePriority priority;
  final Duration age;

  @override
  Widget build(BuildContext context) {
    final urgency = ModerationSla.urgencyFor(priority: priority, age: age);
    final style = _styleFor(urgency);
    final textTheme = Theme.of(context).textTheme;

    final label = urgency == QueueUrgency.breached
        ? '${formatQueueAge(age)} · overdue'
        : formatQueueAge(age);

    return Container(
      key: ValueKey('age-chip-${urgency.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static ({Color foreground, Color background, IconData icon}) _styleFor(
    QueueUrgency urgency,
  ) {
    return switch (urgency) {
      QueueUrgency.onTrack => (
        foreground: Colors.green.shade700,
        background: Colors.green.shade50,
        icon: Icons.schedule,
      ),
      QueueUrgency.approaching => (
        foreground: Colors.amber.shade800,
        background: Colors.amber.shade50,
        icon: Icons.hourglass_bottom,
      ),
      QueueUrgency.breached => (
        foreground: Colors.red.shade700,
        background: Colors.red.shade50,
        icon: Icons.warning_amber_rounded,
      ),
    };
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}