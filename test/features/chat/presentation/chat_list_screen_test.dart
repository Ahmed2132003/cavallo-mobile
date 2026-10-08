import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_avatar.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/message.dart';
import 'package:social_commerce_app/features/chat/domain/message_status.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_list_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-074 STEP 4 — widget tests for [ChatListScreen].
///
/// ### Why this fakes [ConversationRepository] itself, not `Dio`
/// Every other feature in this project (`ProductRepository`,
/// `FeedRepository`, ...) splits an abstract domain interface from its
/// concrete data-layer implementation specifically so presentation-layer
/// tests can override the *interface* provider with a hand-rolled fake
/// (see `product_list_screen_test.dart`'s `_FakeProductRepository`,
/// `home_feed_screen_test.dart`'s `_FakeFeedRepository`). STEP 2's own
/// doc comment on `conversation_repository.dart` flags that
/// `ConversationRepository` was built as this feature's first
/// repository, directly concrete (no separate abstract interface) —
/// there was no existing convention to copy at the time. Rather than
/// fake the `Dio` HTTP layer underneath it (which cannot deterministically
/// gate the "loading" state the way a `Completer` can, and would need an
/// `ErrorInterceptor` just to test the error path), this file extends
/// the concrete class and overrides its three public methods — legal
/// because `ConversationRepository` is a plain, non-`final`, non-`sealed`
/// class. The `Dio()` passed to `super(...)` is never actually used,
/// since every method [ChatListScreen] calls is overridden below.
class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository({List<Conversation> firstPage = const []})
    : currentConversations = List.of(firstPage),
      super(Dio());

  List<Conversation> currentConversations;
  String? nextCursor;

  /// When set, [listConversations] throws this instead of resolving.
  Object? error;

  /// When set, the FIRST [listConversations] call blocks on this instead
  /// of resolving — lets a test observe the initial loading state
  /// deterministically, same pattern as `home_feed_screen_test.dart`'s
  /// `_FakeFeedRepository.firstCallGate`.
  Completer<void>? firstCallGate;

  int callCount = 0;

  @override
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    callCount++;
    if (callCount == 1 && firstCallGate != null) {
      await firstCallGate!.future;
    }
    if (error != null) {
      throw error!;
    }
    return PaginatedResponse<Conversation>(
      results: List.of(currentConversations),
      next: nextCursor,
      previous: null,
    );
  }

  /// Not exercised by [ChatListScreen]'s own list-rendering — only its
  /// STEP 4 "New chat (test)" button calls this, which none of these
  /// tests exercise (that button's own manual-testing nature makes it
  /// unsuitable for an automated widget test: it depends on typing a
  /// real second test account's id). Throws so an accidental future call
  /// site here wouldn't fail silently.
  @override
  Future<int> startConversation({required int recipientId}) =>
      throw UnimplementedError(
        'Not exercised by these ChatListScreen list-rendering tests',
      );

  /// Not used by [ChatListScreen] at all (only by `ChatThreadScreen`).
  @override
  Future<PaginatedResponse<Message>> fetchMessageHistory(
    int conversationId, {
    String? cursor,
  }) => throw UnimplementedError('Not used by ChatListScreen');
}

Conversation _conversation({
  required int id,
  required String displayName,
  LastMessagePreview? lastMessage,
  int unreadCount = 0,
}) {
  return Conversation(
    id: id,
    otherParticipant: ConversationParticipantSummary(
      id: id + 100,
      accountType: 'business',
      displayName: displayName,
    ),
    lastMessage: lastMessage,
    unreadCount: unreadCount,
    createdAt: DateTime(2026, 9, 1, 9),
  );
}

LastMessagePreview _preview(
  String text, {
  MessageStatus status = MessageStatus.delivered,
  int senderId = 142,
  ChatMediaType? mediaType,
  SharedContentType? sharedContentType,
}) {
  return LastMessagePreview(
    id: 501,
    text: text,
    senderId: senderId,
    status: status,
    createdAt: DateTime(2026, 9, 20, 10),
    mediaType: mediaType,
    sharedContentType: sharedContentType,
  );
}

