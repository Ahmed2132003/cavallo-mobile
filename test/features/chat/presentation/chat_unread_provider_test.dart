import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_unread_provider.dart';

/// Part P-113 (STEP 5): `chatUnreadCountProvider`.
///
/// Same fake style as `chat_list_screen_test.dart`: extend the concrete
/// repository and override the one method the provider calls. The `Dio()`
/// passed to `super` is never used.
class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository({this.counts = const <int>[], this.error})
    : super(Dio());

  final List<int> counts;
  final Object? error;
  int calls = 0;

  @override
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return PaginatedResponse<Conversation>(
      results: <Conversation>[
        for (int i = 0; i < counts.length; i++)
          Conversation(
            id: i + 1,
            otherParticipant: null,
            lastMessage: null,
            unreadCount: counts[i],
            createdAt: DateTime.utc(2026, 9, 28),
          ),
      ],
      next: null,
      previous: null,
    );
  }
}

Future<int> _read(ProviderContainer container) async {
  // autoDispose: keep it alive while the test reads it.
  final ProviderSubscription<AsyncValue<int>> keepAlive = container.listen(
    chatUnreadCountProvider,
    (AsyncValue<int>? previous, AsyncValue<int> next) {},
  );
  addTearDown(keepAlive.close);
  return container.read(chatUnreadCountProvider.future);
}

void main() {
  test('adds up the unread count of every conversation', () async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      counts: <int>[2, 0, 5],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(await _read(container), 7);
    expect(repository.calls, 1);
  });

  test('is 0 when there are no conversations', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await _read(container), 0);
  });

  test('is 0 (not an error) when the request fails', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(error: StateError('offline')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await _read(container), 0);
  });

  test('does not poll: one request until it is invalidated', () async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      counts: <int>[3],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(await _read(container), 3);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repository.calls, 1);

    container.invalidate(chatUnreadCountProvider);
    expect(await container.read(chatUnreadCountProvider.future), 3);
    expect(repository.calls, 2);
  });
}
