import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_widgets.dart';

/// Part P-040 scope. Covers the pure formatting helpers and the two
/// small widgets whose colors carry meaning (priority badge, age chip).
void main() {
  group('formatQueueAge', () {
    test('under a minute reads "<1 min"', () {
      expect(formatQueueAge(Duration.zero), '<1 min');
      expect(formatQueueAge(const Duration(seconds: 59)), '<1 min');
    });

    test('a negative age is treated as zero', () {
      expect(formatQueueAge(const Duration(minutes: -5)), '<1 min');
    });

    test('whole minutes under an hour', () {
      expect(formatQueueAge(const Duration(seconds: 60)), '1 min');
      expect(formatQueueAge(const Duration(minutes: 12)), '12 min');
      expect(formatQueueAge(const Duration(minutes: 59, seconds: 59)), '59 min');
    });

    test('hours, with minutes only when non-zero', () {
      expect(formatQueueAge(const Duration(minutes: 60)), '1 h');
      expect(formatQueueAge(const Duration(hours: 2, minutes: 5)), '2 h 5 min');
      expect(formatQueueAge(const Duration(hours: 23, minutes: 59)), '23 h 59 min');
    });

    test('days, with hours only when non-zero', () {
      expect(formatQueueAge(const Duration(hours: 24)), '1 d');
      expect(formatQueueAge(const Duration(hours: 25)), '1 d 1 h');
      expect(formatQueueAge(const Duration(hours: 50)), '2 d 2 h');
    });
  });

  group('contentTypeLabel', () {
    test('capitalizes the backend model name', () {
      expect(contentTypeLabel('post'), 'Post');
      expect(contentTypeLabel('reel'), 'Reel');
      expect(contentTypeLabel('story'), 'Story');
    });

    test('an empty type falls back to "Unknown"', () {
      expect(contentTypeLabel(''), 'Unknown');
    });
  });

  group('PriorityBadge', () {
    Future<void> pumpBadge(WidgetTester tester, QueuePriority priority) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PriorityBadge(priority: priority)),
        ),
      );
    }

    testWidgets('fast_path shows a distinct "Fast path" badge', (tester) async {
      await pumpBadge(tester, QueuePriority.fastPath);

      expect(find.byKey(const ValueKey('priority-badge-fast')), findsOneWidget);
      expect(find.text('Fast path'), findsOneWidget);
      expect(find.byKey(const ValueKey('priority-badge-normal')), findsNothing);
    });

    testWidgets('normal shows the quiet "Normal" badge', (tester) async {
      await pumpBadge(tester, QueuePriority.normal);

      expect(find.byKey(const ValueKey('priority-badge-normal')), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.byKey(const ValueKey('priority-badge-fast')), findsNothing);
    });
  });

  group('QueueAgeChip', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required QueuePriority priority,
      required Duration age,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QueueAgeChip(priority: priority, age: age)),
        ),
      );
    }

    Color iconColor(WidgetTester tester) {
      return tester.widget<Icon>(find.byType(Icon)).color!;
    }

    testWidgets('on track is green and shows the plain age', (tester) async {
      await pumpChip(
        tester,
        priority: QueuePriority.fastPath,
        age: const Duration(minutes: 10),
      );

      expect(find.byKey(const ValueKey('age-chip-onTrack')), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(iconColor(tester), Colors.green.shade700);
    });

    testWidgets('approaching is amber', (tester) async {
      await pumpChip(
        tester,
        priority: QueuePriority.fastPath,
        age: const Duration(minutes: 20),
      );

      expect(find.byKey(const ValueKey('age-chip-approaching')), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(iconColor(tester), Colors.amber.shade800);
    });

    testWidgets('breached is red and says "overdue" in words too', (tester) async {
      await pumpChip(
        tester,
        priority: QueuePriority.fastPath,
        age: const Duration(minutes: 31),
      );

      expect(find.byKey(const ValueKey('age-chip-breached')), findsOneWidget);
      expect(find.text('31 min · overdue'), findsOneWidget);
      expect(iconColor(tester), Colors.red.shade700);
    });

    testWidgets('the same 3-hour age is amber for normal, red for fast_path', (
      tester,
    ) async {
      await pumpChip(
        tester,
        priority: QueuePriority.normal,
        age: const Duration(hours: 3),
      );
      expect(find.byKey(const ValueKey('age-chip-approaching')), findsOneWidget);

      await pumpChip(
        tester,
        priority: QueuePriority.fastPath,
        age: const Duration(hours: 3),
      );
      expect(find.byKey(const ValueKey('age-chip-breached')), findsOneWidget);
    });
  });
}