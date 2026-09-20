import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/moderation/data/moderation_repository_impl.dart';
import 'package:social_commerce_app/features/moderation/domain/moderation_repository.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_queue_screen.dart';

/// Hand-rolled fake, matching this project's convention (no
/// mockito/mocktail). This screen only ever reads the queue, so approve
/// and reject are never exercised here (they belong to the review
/// screen's tests, a later step).
class _FakeModerationRepository implements ModerationRepository {
  _FakeModerationRepository({List<QueueItem> items = const []})
    : currentItems = List.of(items);

  List<QueueItem> currentItems;

  /// When non-null, [fetchQueue] throws this instead of resolving.
  Object? fetchError;

  /// When non-null, [fetchQueue] waits on it — holds the first load in
  /// flight so the loading state can be observed.
  Completer<void>? fetchGate;

  int fetchCallCount = 0;

  @override
  Future<PaginatedResponse<QueueItem>> fetchQueue({
    QueuePriority? priority,
  }) async {
    fetchCallCount++;
    if (fetchGate != null) {
      await fetchGate!.future;
    }
    if (fetchError != null) {
      throw fetchError!;
    }
    return PaginatedResponse<QueueItem>(
      results: List.of(currentItems),
      next: null,
      previous: null,
    );
  }

  @override
  Future<QueueItem> approve(int queueItemId) =>
      throw UnimplementedError('Not exercised by moderation_queue_screen_test');

  @override
  Future<QueueItem> reject({
    required int queueItemId,
    required String reason,
  }) => throw UnimplementedError(
    'Not exercised by moderation_queue_screen_test',
  );
}

QueueItem _item(
  int id, {
  QueuePriority priority = QueuePriority.normal,
  Duration age = const Duration(minutes: 5),
  String? previewText,
  String? businessName,
  String contentType = 'post',
}) {
  return QueueItem(
    id: id,
    contentType: contentType,
    status: QueueItemStatus.pending,
    priority: priority,
    createdAt: DateTime.utc(2026, 9, 20, 10),
    ageDuration: age,
    previewText: previewText ?? 'Preview $id',
    submitterBusinessName: businessName,
  );
}

DioException _dioFailure(int statusCode, ApiFailure failure) {
  final requestOptions = RequestOptions(path: '/api/v1/moderation/queue/');
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
    error: failure,
  );
}

Widget _wrap(
  _FakeModerationRepository fake, {
  void Function(QueueItem item)? onOpenItem,
}) {
  return ProviderScope(
    overrides: [moderationRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: ModerationQueueScreen(onOpenItem: onOpenItem ?? (item) {}),
    ),
  );
}

/// A tall test surface so every row of a multi-item list is built and
/// visible (the default 800x600 fits only a handful of cards).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _rowFinder(int id) => find.byKey(ValueKey('queue-row-$id'));

Color _ageIconColorInRow(WidgetTester tester, int id, String urgencyName) {
  final chip = find.descendant(
    of: _rowFinder(id),
    matching: find.byKey(ValueKey('age-chip-$urgencyName')),
  );
  expect(chip, findsOneWidget, reason: 'row $id should have a $urgencyName chip');
  return tester.widget<Icon>(
    find.descendant(of: chip, matching: find.byType(Icon)),
  ).color!;
}

