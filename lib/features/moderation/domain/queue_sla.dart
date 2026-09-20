/// Part P-040 scope: how urgent a pending queue item is, judged against
/// the SAME thresholds the backend's SLA job (Part P-039,
/// `moderation/tasks.py`) uses to flag a breach — so the "backlog is
/// building up" signal a moderator sees in the UI agrees with what the
/// server logs.
///
/// The backend's two constants are per-priority, not global
/// (`FAST_PATH_SLA_MINUTES = 30`, `NORMAL_SLA_HOURS = 4`, both marked
/// "placeholder values pending real-world tuning"), so the escalation
/// here is per-priority too: a 3-hour-old *normal* item is not urgent,
/// a 3-hour-old *fast_path* item is long past breach.
///
/// If those two backend constants are ever retuned, the four durations
/// below are the only place in the Flutter app that must change with
/// them.
library;

import 'queue_item_entity.dart';

/// Where an item sits relative to its priority's SLA.
enum QueueUrgency {
  /// Comfortably inside the SLA — shown green.
  onTrack,

  /// At least half-way to the SLA threshold but not yet past it — shown
  /// amber ("approaching").
  approaching,

  /// Older than the SLA threshold — the same condition under which
  /// P-039 logs a `moderation_sla_breach` — shown red.
  breached,
}

class ModerationSla {
  ModerationSla._();

  /// Mirrors `FAST_PATH_SLA_MINUTES = 30` (P-039).
  static const Duration fastPathBreachAfter = Duration(minutes: 30);

  /// Half of [fastPathBreachAfter] — the "approaching" point.
  static const Duration fastPathWarnAfter = Duration(minutes: 15);

  /// Mirrors `NORMAL_SLA_HOURS = 4` (P-039).
  static const Duration normalBreachAfter = Duration(hours: 4);

  /// Half of [normalBreachAfter] — the "approaching" point.
  static const Duration normalWarnAfter = Duration(hours: 2);

  static Duration breachAfter(QueuePriority priority) {
    return switch (priority) {
      QueuePriority.fastPath => fastPathBreachAfter,
      QueuePriority.normal => normalBreachAfter,
    };
  }

  static Duration warnAfter(QueuePriority priority) {
    return switch (priority) {
      QueuePriority.fastPath => fastPathWarnAfter,
      QueuePriority.normal => normalWarnAfter,
    };
  }

  /// Classifies [age] for [priority].
  ///
  /// Boundary semantics match the backend: P-039 flags an item only when
  /// it is STRICTLY older than the threshold (`created_at < cutoff`), so
  /// an item exactly at the threshold is still [QueueUrgency.approaching],
  /// and becomes [QueueUrgency.breached] one instant later. The
  /// "approaching" point itself is inclusive.
  static QueueUrgency urgencyFor({
    required QueuePriority priority,
    required Duration age,
  }) {
    if (age > breachAfter(priority)) {
      return QueueUrgency.breached;
    }
    if (age >= warnAfter(priority)) {
      return QueueUrgency.approaching;
    }
    return QueueUrgency.onTrack;
  }
}