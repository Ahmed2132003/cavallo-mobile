import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_commerce_app/features/business_console/data/business_analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_content.dart';
import 'package:social_commerce_app/features/business_console/domain/analytics_products.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/own_business_id_provider.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../bi_fixtures.dart';
import '../fake_business_analytics_repository.dart';

/// Part BI-04 (tests): shared setup of the dashboard / detail widget tests.
///
/// Only the network edge is faked ([FakeBusinessAnalyticsRepository]); the real
/// screens and the real providers run above it. The business id is supplied
/// through BOTH `businessProfileProvider` and `ownBusinessIdProvider`, so the
/// test works whichever of the two the analytics providers read.

const BusinessProfile biProfile = BusinessProfile(
  id: 42,
  businessName: 'Test Co',
  businessType: BusinessType.trader,
  country: 'EG',
  city: 'Cairo',
  isVerified: false,
);

class _FakeProfileNotifier extends BusinessProfileNotifier {
  _FakeProfileNotifier(this._profile);

  final BusinessProfile? _profile;

  @override
  Future<BusinessProfile?> build() async => _profile;
}

/// The real generated localizations of [languageCode] (`en` or `ar`), so a
/// test asserts the same text the screen renders.
Future<AppLocalizations> biL10n([String languageCode = 'en']) =>
    AppLocalizations.delegate.load(Locale(languageCode));

/// A repository that answers every endpoint with sample data.
FakeBusinessAnalyticsRepository biFullRepository() =>
    FakeBusinessAnalyticsRepository(
      overview: biOverview(),
      productsPages: <ProductsPage>[biProductsPage()],
      productDetail: biProductDetail(),
      contentPages: <ContentPage>[biContentPage()],
      contentDetail: biContentDetail(),
      externalMetrics: biExternalMetrics(),
      ordersSummary: biOrdersSummary(),
    );

/// Pumps [home] (or a [router]) inside the real provider scope.
///
/// [settle] false pumps a single frame (used to look at the loading state).
Future<void> pumpBi(
  WidgetTester tester, {
  required FakeBusinessAnalyticsRepository repository,
  Widget? home,
  GoRouter? router,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool hasBusiness = true,
  bool settle = true,
}) async {
  assert(
    (home == null) != (router == null),
    'Pass exactly one of home / router.',
  );
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final ThemeData theme = ThemeData(brightness: brightness, useMaterial3: true);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessAnalyticsRepositoryProvider.overrideWithValue(repository),
        businessProfileProvider.overrideWith(
          () => _FakeProfileNotifier(hasBusiness ? biProfile : null),
        ),
        ownBusinessIdProvider.overrideWith((ref) => hasBusiness ? 42 : null),
        analyticsNowProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 15, 12),
        ),
      ],
      child:
          router == null
              ? MaterialApp(
                theme: theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: home,
              )
              : MaterialApp.router(
                theme: theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Taps the dashboard tab [name]: overview | products | orders | content |
/// external (keys `bi-tab-<name>`).
Future<void> openBiTab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey<String>('bi-tab-$name')));
  await tester.pumpAndSettle();
}

/// All six order statuses with 0 orders.
List<Map<String, dynamic>> biZeroStatuses() => <Map<String, dynamic>>[
  for (final String status in <String>[
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  ])
    <String, dynamic>{'status': status, 'orders': 0},
];
