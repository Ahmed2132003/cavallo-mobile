import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/products/data/product_public_repository.dart';
import 'package:social_commerce_app/features/products/domain/product_entity.dart';
import 'package:social_commerce_app/features/products/domain/product_public_repository.dart';
import 'package:social_commerce_app/features/products/presentation/product_detail_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-077 STEP 5B — the final proof that the "Message Business"
/// stub (deliberately inert since Part P-034) is genuinely complete:
/// tapping it starts / resumes a real conversation with THIS product's
/// business and navigates into the thread, with loading, double-tap and
/// failure handling.

class _FakeProductPublicRepository implements ProductPublicRepository {
  @override
  Future<Product?> fetchPublicProduct(int id) async => _product;

  @override
  Future<PaginatedResponse<Product>> fetchBusinessProducts(int businessId) {
    throw UnimplementedError('not used by ProductDetailScreen');
  }
}

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository() : super(Dio());

  Completer<void>? gate;
  Object? errorToThrow;
  Conversation? result;
  final List<int> startedBusinessIds = [];

  @override
  Future<Conversation?> startConversationWithBusiness({
    required int businessId,
  }) async {
    startedBusinessIds.add(businessId);
    final pending = gate;
    if (pending != null) await pending.future;
    final error = errorToThrow;
    if (error != null) throw error;
    return result;
  }
}

const _product = Product(
  id: 10,
  businessId: 7,
  categoryId: 3,
  name: 'Cotton T-Shirt',
  description: 'Plain white cotton t-shirt.',
  price: '199.99',
  currency: Currency.egp,
);

Conversation _conversation() => Conversation(
  id: 5,
  otherParticipant: const ConversationParticipantSummary(
    id: 70,
    accountType: 'business',
    displayName: 'Al Anaqa Store',
  ),
  lastMessage: null,
  unreadCount: 0,
  createdAt: DateTime(2026, 1, 1),
);

Finder get _messageButton => find.byType(AppButton);

/// Hosts the real [ProductDetailScreen] on '/', with a stub `chatThread`
/// route that prints `THREAD_<id>` and records the `extra` it received.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeConversationRepository conversations,
  required List<Object?> openedExtras,
}) async {
  // Tall enough that the whole product page (including the "Message
  // Business" button at the bottom of the scroll view) is on screen —
  // the default 800x600 test surface would leave it off-screen and
  // every tap would miss.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ProductDetailScreen(productId: '10'),
      ),
      GoRoute(
        path: RouteNames.chatThreadPath,
        name: RouteNames.chatThread,
        builder: (context, state) {
          openedExtras.add(state.extra);
          return Scaffold(
            body: Text('THREAD_${state.pathParameters[RouteNames.idParam]}'),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productPublicRepositoryProvider.overrideWithValue(
          _FakeProductPublicRepository(),
        ),
        conversationRepositoryProvider.overrideWithValue(conversations),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FakeConversationRepository conversations;
  late List<Object?> openedExtras;

  setUp(() {
    conversations = _FakeConversationRepository()..result = _conversation();
    openedExtras = [];
  });

  testWidgets('tapping "Message Business" starts the conversation with THIS '
      "product's business and opens its thread", (tester) async {
    await _pump(tester, conversations: conversations, openedExtras: openedExtras);

    await tester.tap(find.widgetWithText(AppButton, 'Message Business'));
    await tester.pumpAndSettle();

    expect(conversations.startedBusinessIds, [7]);
    expect(find.text('THREAD_5'), findsOneWidget);

    final extra = openedExtras.single;
    expect(extra, isA<Conversation>());
    expect((extra! as Conversation).id, 5);
    expect(
      (extra as Conversation).otherParticipant!.displayName,
      'Al Anaqa Store',
    );
  });

  testWidgets('while starting: spinner shown, a second tap is ignored', (
    tester,
  ) async {
    conversations.gate = Completer<void>();
    await _pump(tester, conversations: conversations, openedExtras: openedExtras);

    await tester.tap(find.widgetWithText(AppButton, 'Message Business'));
    await tester.pump();

    expect(tester.widget<AppButton>(_messageButton).isLoading, isTrue);
    expect(
      find.descendant(
        of: _messageButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(_messageButton, warnIfMissed: false);
    await tester.pump();
    expect(conversations.startedBusinessIds, hasLength(1));

    conversations.gate!.complete();
    await tester.pumpAndSettle();

    expect(conversations.startedBusinessIds, hasLength(1));
    expect(find.text('THREAD_5'), findsOneWidget);
  });

  testWidgets('a failure shows the message, re-enables the button and '
      'navigates nowhere', (tester) async {
    conversations.errorToThrow = const ValidationFailure(
      message: 'Cannot start a conversation with yourself.',
      fields: {},
    );
    await _pump(tester, conversations: conversations, openedExtras: openedExtras);

    await tester.tap(find.widgetWithText(AppButton, 'Message Business'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Cannot start a conversation with yourself.'),
      findsOneWidget,
    );
    expect(tester.widget<AppButton>(_messageButton).isLoading, isFalse);
    expect(find.textContaining('THREAD_'), findsNothing);
    expect(openedExtras, isEmpty);
  });

  testWidgets('a started conversation missing from the list opens no thread', (
    tester,
  ) async {
    conversations.result = null;
    await _pump(tester, conversations: conversations, openedExtras: openedExtras);

    await tester.tap(find.widgetWithText(AppButton, 'Message Business'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Conversation started. Open it from Messages.'),
      findsOneWidget,
    );
    expect(find.textContaining('THREAD_'), findsNothing);
    expect(openedExtras, isEmpty);
  });
}