import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/feed/presentation/home_screen.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-040 scope: the temporary "Moderation queue (debug)" entry on
/// the placeholder Home screen. These only prove WHEN the button is
/// offered and that it navigates; they do not prove access control — the
/// route's real gate lives in `app_router.dart` and is tested by
/// `test/routing/moderation_router_gate_test.dart`.
///
/// [sessionProvider] is overridden with a fake notifier resolving
/// immediately to a fixed user, same approach as the router tests.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._fixedValue);

  final User? _fixedValue;

  @override
  Future<User?> build() async => _fixedValue;
}

User _user({bool isModerator = false, bool isStaff = false}) {
  return User(
    id: 1,
    email: 'user@example.com',
    accountType: AccountType.customer,
    isModerator: isModerator,
    isStaff: isStaff,
  );
}

/// A tiny [GoRouter] with just Home and a placeholder for the moderation
/// route, so the button's `pushNamed` has somewhere to go without pulling
/// in the real router (and its redirect guard).
Future<void> _pumpHome(WidgetTester tester, User user) async {
  final router = GoRouter(
    initialLocation: RouteNames.homePath,
    routes: [
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.moderationPath,
        name: RouteNames.moderation,
        builder: (context, state) =>
            const Scaffold(body: Text('MODERATION_PLACEHOLDER')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSessionNotifier(user)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _moderationButton =>
    find.widgetWithText(AppButton, 'Moderation queue (debug)');

void main() {
  group('HomeScreen — moderation entry (Part P-040)', () {
    testWidgets('a plain user does not see the button', (tester) async {
      await _pumpHome(tester, _user());

      expect(_moderationButton, findsNothing);
    });

    testWidgets('a user with isModerator sees the button', (tester) async {
      await _pumpHome(tester, _user(isModerator: true));

      expect(_moderationButton, findsOneWidget);
    });

    testWidgets('a user with isStaff sees the button', (tester) async {
      await _pumpHome(tester, _user(isStaff: true));

      expect(_moderationButton, findsOneWidget);
    });

    testWidgets('tapping the button navigates to the moderation route', (
      tester,
    ) async {
      await _pumpHome(tester, _user(isModerator: true));

      await tester.tap(_moderationButton);
      await tester.pumpAndSettle();

      expect(find.text('MODERATION_PLACEHOLDER'), findsOneWidget);
    });
  });
}