void main() {
  group('loading, empty and error states', () {
    testWidgets('shows a loading indicator while the first load is in flight', (
      tester,
    ) async {
      final fake = _FakeModerationRepository()..fetchGate = Completer<void>();
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.fetchGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an empty queue shows the "queue is clear" message', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_FakeModerationRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('The queue is clear.'), findsOneWidget);
    });

    testWidgets(
      'a failure shows the backend message with a Retry that reloads the '
      'queue',
      (tester) async {
        final fake = _FakeModerationRepository()
          ..fetchError = _dioFailure(
            500,
            const ServerFailure(message: 'Server exploded.'),
          );
        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.text('Server exploded.'), findsOneWidget);
        expect(fake.fetchCallCount, 1);

        // "Fix the backend", then retry.
        fake.fetchError = null;
        fake.currentItems = [_item(1, previewText: 'Recovered item')];
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Recovered item'), findsOneWidget);
        expect(find.text('Server exploded.'), findsNothing);
        expect(fake.fetchCallCount, 2);
      },
    );

    testWidgets(
      'a 403 explains the Moderator-group requirement instead of showing '
      'a raw permission string',
      (tester) async {
        final fake = _FakeModerationRepository()
          ..fetchError = _dioFailure(
            403,
            const AuthFailure(
              message: 'Missing required capability: can_moderate_content.',
            ),
          );
        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(find.textContaining('Moderator group'), findsOneWidget);
        expect(find.textContaining('can_moderate_content'), findsNothing);
      },
    );
  });

  group('list content', () {
    testWidgets('shows fast_path items first, then the oldest normal first', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeModerationRepository(
        items: [
          _item(1, previewText: 'Newer normal', age: const Duration(minutes: 5)),
          _item(2, previewText: 'Older normal', age: const Duration(minutes: 90)),
          _item(
            3,
            previewText: 'Fast path item',
            priority: QueuePriority.fastPath,
            age: const Duration(minutes: 2),
          ),
        ],
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      final fastY = tester.getTopLeft(find.text('Fast path item')).dy;
      final olderY = tester.getTopLeft(find.text('Older normal')).dy;
      final newerY = tester.getTopLeft(find.text('Newer normal')).dy;

      expect(fastY, lessThan(olderY));
      expect(olderY, lessThan(newerY));
    });

    testWidgets('only fast_path rows carry the distinct fast-path badge', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeModerationRepository(
        items: [
          _item(1),
          _item(2, priority: QueuePriority.fastPath),
          _item(3),
        ],
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('priority-badge-fast')), findsOneWidget);
      expect(find.byKey(const ValueKey('priority-badge-normal')), findsNWidgets(2));
      expect(
        find.descendant(
          of: _rowFinder(2),
          matching: find.byKey(const ValueKey('priority-badge-fast')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('each row shows preview text, content type and business', (
      tester,
    ) async {
      final fake = _FakeModerationRepository(
        items: [
          _item(
            1,
            previewText: 'Summer sale caption',
            businessName: 'Elegance Store',
            contentType: 'reel',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('Summer sale caption'), findsOneWidget);
      expect(find.text('Reel · Elegance Store'), findsOneWidget);
    });

    testWidgets('a row without a business shows just the content type', (
      tester,
    ) async {
      final fake = _FakeModerationRepository(items: [_item(1)]);
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('an item with no preview text shows a placeholder line', (
      tester,
    ) async {
      final fake = _FakeModerationRepository(
        items: [
          QueueItem(
            id: 1,
            contentType: 'post',
            status: QueueItemStatus.pending,
            priority: QueuePriority.normal,
            createdAt: DateTime.utc(2026, 9, 20, 10),
            ageDuration: const Duration(minutes: 1),
          ),
        ],
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('No preview available'), findsOneWidget);
    });

    testWidgets('the summary line counts pending and fast_path items', (
      tester,
    ) async {
      _useTallSurface(tester);
      final fake = _FakeModerationRepository(
        items: [
          _item(1),
          _item(2, priority: QueuePriority.fastPath),
          _item(3, priority: QueuePriority.fastPath),
        ],
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('3 pending · 2 fast path'), findsOneWidget);
    });

    testWidgets('the summary omits the fast path count when there is none', (
      tester,
    ) async {
      final fake = _FakeModerationRepository(items: [_item(1), _item(2)]);
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('2 pending'), findsOneWidget);
    });
  });

  group('age escalation', () {
    testWidgets(
      'fast_path rows escalate green → amber → red at 15 and 30 minutes',
      (tester) async {
        _useTallSurface(tester);
        final fake = _FakeModerationRepository(
          items: [
            _item(1, priority: QueuePriority.fastPath, age: const Duration(minutes: 10)),
            _item(2, priority: QueuePriority.fastPath, age: const Duration(minutes: 20)),
            _item(3, priority: QueuePriority.fastPath, age: const Duration(minutes: 31)),
          ],
        );
        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(_ageIconColorInRow(tester, 1, 'onTrack'), Colors.green.shade700);
        expect(_ageIconColorInRow(tester, 2, 'approaching'), Colors.amber.shade800);
        expect(_ageIconColorInRow(tester, 3, 'breached'), Colors.red.shade700);
      },
    );

    testWidgets(
      'normal rows use the longer 4-hour SLA: 1 h green, 3 h amber, 5 h red',
      (tester) async {
        _useTallSurface(tester);
        final fake = _FakeModerationRepository(
          items: [
            _item(1, age: const Duration(hours: 1)),
            _item(2, age: const Duration(hours: 3)),
            _item(3, age: const Duration(hours: 5)),
          ],
        );
        await tester.pumpWidget(_wrap(fake));
        await tester.pumpAndSettle();

        expect(_ageIconColorInRow(tester, 1, 'onTrack'), Colors.green.shade700);
        expect(_ageIconColorInRow(tester, 2, 'approaching'), Colors.amber.shade800);
        expect(_ageIconColorInRow(tester, 3, 'breached'), Colors.red.shade700);
      },
    );
  });

  group('interaction', () {
    testWidgets('tapping a row calls onOpenItem with that item', (tester) async {
      _useTallSurface(tester);
      final tapped = <QueueItem>[];
      final fake = _FakeModerationRepository(
        items: [_item(1, previewText: 'First'), _item(2, previewText: 'Second')],
      );
      await tester.pumpWidget(_wrap(fake, onOpenItem: tapped.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(tapped, hasLength(1));
      expect(tapped.single.id, 2);
    });

    testWidgets('the app-bar refresh button refetches the queue', (tester) async {
      final fake = _FakeModerationRepository(items: [_item(1)]);
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();
      expect(fake.fetchCallCount, 1);

      fake.currentItems = [_item(1), _item(2, previewText: 'Brand new item')];
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(fake.fetchCallCount, 2);
      expect(find.text('Brand new item'), findsOneWidget);
    });
  });
}