import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/moderation/data/moderation_repository_impl.dart';
import 'package:social_commerce_app/features/moderation/domain/moderation_repository.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_provider.dart';
import 'package:social_commerce_app/features/moderation/presentation/moderation_review_screen.dart';

/// Hand-rolled fake, matching this project's convention (no
/// mockito/mocktail). Unlike the queue-screen test's fake, this one
/// records approve/reject calls, and never removes anything from its own
/// list on approve/reject — so if an item leaves the provider's state in
/// a test below, it is the notifier's local removal that did it, not a
/// refetch.
class _FakeModerationRepository implements ModerationRepository {
  _FakeModerationRepository(List<QueueItem> items)
    : currentItems = List.of(items);

  final List<QueueItem> currentItems;

  /// Awaited by [approve] / [reject] before they resolve; may throw to
  /// simulate a backend failure, or wait on a [Completer] to hold the
  /// request in flight.
  Future<void> Function()? approveBehavior;
  Future<void> Function()? rejectBehavior;

  final List<int> approvedIds = [];
  final List<int> rejectedIds = [];
  final List<String> rejectReasons = [];

  @override
  Future<PaginatedResponse<QueueItem>> fetchQueue({
    QueuePriority? priority,
  }) async {
    return PaginatedResponse<QueueItem>(
      results: List.of(currentItems),
      next: null,
      previous: null,
    );
  }

  @override
  Future<QueueItem> approve(int queueItemId) async {
    approvedIds.add(queueItemId);
    if (approveBehavior != null) {
      await approveBehavior!();
    }
    return _item(queueItemId);
  }

  @override
  Future<QueueItem> reject({
    required int queueItemId,
    required String reason,
  }) async {
    rejectedIds.add(queueItemId);
    rejectReasons.add(reason);
    if (rejectBehavior != null) {
      await rejectBehavior!();
    }
    return _item(queueItemId);
  }
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
    previewText: previewText,
    submitterBusinessName: businessName,
  );
}

DioException _dioFailure(int statusCode, ApiFailure failure) {
  final requestOptions = RequestOptions(path: '/api/v1/moderation/queue/7/');
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
    error: failure,
  );
}

/// Stands in for the queue screen: a page with a button that pushes the
/// review screen and shows what the screen popped with, so "leaves the
/// screen" and its result are both observable without GoRouter.
class _Host extends StatefulWidget {
  const _Host({required this.item});

  final QueueItem item;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const ValueKey('open-review'),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ModerationReviewScreen(item: widget.item),
                ),
              );
              setState(() => _result = result);
            },
            child: const Text('Open'),
          ),
          Text('result: $_result'),
        ],
      ),
    );
  }
}

