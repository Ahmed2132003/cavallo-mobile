import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/content/data/post_public_repository.dart';
import 'package:social_commerce_app/features/content/data/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/presentation/post_detail_screen.dart';
import 'package:social_commerce_app/features/content/presentation/reel_detail_screen.dart';
import 'package:social_commerce_app/features/notifications/presentation/notification_navigator.dart';

/// Part P-095: pins two OPEN DEFECTS found by the deep-link sweep.
///
/// The backend (see notifications/tests/test_deep_link_sweep.py) stores the
/// right deep link for moderation decisions and serves the exact Post/Reel
/// plus its `rejection_reason`. But `/post/:id` and `/reel/:id` are the
/// PUBLIC detail screens, and their repositories return null (rendered as
/// "not found") for anything that is not publicly visible:
///
/// * D-1: a REJECTED Post/Reel -> the owner who taps the
///   `moderation_rejected` notification lands on "not found" and never sees
///   the rejection reason.
/// * D-2: an APPROVED Reel whose `processing_status` is not yet `ready` ->
///   the owner who taps the `moderation_approved` notification lands on
///   "not found".
///
/// These are CHARACTERIZATION tests of the current behaviour, on purpose:
/// the REAL repositories run over a fake Dio, so the whole chain
/// (navigator -> resolveDeepLink -> real screen -> real repository) is
/// exercised. When the defects are fixed (an owner-facing view of
/// unpublished content), these assertions must be flipped to expect the
/// content and the rejection reason instead of the not-found text.
class _NoConversationRepository extends ConversationRepository {
  _NoConversationRepository() : super(Dio());
}

class _Harness {
  _Harness({required this.navigator, required this.requestedPaths});

  final NotificationNavigator navigator;

  /// Every API path the real repositories asked the (fake) backend for.
  final List<String> requestedPaths;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> backendJson,
}) async {
  final requestedPaths = <String>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPaths.add(options.path);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: backendJson,
          ),
        );
      },
    ),
  );

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const Text('screen: notifications'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('screen: home'),
      ),
      GoRoute(
        path: '/post/:id',
        builder:
            (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reel/:id',
        builder:
            (context, state) =>
                ReelDetailScreen(reelId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  final navigator = NotificationNavigator(
    router: router,
    conversationRepository: _NoConversationRepository(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postPublicRepositoryProvider.overrideWithValue(
          PostPublicRepositoryImpl(dio: dio),
        ),
        reelPublicRepositoryProvider.overrideWithValue(
          ReelPublicRepositoryImpl(dio: dio),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('screen: notifications'), findsOneWidget);

  return _Harness(navigator: navigator, requestedPaths: requestedPaths);
}

void main() {
  group('OPEN DEFECT D-1 - rejected content opens "not found"', () {
    testWidgets('moderation_rejected + post_detail: owner never sees the '
        'rejection reason', (tester) async {
      final harness = await _pump(
        tester,
        backendJson: <String, dynamic>{
          'id': 501,
          'status': 'rejected',
          'rejection_reason': 'Blurry image',
          'caption': 'My rejected post',
        },
      );

      await harness.navigator.open(deepLinkType: 'post_detail', targetId: 501);
      await tester.pumpAndSettle();

      // The screen asked the backend for EXACTLY the notified Post...
      expect(harness.requestedPaths, ['/api/v1/posts/501/']);
      // ...the backend returned the rejected Post with its reason, but the
      // public screen shows "not found" and hides the reason (the defect).
      expect(
        find.text('Post not found.\nIt may have been removed.'),
        findsOneWidget,
      );
      expect(find.textContaining('Blurry image'), findsNothing);
      expect(find.text('My rejected post'), findsNothing);
    });

    testWidgets('moderation_rejected + reel_detail: owner never sees the '
        'rejection reason', (tester) async {
      final harness = await _pump(
        tester,
        backendJson: <String, dynamic>{
          'id': 77,
          'status': 'rejected',
          'processing_status': 'ready',
          'rejection_reason': 'Not allowed',
          'caption': 'My rejected reel',
        },
      );

      await harness.navigator.open(deepLinkType: 'reel_detail', targetId: 77);
      await tester.pumpAndSettle();

      expect(harness.requestedPaths, ['/api/v1/reels/77/']);
      expect(
        find.text('Reel not found.\nIt may have been removed.'),
        findsOneWidget,
      );
      expect(find.textContaining('Not allowed'), findsNothing);
    });
  });

  group('OPEN DEFECT D-2 - approved but not yet processed Reel', () {
    testWidgets('moderation_approved + reel_detail while processing_status '
        'is not ready opens "not found"', (tester) async {
      final harness = await _pump(
        tester,
        backendJson: <String, dynamic>{
          'id': 78,
          'status': 'published',
          'processing_status': 'uploaded',
          'caption': 'Approved, still transcoding',
        },
      );

      await harness.navigator.open(deepLinkType: 'reel_detail', targetId: 78);
      await tester.pumpAndSettle();

      expect(harness.requestedPaths, ['/api/v1/reels/78/']);
      expect(
        find.text('Reel not found.\nIt may have been removed.'),
        findsOneWidget,
      );
      expect(find.text('Approved, still transcoding'), findsNothing);
    });
  });
}