import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/chat/presentation/message_bubble_widget.dart';
import 'package:social_commerce_app/features/chat/presentation/shared_content_card.dart';
import 'package:social_commerce_app/features/content/domain/public_post_entity.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/content_public_providers.dart';
import 'package:social_commerce_app/features/content/presentation/post_card.dart';
import 'package:social_commerce_app/features/content/presentation/reel_card.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';
import 'package:social_commerce_app/routing/route_names.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-077 STEP 3 — widget tests for rendering shared content inside
/// a chat bubble: PostCard / ReelCard reused, compact product card,
/// unavailable / loading / error states, and tap navigation to the
/// content's existing detail route.

// No imageUrl on purpose: PostCard would otherwise start a real
// Image.network request, and flutter_test answers every HTTP request
// with a 400 whose exception can land on an unrelated test.
const _post = PublicPost(
  id: 42,
  businessId: 7,
  caption: 'New summer collection',
);

const _reel = PublicReel(
  id: 9,
  businessId: 7,
  caption: 'Behind the scenes',
);

SharedContent _shared(
  SharedContentType type,
  int objectId, {
  bool available = true,
}) {
  return SharedContent(
    type: type,
    objectId: objectId,
    available: available,
    businessId: available ? 7 : null,
    businessName: available ? 'Al Anaqa Store' : null,
    previewText: available
        ? (type == SharedContentType.product
              ? 'Leather Jacket'
              : 'Preview text')
        : null,
    previewImageUrl: null,
  );
}

Message _message({String text = '', SharedContent? shared}) {
  return Message(
    id: 1,
    conversationId: 1,
    senderId: 1,
    text: text,
    status: MessageStatus.sent,
    createdAt: DateTime(2026, 1, 1, 9, 30),
    sharedContent: shared,
  );
}

/// Pumps a [MessageBubbleWidget] inside a real [GoRouter] whose detail
/// routes are stubs that print a marker, so navigation can be asserted.
/// The Post / Reel loaders stand in for the public repositories.
Future<void> _pump(
  WidgetTester tester,
  Message message, {
  Future<PublicPost?> Function()? postLoader,
  Future<PublicReel?> Function()? reelLoader,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: MessageBubbleWidget(message: message, isMine: false),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.postDetailPath,
        name: RouteNames.postDetail,
        builder: (context, state) => Scaffold(
          body: Text('POST_DETAIL_${state.pathParameters[RouteNames.idParam]}'),
        ),
      ),
      GoRoute(
        path: RouteNames.reelDetailPath,
        name: RouteNames.reelDetail,
        builder: (context, state) => Scaffold(
          body: Text('REEL_DETAIL_${state.pathParameters[RouteNames.idParam]}'),
        ),
      ),
      GoRoute(
        path: RouteNames.productDetailPath,
        name: RouteNames.productDetail,
        builder: (context, state) => Scaffold(
          body: Text(
            'PRODUCT_DETAIL_${state.pathParameters[RouteNames.idParam]}',
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialInteractionRepositoryProvider.overrideWithValue(
          FakeSocialInteractionRepository(),
        ),
        postPublicDetailProvider(
          42,
        ).overrideWith((ref) => (postLoader ?? () async => _post)()),
        reelPublicDetailProvider(
          9,
        ).overrideWith((ref) => (reelLoader ?? () async => _reel)()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('shared Post', () {
    testWidgets('renders the reused PostCard, the business name and the text', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(
          text: 'check this out!',
          shared: _shared(SharedContentType.post, 42),
        ),
      );

      expect(find.byType(PostCard), findsOneWidget);
      expect(find.text('Al Anaqa Store'), findsOneWidget);
      expect(find.text('New summer collection'), findsOneWidget);
      // The optional text travels with the card, in its own bubble.
      expect(find.text('check this out!'), findsOneWidget);
    });

    testWidgets('tapping the card opens the existing post detail route', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.post, 42)),
      );

      await tester.tap(find.text('New summer collection'));
      await tester.pumpAndSettle();

      expect(find.text('POST_DETAIL_42'), findsOneWidget);
    });

    testWidgets('while loading, a preview card is shown, then the PostCard', (
      tester,
    ) async {
      final completer = Completer<PublicPost?>();
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.post, 42)),
        postLoader: () => completer.future,
      );

      expect(
        find.byKey(const ValueKey('sharedContent_preview_post')),
        findsOneWidget,
      );
      expect(find.byType(PostCard), findsNothing);

      completer.complete(_post);
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sharedContent_preview_post')),
        findsNothing,
      );
    });

    testWidgets('a failed fetch falls back to a tappable preview card', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.post, 42)),
        postLoader: () async => throw Exception('boom'),
      );

      expect(
        find.byKey(const ValueKey('sharedContent_preview_post')),
        findsOneWidget,
      );
      expect(find.byType(PostCard), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sharedContent_preview_post')));
      await tester.pumpAndSettle();
      expect(find.text('POST_DETAIL_42'), findsOneWidget);
    });

    testWidgets('a post that no longer exists shows "unavailable"', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.post, 42)),
        postLoader: () async => null,
      );

      expect(
        find.byKey(const ValueKey('sharedContent_unavailable')),
        findsOneWidget,
      );
      expect(find.byType(PostCard), findsNothing);
    });
  });

  group('shared Reel', () {
    testWidgets('renders the reused ReelCard and opens the reel detail', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.reel, 9)),
      );

      expect(find.byType(ReelCard), findsOneWidget);
      expect(find.text('Behind the scenes'), findsOneWidget);

      await tester.tap(find.text('Behind the scenes'));
      await tester.pumpAndSettle();

      expect(find.text('REEL_DETAIL_9'), findsOneWidget);
    });
  });

  group('shared Product', () {
    testWidgets('renders the compact product card and opens the product', (
      tester,
    ) async {
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.product, 5)),
      );

      expect(
        find.byKey(const ValueKey('sharedContent_preview_product')),
        findsOneWidget,
      );
      expect(find.text('Leather Jacket'), findsOneWidget);
      expect(find.text('Al Anaqa Store'), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      expect(find.byType(ReelCard), findsNothing);

      await tester.tap(find.text('Leather Jacket'));
      await tester.pumpAndSettle();

      expect(find.text('PRODUCT_DETAIL_5'), findsOneWidget);
    });
  });

  group('unavailable / regression', () {
    testWidgets('available:false shows "unavailable" and never fetches', (
      tester,
    ) async {
      var fetches = 0;
      await _pump(
        tester,
        _message(shared: _shared(SharedContentType.post, 42, available: false)),
        postLoader: () async {
          fetches++;
          return _post;
        },
      );

      expect(
        find.byKey(const ValueKey('sharedContent_unavailable')),
        findsOneWidget,
      );
      expect(find.text('This content is no longer available'), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      expect(fetches, 0);
    });

    testWidgets('a plain text message has no shared-content card', (
      tester,
    ) async {
      await _pump(tester, _message(text: 'hello there'));

      expect(find.text('hello there'), findsOneWidget);
      expect(find.byType(SharedContentCard), findsNothing);
    });
  });
}