import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/features/business_console/presentation/content_analytics_detail_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

import '../bi_fixtures.dart';
import '../fake_business_analytics_repository.dart';
import 'bi_test_harness.dart';

/// Part BI-04: analytics of ONE post or reel. Internal (in-app) numbers and
/// external (platform) numbers are two separate blocks. External numbers are
/// manual today and are never labelled live.
const String _dash = '—';

FakeBusinessAnalyticsRepository _repoWithExternal(
  List<Map<String, dynamic>> metrics,
) =>
    biFullRepository()
      ..contentDetail = biContentDetail(
        biContentDetailJson(externalMetrics: metrics),
      )
      ..externalMetrics = biExternalMetrics(
        biExternalMetricsJson(metrics: metrics),
      );

void main() {
  const Widget screen = ContentAnalyticsDetailScreen(
    contentType: 'post',
    contentId: 5,
  );

  group('loaded', () {
    testWidgets('requests the content of the signed-in business', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo = biFullRepository();

      await pumpBi(tester, repository: repo, home: screen);

      expect(repo.contentDetailCalls, hasLength(1));
      expect(repo.contentDetailCalls.single.businessId, 42);
      expect(repo.contentDetailCalls.single.contentType, 'post');
      expect(repo.contentDetailCalls.single.contentId, 5);
      expect(find.text('Summer sale'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('internal and external are separate blocks with their notes', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: screen);

      expect(find.text(l10n.analyticsContentInternalTitle), findsOneWidget);
      expect(find.text(l10n.analyticsContentExternalTitle), findsOneWidget);
      expect(find.text(l10n.analyticsContentInAppNote), findsOneWidget);
      expect(find.text(l10n.analyticsContentExternalNote), findsOneWidget);
    });

    testWidgets('a manual external number is badged Manual, never Synced', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: screen);

      expect(find.text(l10n.analyticsExternalBadgeManual), findsWidgets);
      expect(find.text(l10n.analyticsExternalBadgeSynced), findsNothing);
      expect(find.text(l10n.analyticsExternalPlatformInstagram), findsWidgets);
    });

    testWidgets('only an explicit synced source gets the Synced badge', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = _repoWithExternal(
        <Map<String, dynamic>>[
          biExternalMetricJson(source: 'synced', metricType: 'likes'),
        ],
      );

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsExternalBadgeSynced), findsWidgets);
      expect(find.text(l10n.analyticsExternalBadgeManual), findsNothing);
    });

    testWidgets('no external numbers: the empty message', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = _repoWithExternal(
        <Map<String, dynamic>>[],
      );

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsExternalEmpty), findsWidgets);
    });

    testWidgets('a content item without a caption says so', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final Map<String, dynamic> json = biContentDetailJson();
      (json['content'] as Map<String, dynamic>)['caption_preview'] = '';
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()..contentDetail = biContentDetail(json);

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsContentNoCaption), findsWidgets);
    });

    testWidgets('null internal numbers show a dash', (
      WidgetTester tester,
    ) async {
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..contentDetail = biContentDetail(
              biContentDetailJson(
                totals: biContentMetricsJson(
                  views: null,
                  uniqueViews: null,
                  likes: null,
                  comments: null,
                  saves: null,
                  inAppShares: null,
                  engagementRate: null,
                ),
                trend: <Map<String, dynamic>>[],
              ),
            );

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(_dash), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Add or update numbers" opens the manual-entry sheet', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');

      await pumpBi(tester, repository: biFullRepository(), home: screen);
      await tester.ensureVisible(find.text(l10n.analyticsExternalAddUpdate));
      await tester.tap(find.text(l10n.analyticsExternalAddUpdate));
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsExternalFormTitle), findsOneWidget);
      expect(find.text(l10n.analyticsExternalFormNote), findsOneWidget);
      expect(find.text(l10n.analyticsExternalPlatformTiktok), findsWidgets);
    });
  });

  group('states', () {
    testWidgets('loading keeps a request pending and shows no data', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()..gate = Completer<void>();

      await pumpBi(tester, repository: repo, home: screen, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.count('contentDetail'), 1);
      expect(find.text(l10n.analyticsContentInternalTitle), findsNothing);
      expect(find.text(l10n.analyticsContentLoadError), findsNothing);

      repo.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsContentInternalTitle), findsOneWidget);
    });

    testWidgets('error shows the load-error message', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo =
          biFullRepository()
            ..errors['contentDetail'] = const UnknownFailure(message: 'boom');

      await pumpBi(tester, repository: repo, home: screen);

      expect(find.text(l10n.analyticsContentLoadError), findsWidgets);
      expect(find.text(l10n.analyticsContentInternalTitle), findsNothing);
    });

    testWidgets('no business profile: says so and sends no request', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await biL10n('en');
      final FakeBusinessAnalyticsRepository repo = biFullRepository();

      await pumpBi(
        tester,
        repository: repo,
        home: screen,
        hasBusiness: false,
      );

      expect(find.text(l10n.analyticsProdNoBusiness), findsWidgets);
      expect(repo.calls, isEmpty);
    });
  });

  group('language and theme', () {
    for (final String language in <String>['en', 'ar']) {
      for (final Brightness brightness in Brightness.values) {
        testWidgets('renders: $language / ${brightness.name}', (
          WidgetTester tester,
        ) async {
          final AppLocalizations l10n = await biL10n(language);

          await pumpBi(
            tester,
            repository: biFullRepository(),
            home: screen,
            locale: Locale(language),
            brightness: brightness,
          );

          expect(
            find.text(l10n.analyticsContentInternalTitle),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}