/// Pumps [ChatListScreen] with [conversationRepositoryProvider]
/// overridden to [repository]. Deliberately a plain [MaterialApp] — NOT
/// `MaterialApp.router`/`GoRouter` — same reasoning as
/// `product_list_screen_test.dart`: none of these tests tap a
/// conversation row (which would call `context.pushNamed` and need a
/// real router), only assert on what's rendered.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeConversationRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ChatListScreen()),
    ),
  );
}

void main() {
  group('ChatListScreen — loading', () {
    testWidgets('shows a loading indicator before the first page resolves', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
          ),
        ],
      )..firstCallGate = Completer<void>();

      await _pumpScreen(tester, repository: repository);
      await tester.pump();

      // P-115 STEP 2: the first load is a skeleton, not a spinner.
      expect(find.byType(AppShimmerBox), findsWidgets);
      expect(find.text('Acme Traders'), findsNothing);

      repository.firstCallGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AppShimmerBox), findsNothing);

      expect(find.text('Acme Traders'), findsOneWidget);
    });
  });

  group('ChatListScreen — empty', () {
    testWidgets('shows "No conversations yet" when the list is empty', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(firstPage: const []);

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet'), findsOneWidget);
    });
  });

  group('ChatListScreen — populated', () {
    testWidgets(
      "shows the other participant's display name and the last message "
      'preview text',
      (tester) async {
        final repository = _FakeConversationRepository(
          firstPage: [
            _conversation(
              id: 1,
              displayName: 'Acme Traders',
              lastMessage: _preview('Is this available?'),
            ),
          ],
        );

        await _pumpScreen(tester, repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Acme Traders'), findsOneWidget);
        expect(find.text('Is this available?'), findsOneWidget);
      },
    );

    testWidgets(
      'a conversation with no messages yet shows the "No messages yet" '
      'placeholder',
      (tester) async {
        final repository = _FakeConversationRepository(
          firstPage: [_conversation(id: 2, displayName: 'jane@example.com')],
        );

        await _pumpScreen(tester, repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('No messages yet'), findsOneWidget);
      },
    );

    testWidgets('shows an unread-count badge when unread_count > 0', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
            unreadCount: 3,
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      // P-115 STEP 2: one AppAvatar per row; the badge is a pill, not an avatar.
      expect(find.byType(AppAvatar), findsOneWidget);
    });

    testWidgets('shows no unread badge when unread_count is 0', (tester) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      // No unread-count badge: no count text in the row.
      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a very high unread count is capped at "99+"', (tester) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
            unreadCount: 150,
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('ChatListScreen — P-115 restyle', () {
    testWidgets('shows the Messages title', (tester) async {
      await _pumpScreen(
        tester,
        repository: _FakeConversationRepository(firstPage: const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('media-only and shared-only messages show a label', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'A',
            lastMessage: _preview('', mediaType: ChatMediaType.image),
          ),
          _conversation(
            id: 2,
            displayName: 'B',
            lastMessage: _preview('', mediaType: ChatMediaType.video),
          ),
          _conversation(
            id: 3,
            displayName: 'C',
            lastMessage: _preview(
              '',
              sharedContentType: SharedContentType.reel,
            ),
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Shared a reel'), findsOneWidget);
    });

    testWidgets('text wins over the media label', (tester) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'A',
            lastMessage: _preview('nice', mediaType: ChatMediaType.image),
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('nice'), findsOneWidget);
      expect(find.text('Photo'), findsNothing);
    });

    testWidgets('renders in dark theme and in Arabic RTL without errors', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        firstPage: [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
            unreadCount: 120,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ChatListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('الرسائل'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(ChatListScreen))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ChatListScreen — error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button; '
      'tapping Retry recovers',
      (tester) async {
        final repository = _FakeConversationRepository(firstPage: const [])
          ..error = const ServerFailure(message: 'Something broke.');

        await _pumpScreen(tester, repository: repository);
        await tester.pumpAndSettle();

        // P-115 STEP 2: the message is the localized one (P-112), not the raw
        // backend text, and the retry button is the shared AppButton.
        expect(
          find.text('Something went wrong on our end. Please try again later.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

        repository.error = null;
        repository.currentConversations = [
          _conversation(
            id: 1,
            displayName: 'Acme Traders',
            lastMessage: _preview('hi'),
          ),
        ];

        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Acme Traders'), findsOneWidget);
      },
    );
  });
}
