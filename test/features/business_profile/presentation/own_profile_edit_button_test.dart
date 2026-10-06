import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_business_id_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_profile_edit_button.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-113 (STEP 4B): the owner's Edit action on the public Business
/// profile, and the provider that decides who the owner is.

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user);

  final User? _user;

  @override
  Future<User?> build() async => _user;
}

class _FakeProfileNotifier extends BusinessProfileNotifier {
  _FakeProfileNotifier(this._profile);

  final BusinessProfile? _profile;

  @override
  Future<BusinessProfile?> build() async => _profile;
}

const User _customer = User(
  id: 1,
  email: 'customer@example.com',
  accountType: AccountType.customer,
  isModerator: false,
  isStaff: false,
);

const User _business = User(
  id: 2,
  email: 'business@example.com',
  accountType: AccountType.business,
  isModerator: false,
  isStaff: false,
);

BusinessProfile _profile(int id) {
  return BusinessProfile(
    id: id,
    businessName: 'Roots Atelier',
    businessType: BusinessType.trader,
    country: 'EG',
    city: 'Cairo',
    isVerified: false,
    isFeatured: false,
  );
}

GoRouter _router(int shownBusinessId) {
  return GoRouter(
    initialLocation: '/host',
    routes: <RouteBase>[
      GoRoute(
        path: '/host',
        builder:
            (BuildContext context, GoRouterState state) => Scaffold(
              appBar: AppBar(
                title: const Text('host'),
                actions: <Widget>[
                  OwnProfileEditButton(businessId: shownBusinessId),
                ],
              ),
            ),
      ),
      GoRoute(
        path: RouteNames.businessProfileEditPath,
        name: RouteNames.businessProfileEdit,
        builder:
            (BuildContext context, GoRouterState state) => const Scaffold(
              body: Center(child: Text('stub:businessProfileEdit')),
            ),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required int? ownId,
  required int shownBusinessId,
}) async {
  final GoRouter router = _router(shownBusinessId);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ownBusinessIdProvider.overrideWithValue(ownId)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int?> _ownId(
  User? user,
  BusinessProfile? profile,
) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(user)),
      businessProfileProvider.overrideWith(() => _FakeProfileNotifier(profile)),
    ],
  );
  addTearDown(container.dispose);
  final ProviderSubscription<int?> subscription = container.listen<int?>(
    ownBusinessIdProvider,
    (int? previous, int? next) {},
  );
  addTearDown(subscription.close);
  await container.read(sessionProvider.future);
  await container.read(businessProfileProvider.future);
  return container.read(ownBusinessIdProvider);
}

void main() {
  group('P-113 STEP 4B: OwnProfileEditButton', () {
    testWidgets('the owner sees Edit, and it opens the edit screen', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: 5, shownBusinessId: 5);

      expect(find.byKey(OwnProfileEditButton.buttonKey), findsOneWidget);
      expect(find.byTooltip('Edit business profile'), findsOneWidget);

      await tester.tap(find.byKey(OwnProfileEditButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text('stub:businessProfileEdit'), findsOneWidget);
    });

    testWidgets('someone looking at ANOTHER business sees no Edit', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: 5, shownBusinessId: 6);
      expect(find.byKey(OwnProfileEditButton.buttonKey), findsNothing);
    });

    testWidgets('a user with no own business sees no Edit', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ownId: null, shownBusinessId: 5);
      expect(find.byKey(OwnProfileEditButton.buttonKey), findsNothing);
    });
  });

  group('P-113 STEP 4B: ownBusinessIdProvider', () {
    test('a Business account with a profile: its business id', () async {
      expect(await _ownId(_business, _profile(7)), 7);
    });

    test('a Business account without a profile yet: null', () async {
      expect(await _ownId(_business, null), isNull);
    });

    test('a Customer account: null, whatever the profile provider holds', () async {
      expect(await _ownId(_customer, _profile(7)), isNull);
    });

    test('nobody signed in: null', () async {
      expect(await _ownId(null, null), isNull);
    });
  });
}
