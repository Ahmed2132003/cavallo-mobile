import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/moderation/data/moderation_repository_impl.dart';
import 'package:social_commerce_app/features/moderation/domain/moderation_repository.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_provider.dart';

/// Hand-rolled test double for [ModerationRepository] — this project
/// doesn't use mockito/mocktail anywhere (confirmed against
/// `own_products_provider_test.dart`'s own note); every provider test
/// hand-rolls a fake like this one.
class FakeModerationRepository implements ModerationRepository {
  FakeModerationRepository({List<QueueItem> items = const []})
    : currentItems = List.of(items);

  /// The fake "backend" pending list. Mutable so a test can change what
  /// the next `fetchQueue` returns (refresh), and so approve/reject can
  /// mirror a real decision's persisted effect (the row leaves pending).
  List<QueueItem> currentItems;

  /// When non-null, [fetchQueue] throws this instead of resolving.
  Object? fetchError;

  /// When non-null, [approve] throws this instead of deciding.
  Object? approveError;

  /// When non-null, [reject] throws this instead of deciding.
  Object? rejectError;

  /// When non-null, [approve] waits on it before deciding — lets a test
  /// hold a call "in flight" to exercise the duplicate-tap guard.
  Completer<void>? approveGate;

  int fetchCallCount = 0;
  int approveCallCount = 0;
  int rejectCallCount = 0;
  int? lastApprovedId;
  int? lastRejectedId;
  String? lastRejectReason;

