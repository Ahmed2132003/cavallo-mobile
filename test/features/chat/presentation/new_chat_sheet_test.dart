import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/features/chat/data/conversation_repository.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/followed_business.dart';
import 'package:social_commerce_app/features/chat/presentation/chat_list_screen.dart';
import 'package:social_commerce_app/features/chat/presentation/new_chat_sheet.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Widget tests for the "New chat" picker ([NewChatSheet]) and the
/// [ChatListScreen] button that opens it. Fakes [ConversationRepository]
/// itself (same approach as `chat_list_screen_test.dart`).
class _FakeRepository extends ConversationRepository {
  _FakeRepository({this.followed = const []}) : super(Dio());

  List<FollowedBusiness> followed;
  Object? followedError;

  @override
  Future<PaginatedResponse<FollowedBusiness>> listFollowedBusinesses({
    String? cursor,
  }) async {
    if (followedError != null) throw followedError!;
    return PaginatedResponse<FollowedBusiness>(
      results: List.of(followed),
      next: null,
      previous: null,
    );
  }

  @override
  Future<PaginatedResponse<Conversation>> listConversations({
    String? cursor,
  }) async => const PaginatedResponse<Conversation>(
    results: [],
    next: null,
    previous: null,
  );
}

FollowedBusiness _business(int id, String name) => FollowedBusiness(
  businessId: id,
  businessName: name,
  businessType: 'trader',
  city: 'Cairo',
  country: 'Egypt',
);

Widget _app(_FakeRepository repository, Widget home) {
  return ProviderScope(
    overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Pumps a button that opens the sheet and records what it resolved to.
Future<void> _pumpOpener(
  WidgetTester tester,
  _FakeRepository repository,
  void Function(FollowedBusiness?) onResult,
) async {
  await tester.pumpWidget(
    _app(
      repository,
      Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed:
                      () async => onResult(await showNewChatSheet(context)),
                  child: const Text('open'),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('NewChatSheet', () {
    testWidgets('lists the followed businesses with a localized subtitle', (
      tester,
    ) async {
      final repository = _FakeRepository(
        followed: [_business(1, 'Nile Textiles'), _business(2, 'Delta Foods')],
      );

      await _pumpOpener(tester, repository, (_) {});

      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Nile Textiles'), findsOneWidget);
      expect(find.text('Delta Foods'), findsOneWidget);
      expect(find.text('Trader · Cairo, Egypt'), findsNWidgets(2));
    });

    testWidgets('tapping a business resolves the sheet with it', (
      tester,
    ) async {
      final repository = _FakeRepository(
        followed: [_business(1, 'Nile Textiles'), _business(2, 'Delta Foods')],
      );
      FollowedBusiness? picked;

      await _pumpOpener(tester, repository, (b) => picked = b);
      await tester.tap(find.text('Delta Foods'));
      await tester.pumpAndSettle();

      expect(picked?.businessId, 2);
      expect(find.text('Nile Textiles'), findsNothing);
    });

    testWidgets('shows a friendly empty state when following nobody', (
      tester,
    ) async {
      await _pumpOpener(tester, _FakeRepository(), (_) {});

      expect(
        find.textContaining('You are not following any business yet'),
        findsOneWidget,
      );
    });

    testWidgets('shows an error state when loading fails', (tester) async {
      final repository =
          _FakeRepository()
            ..followedError = const ServerFailure(message: 'Something broke.');

      await _pumpOpener(tester, repository, (_) {});

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Nile Textiles'), findsNothing);
      expect(
        find.textContaining('You are not following any business yet'),
        findsNothing,
      );
    });
  });

  group('ChatListScreen — New chat button', () {
    testWidgets('is labelled "New chat" (no "(test)") and opens the picker', (
      tester,
    ) async {
      final repository = _FakeRepository(
        followed: [_business(1, 'Nile Textiles')],
      );

      await tester.pumpWidget(_app(repository, const ChatListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New chat (test)'), findsNothing);
      expect(find.text('New chat'), findsOneWidget);

      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();

      expect(find.text('Nile Textiles'), findsOneWidget);
    });
  });
}