/// Builds the app around [_Host], opens the review screen for [item], and
/// returns the container so tests can read the queue provider's state.
///
/// The queue provider is `autoDispose`, so the container itself listens
/// to it for the whole test — otherwise it would be disposed the moment
/// the review screen pops, and reading it afterwards would silently
/// rebuild it from the fake instead of showing the notifier's state.
Future<ProviderContainer> _openReview(
  WidgetTester tester,
  _FakeModerationRepository fake,
  QueueItem item,
) async {
  final container = ProviderContainer(
    overrides: [moderationRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  container.listen(moderationQueueProvider, (previous, next) {});

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _Host(item: item)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-review')));
  await tester.pumpAndSettle();
  return container;
}

List<int> _queueIds(ProviderContainer container) {
  return container
      .read(moderationQueueProvider)
      .value!
      .map((item) => item.id)
      .toList();
}

Finder get _approveButton => find.byKey(const ValueKey('review-approve-button'));
Finder get _rejectButton => find.byKey(const ValueKey('review-reject-button'));
Finder get _confirmButton => find.byKey(const ValueKey('reject-confirm-button'));

AppButton _confirm(WidgetTester tester) =>
    tester.widget<AppButton>(_confirmButton);

Future<void> _openRejectDialog(WidgetTester tester) async {
  await tester.tap(_rejectButton);
  await tester.pumpAndSettle();
}

void main() {
  late QueueItem target;
  late QueueItem other;

  setUp(() {
    target = _item(7, previewText: 'Great deal on shoes');
    other = _item(8, previewText: 'Second item');
  });

  group('content', () {
    testWidgets('shows the preview, type, submitter, priority and age', (
      tester,
    ) async {
      final item = _item(
        7,
        priority: QueuePriority.fastPath,
        age: const Duration(minutes: 40),
        previewText: 'Great deal on shoes',
        businessName: 'Cavallo Shoes',
      );
      await _openReview(tester, _FakeModerationRepository([item]), item);

      expect(find.text('Great deal on shoes'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
      expect(find.text('Cavallo Shoes'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.byKey(const ValueKey('priority-badge-fast')), findsOneWidget);
      expect(find.byKey(const ValueKey('age-chip-breached')), findsOneWidget);
      expect(_approveButton, findsOneWidget);
      expect(_rejectButton, findsOneWidget);
    });

    testWidgets(
      'an item with no preview text and no submitter says so and omits '
      'the submitter row',
      (tester) async {
        final item = _item(7);
        await _openReview(tester, _FakeModerationRepository([item]), item);

        expect(find.text('No preview available'), findsOneWidget);
        expect(find.text('Submitted by'), findsNothing);
      },
    );
  });

  group('approve', () {
    testWidgets(
      'approves the item, removes it from the queue, confirms with a '
      'snackbar and pops with true',
      (tester) async {
        final fake = _FakeModerationRepository([target, other]);
        final container = await _openReview(tester, fake, target);
        expect(_queueIds(container), [7, 8]);

        await tester.tap(_approveButton);
        await tester.pumpAndSettle();

        expect(fake.approvedIds, [7]);
        expect(_queueIds(container), [8]);
        expect(find.byType(ModerationReviewScreen), findsNothing);
        expect(find.text('result: true'), findsOneWidget);
        expect(find.text('Item approved'), findsOneWidget);
      },
    );

    testWidgets(
      'while the request is in flight both buttons are disabled and '
      'Approve shows a spinner',
      (tester) async {
        final gate = Completer<void>();
        final fake = _FakeModerationRepository([target])
          ..approveBehavior = () => gate.future;
        await _openReview(tester, fake, target);

        await tester.tap(_approveButton);
        await tester.pump();

        expect(tester.widget<AppButton>(_approveButton).isLoading, isTrue);
        expect(tester.widget<OutlinedButton>(_rejectButton).onPressed, isNull);
        expect(fake.approvedIds, [7]);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.byType(ModerationReviewScreen), findsNothing);
      },
    );

    testWidgets(
      'a failure keeps the screen and the queue untouched and shows the '
      'backend message',
      (tester) async {
        final fake = _FakeModerationRepository([target, other])
          ..approveBehavior = () => throw _dioFailure(
            500,
            const ServerFailure(message: 'Something went wrong.'),
          );
        final container = await _openReview(tester, fake, target);

        await tester.tap(_approveButton);
        await tester.pumpAndSettle();

        expect(find.byType(ModerationReviewScreen), findsOneWidget);
        expect(find.text('Something went wrong.'), findsOneWidget);
        expect(tester.widget<AppButton>(_approveButton).isLoading, isFalse);
        expect(_queueIds(container), [7, 8]);
      },
    );

    testWidgets(
      'a 403 explains the missing Moderator group instead of showing a '
      'raw permission error',
      (tester) async {
        final fake = _FakeModerationRepository([target])
          ..approveBehavior = () => throw _dioFailure(
            403,
            const AuthFailure(message: 'You do not have permission.'),
          );
        await _openReview(tester, fake, target);

        await tester.tap(_approveButton);
        await tester.pumpAndSettle();

        expect(find.textContaining('Moderator group'), findsOneWidget);
        expect(find.text('You do not have permission.'), findsNothing);
      },
    );

    testWidgets(
      'a 409 (already decided elsewhere) drops the item, leaves the '
      'screen with false and says why',
      (tester) async {
        final fake = _FakeModerationRepository([target, other])
          ..approveBehavior = () => throw _dioFailure(
            409,
            const UnknownFailure(message: 'Already decided.'),
          );
        final container = await _openReview(tester, fake, target);

        await tester.tap(_approveButton);
        await tester.pumpAndSettle();

        expect(find.byType(ModerationReviewScreen), findsNothing);
        expect(find.text('result: false'), findsOneWidget);
        expect(find.textContaining('already handled'), findsOneWidget);
        expect(_queueIds(container), [8]);
      },
    );
  });

  group('reject — reason is required before submitting', () {
    testWidgets('the dialog opens with the confirm button disabled', (
      tester,
    ) async {
      await _openReview(tester, _FakeModerationRepository([target]), target);
      await _openRejectDialog(tester);

      expect(find.text('Reject content'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);
      // No scolding before the moderator has typed anything.
      expect(find.byKey(const ValueKey('reject-reason-required')), findsNothing);
    });

    testWidgets(
      'a whitespace-only reason keeps it disabled and shows the '
      'validation message; a real reason enables it; clearing disables '
      'it again',
      (tester) async {
        final fake = _FakeModerationRepository([target]);
        await _openReview(tester, fake, target);
        await _openRejectDialog(tester);

        await tester.enterText(find.byType(TextFormField), '   ');
        await tester.pump();
        expect(_confirm(tester).onPressed, isNull);
        expect(
          find.byKey(const ValueKey('reject-reason-required')),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextFormField), 'Blurry photo');
        await tester.pump();
        expect(_confirm(tester).onPressed, isNotNull);
        expect(find.byKey(const ValueKey('reject-reason-required')), findsNothing);

        await tester.enterText(find.byType(TextFormField), '');
        await tester.pump();
        expect(_confirm(tester).onPressed, isNull);
        expect(
          find.byKey(const ValueKey('reject-reason-required')),
          findsOneWidget,
        );

        // Nothing was ever sent while the reason was blank.
        expect(fake.rejectedIds, isEmpty);
      },
    );

    testWidgets('Cancel closes the dialog without calling the backend', (
      tester,
    ) async {
      final fake = _FakeModerationRepository([target]);
      await _openReview(tester, fake, target);
      await _openRejectDialog(tester);

      await tester.tap(find.byKey(const ValueKey('reject-cancel-button')));
      await tester.pumpAndSettle();

      expect(find.text('Reject content'), findsNothing);
      expect(find.byType(ModerationReviewScreen), findsOneWidget);
      expect(fake.rejectedIds, isEmpty);
    });
  });

  group('reject — submitting', () {
    testWidgets(
      'sends the trimmed reason, removes the item, confirms with a '
      'snackbar and pops with true',
      (tester) async {
        final fake = _FakeModerationRepository([target, other]);
        final container = await _openReview(tester, fake, target);
        await _openRejectDialog(tester);

        await tester.enterText(find.byType(TextFormField), '  Blurry photo  ');
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(fake.rejectedIds, [7]);
        expect(fake.rejectReasons, ['Blurry photo']);
        expect(_queueIds(container), [8]);
        expect(find.byType(ModerationReviewScreen), findsNothing);
        expect(find.text('result: true'), findsOneWidget);
        expect(find.text('Item rejected'), findsOneWidget);
      },
    );

    testWidgets(
      'a failure keeps the dialog open with the typed reason and shows '
      'the error next to it',
      (tester) async {
        final fake = _FakeModerationRepository([target, other])
          ..rejectBehavior = () => throw _dioFailure(
            500,
            const ServerFailure(message: 'Something went wrong.'),
          );
        final container = await _openReview(tester, fake, target);
        await _openRejectDialog(tester);

        await tester.enterText(find.byType(TextFormField), 'Blurry photo');
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('Reject content'), findsOneWidget);
        expect(find.byKey(const ValueKey('reject-error')), findsOneWidget);
        expect(find.text('Something went wrong.'), findsOneWidget);
        // The reason survives, and the button is usable again.
        expect(find.text('Blurry photo'), findsOneWidget);
        expect(_confirm(tester).isLoading, isFalse);
        expect(_confirm(tester).onPressed, isNotNull);
        expect(_queueIds(container), [7, 8]);
        expect(find.byType(ModerationReviewScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a backend "reason" validation error is shown as the dialog error',
      (tester) async {
        final fake = _FakeModerationRepository([target])
          ..rejectBehavior = () => throw _dioFailure(
            400,
            const ValidationFailure(
              message: 'Invalid input',
              fields: {
                'reason': ['This field may not be blank.'],
              },
            ),
          );
        await _openReview(tester, fake, target);
        await _openRejectDialog(tester);

        await tester.enterText(find.byType(TextFormField), 'x');
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('This field may not be blank.'), findsOneWidget);
      },
    );

    testWidgets(
      'a 409 closes the dialog, drops the item, leaves the screen with '
      'false and says why',
      (tester) async {
        final fake = _FakeModerationRepository([target, other])
          ..rejectBehavior = () => throw _dioFailure(
            409,
            const UnknownFailure(message: 'Already decided.'),
          );
        final container = await _openReview(tester, fake, target);
        await _openRejectDialog(tester);

        await tester.enterText(find.byType(TextFormField), 'Blurry photo');
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('Reject content'), findsNothing);
        expect(find.byType(ModerationReviewScreen), findsNothing);
        expect(find.text('result: false'), findsOneWidget);
        expect(find.textContaining('already handled'), findsOneWidget);
        expect(_queueIds(container), [8]);
      },
    );
  });
}