  @override
  Future<PaginatedResponse<QueueItem>> fetchQueue({
    QueuePriority? priority,
  }) async {
    fetchCallCount++;
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
  Future<QueueItem> approve(int queueItemId) async {
    approveCallCount++;
    lastApprovedId = queueItemId;
    if (approveGate != null) {
      await approveGate!.future;
    }
    if (approveError != null) {
      throw approveError!;
    }
    return _decide(queueItemId, QueueItemStatus.approved);
  }

  @override
  Future<QueueItem> reject({
    required int queueItemId,
    required String reason,
  }) async {
    rejectCallCount++;
    lastRejectedId = queueItemId;
    lastRejectReason = reason;
    if (rejectError != null) {
      throw rejectError!;
    }
    return _decide(queueItemId, QueueItemStatus.rejected);
  }

  QueueItem _decide(int queueItemId, QueueItemStatus status) {
    final original = currentItems.firstWhere((i) => i.id == queueItemId);
    currentItems.removeWhere((i) => i.id == queueItemId);
    return QueueItem(
      id: original.id,
      contentType: original.contentType,
      status: status,
      priority: original.priority,
      createdAt: original.createdAt,
      ageDuration: original.ageDuration,
      previewText: original.previewText,
    );
  }
}

QueueItem _item(
  int id, {
  QueuePriority priority = QueuePriority.normal,
  int ageSeconds = 60,
}) {
  return QueueItem(
    id: id,
    contentType: 'post',
    status: QueueItemStatus.pending,
    priority: priority,
    createdAt: DateTime.utc(2026, 9, 20, 10),
    ageDuration: Duration(seconds: ageSeconds),
    previewText: 'Item $id',
  );
}

/// A [DioException] shaped exactly like what `ErrorInterceptor` (Part
/// P-004) produces: the raw response (so the status code is readable) and
/// a typed [ApiFailure] in `.error`.
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

/// Builds a container wired to [fake], and keeps the auto-disposed
/// provider alive for the duration of the test (nothing else is
/// listening to it here, unlike in the real app where the queue screen
/// does).
ProviderContainer _makeContainer(FakeModerationRepository fake) {
  final container = ProviderContainer(
    overrides: [moderationRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  container.listen(moderationQueueProvider, (previous, next) {});
  return container;
}

void main() {
  group('sortModerationQueue', () {
    test('puts fast_path first, then the oldest item first within a tier', () {
      final sorted = sortModerationQueue([
        _item(1, ageSeconds: 100),
        _item(2, ageSeconds: 500),
        _item(3, priority: QueuePriority.fastPath, ageSeconds: 10),
        _item(4, priority: QueuePriority.fastPath, ageSeconds: 300),
      ]);

      expect(sorted.map((i) => i.id), [4, 3, 2, 1]);
    });

    test('breaks age ties by the lower queue id, deterministically', () {
      final sorted = sortModerationQueue([
        _item(9, ageSeconds: 60),
        _item(3, ageSeconds: 60),
        _item(5, ageSeconds: 60),
      ]);

      expect(sorted.map((i) => i.id), [3, 5, 9]);
    });

    test('returns a new list and does not mutate its input', () {
      final input = [_item(1, ageSeconds: 10), _item(2, ageSeconds: 99)];

      final sorted = sortModerationQueue(input);

      expect(sorted.map((i) => i.id), [2, 1]);
      expect(input.map((i) => i.id), [1, 2]);
    });
  });

  group('ModerationQueueNotifier.build', () {
    test('loads the queue sorted fast_path first, oldest first', () async {
      final fake = FakeModerationRepository(
        items: [
          _item(1, ageSeconds: 100),
          _item(2, priority: QueuePriority.fastPath, ageSeconds: 30),
          _item(3, ageSeconds: 900),
        ],
      );
      final container = _makeContainer(fake);

      final items = await container.read(moderationQueueProvider.future);

      expect(items.map((i) => i.id), [2, 3, 1]);
      expect(fake.fetchCallCount, 1);
    });

    test(
      'a fetch failure surfaces as AsyncError immediately (retry is '
      'disabled, so it does not hang in a loading state)',
      () async {
        final fake = FakeModerationRepository()
          ..fetchError = _dioFailure(
            403,
            const AuthFailure(message: 'Missing required capability.'),
          );
        final container = _makeContainer(fake);

        // A plain await inside try/catch, not expectLater(..., throwsA):
        // session_provider_test.dart documents that the matcher form
        // leaves an initial-build rejection unobserved.
        Object? caughtError;
        try {
          await container.read(moderationQueueProvider.future);
          fail('Expected moderationQueueProvider.future to throw.');
        } catch (error) {
          caughtError = error;
        }

        expect(caughtError, isA<DioException>());
        expect(container.read(moderationQueueProvider).hasError, isTrue);
      },
    );
  });

  group('ModerationQueueNotifier.approve', () {
    test(
      'calls the repository, then removes the item locally with no refetch',
      () async {
        final fake = FakeModerationRepository(
          items: [_item(1), _item(2, ageSeconds: 200)],
        );
        final container = _makeContainer(fake);
        await container.read(moderationQueueProvider.future);

        await container.read(moderationQueueProvider.notifier).approve(2);

        expect(fake.lastApprovedId, 2);
        expect(fake.fetchCallCount, 1); // no refetch after the action
        expect(
          container.read(moderationQueueProvider).value!.map((i) => i.id),
          [1],
        );
      },
    );

    test(
      'a generic failure rethrows and leaves the list untouched',
      () async {
        final fake = FakeModerationRepository(items: [_item(1), _item(2)])
          ..approveError = _dioFailure(
            500,
            const ServerFailure(message: 'boom'),
          );
        final container = _makeContainer(fake);
        await container.read(moderationQueueProvider.future);

        await expectLater(
          () => container.read(moderationQueueProvider.notifier).approve(1),
          throwsA(isA<DioException>()),
        );

        expect(
          container.read(moderationQueueProvider).value!.map((i) => i.id),
          [1, 2],
        );
      },
    );

    for (final statusCode in [409, 404]) {
      test(
        'a $statusCode (item no longer pending) rethrows AND removes the '
        'item locally',
        () async {
          final fake = FakeModerationRepository(items: [_item(1), _item(2)])
            ..approveError = _dioFailure(
              statusCode,
              const UnknownFailure(message: 'Already decided.'),
            );
          final container = _makeContainer(fake);
          await container.read(moderationQueueProvider.future);

          await expectLater(
            () => container.read(moderationQueueProvider.notifier).approve(1),
            throwsA(isA<DioException>()),
          );

          expect(
            container.read(moderationQueueProvider).value!.map((i) => i.id),
            [2],
          );
        },
      );
    }

    test('a second call for the same id while one is in flight is ignored', () async {
      final fake = FakeModerationRepository(items: [_item(1)])
        ..approveGate = Completer<void>();
      final container = _makeContainer(fake);
      await container.read(moderationQueueProvider.future);
      final notifier = container.read(moderationQueueProvider.notifier);

      final first = notifier.approve(1); // held at the gate
      await notifier.approve(1); // duplicate tap: returns immediately
      fake.approveGate!.complete();
      await first;

      expect(fake.approveCallCount, 1);
      expect(container.read(moderationQueueProvider).value, isEmpty);
    });
  });

  group('ModerationQueueNotifier.reject', () {
    test(
      'sends the TRIMMED reason, then removes the item locally',
      () async {
        final fake = FakeModerationRepository(items: [_item(1), _item(2)]);
        final container = _makeContainer(fake);
        await container.read(moderationQueueProvider.future);

        await container
            .read(moderationQueueProvider.notifier)
            .reject(1, '  Contains prohibited content  ');

        expect(fake.lastRejectedId, 1);
        expect(fake.lastRejectReason, 'Contains prohibited content');
        expect(
          container.read(moderationQueueProvider).value!.map((i) => i.id),
          [2],
        );
      },
    );

    test(
      'a blank reason throws ArgumentError before any network call and '
      'leaves the list untouched',
      () async {
        final fake = FakeModerationRepository(items: [_item(1)]);
        final container = _makeContainer(fake);
        await container.read(moderationQueueProvider.future);

        await expectLater(
          () => container.read(moderationQueueProvider.notifier).reject(1, '   '),
          throwsArgumentError,
        );

        expect(fake.rejectCallCount, 0);
        expect(
          container.read(moderationQueueProvider).value!.map((i) => i.id),
          [1],
        );
      },
    );

    test(
      'a backend validation failure rethrows and leaves the list untouched',
      () async {
        final fake = FakeModerationRepository(items: [_item(1)])
          ..rejectError = _dioFailure(
            400,
            const ValidationFailure(
              message: 'Invalid input',
              fields: {
                'reason': ['This field may not be blank.'],
              },
            ),
          );
        final container = _makeContainer(fake);
        await container.read(moderationQueueProvider.future);

        await expectLater(
          () => container
              .read(moderationQueueProvider.notifier)
              .reject(1, 'some reason'),
          throwsA(isA<DioException>()),
        );

        expect(
          container.read(moderationQueueProvider).value!.map((i) => i.id),
          [1],
        );
      },
    );
  });

  group('ModerationQueueNotifier.refresh', () {
    test('refetches and re-sorts, picking up newly queued items', () async {
      final fake = FakeModerationRepository(items: [_item(1, ageSeconds: 50)]);
      final container = _makeContainer(fake);
      await container.read(moderationQueueProvider.future);

      fake.currentItems = [
        _item(1, ageSeconds: 80),
        _item(7, priority: QueuePriority.fastPath, ageSeconds: 5),
      ];
      await container.read(moderationQueueProvider.notifier).refresh();

      expect(fake.fetchCallCount, 2);
      expect(
        container.read(moderationQueueProvider).value!.map((i) => i.id),
        [7, 1],
      );
    });
  });
}