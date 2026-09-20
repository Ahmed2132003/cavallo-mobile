import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_sla.dart';

/// Part P-040 scope. Pins the escalation thresholds to the backend's
/// P-039 SLA job (`FAST_PATH_SLA_MINUTES = 30`, `NORMAL_SLA_HOURS = 4`),
/// including the exact boundary instants: "approaching" starts at half
/// the threshold (inclusive), and "breached" only once an item is
/// STRICTLY older than the threshold — the same `created_at < cutoff`
/// rule the backend applies.
void main() {
  QueueUrgency fast(Duration age) =>
      ModerationSla.urgencyFor(priority: QueuePriority.fastPath, age: age);
  QueueUrgency normal(Duration age) =>
      ModerationSla.urgencyFor(priority: QueuePriority.normal, age: age);

  group('fast_path (30-minute SLA)', () {
    test('a brand-new item is on track', () {
      expect(fast(Duration.zero), QueueUrgency.onTrack);
    });

    test('one second before the 15-minute warn point is still on track', () {
      expect(fast(const Duration(minutes: 14, seconds: 59)), QueueUrgency.onTrack);
    });

    test('exactly 15 minutes is approaching (inclusive)', () {
      expect(fast(const Duration(minutes: 15)), QueueUrgency.approaching);
    });

    test('exactly 30 minutes is still approaching, not breached', () {
      expect(fast(const Duration(minutes: 30)), QueueUrgency.approaching);
    });

    test('one second past 30 minutes is breached', () {
      expect(fast(const Duration(minutes: 30, seconds: 1)), QueueUrgency.breached);
    });
  });

  group('normal (4-hour SLA)', () {
    test('one second before the 2-hour warn point is still on track', () {
      expect(normal(const Duration(hours: 1, minutes: 59, seconds: 59)), QueueUrgency.onTrack);
    });

    test('exactly 2 hours is approaching (inclusive)', () {
      expect(normal(const Duration(hours: 2)), QueueUrgency.approaching);
    });

    test('exactly 4 hours is still approaching, not breached', () {
      expect(normal(const Duration(hours: 4)), QueueUrgency.approaching);
    });

    test('one second past 4 hours is breached', () {
      expect(normal(const Duration(hours: 4, seconds: 1)), QueueUrgency.breached);
    });
  });

  test('the same age is judged differently per priority', () {
    const threeHours = Duration(hours: 3);

    expect(fast(threeHours), QueueUrgency.breached);
    expect(normal(threeHours), QueueUrgency.approaching);
  });

  test('warnAfter is half of breachAfter for both priorities', () {
    for (final priority in QueuePriority.values) {
      expect(
        ModerationSla.warnAfter(priority) * 2,
        ModerationSla.breachAfter(priority),
      );
    }
  });
}