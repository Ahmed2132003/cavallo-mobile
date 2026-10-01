import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_console/data/analytics_repository.dart';
import 'package:social_commerce_app/features/business_console/domain/daily_stats_entity.dart';
import 'package:social_commerce_app/features/business_console/presentation/analytics_provider.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_profile_provider.dart';

/// Part P-085 scope. Hand-rolled fakes only (no mocking package), same as
/// the rest of the project: a fake [AnalyticsRepository] that records every
/// call, and a fake [BusinessProfileNotifier] controlling only the state.
class _FakeAnalyticsRepository implements AnalyticsRepository {
  _FakeAnalyticsRepository({this.rows = const [], this.error});

  List<DailyStats> rows;
  Object? error;
  final List<({int businessId, DateTime from, DateTime to})> calls = [];

  @override
  Future<List<DailyStats>> fetchDailyStats({
    required int businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    calls.add((businessId: businessId, from: from, to: to));
    final e = error;
    if (e != null) throw e;
    return rows;
  }
}

class _FakeBusinessProfileNotifier extends BusinessProfileNotifier {
  _FakeBusinessProfileNotifier(this._build);

  final Future<BusinessProfile?> Function() _build;

  @override
  Future<BusinessProfile?> build() => _build();
}

const _profile = BusinessProfile(
  id: 42,
  businessName: 'Test Co',
  businessType: BusinessType.trader,
  country: 'EG',
  city: 'Cairo',
  isVerified: false,
);

DailyStats _day(int day, {int followers = 0, int likes = 0}) => DailyStats(
  date: DateTime.utc(2026, 10, day),
  newFollowers: followers,
  totalLikesReceived: likes,
  totalCommentsReceived: 0,
  totalStoryViews: 0,
);

ProviderContainer _container({
  required _FakeAnalyticsRepository repository,
  Future<BusinessProfile?> Function()? profile,
  DateTime Function()? now,
}) {
  final container = ProviderContainer(
    overrides: [
      analyticsRepositoryProvider.overrideWithValue(repository),
      businessProfileProvider.overrideWith(
        () => _FakeBusinessProfileNotifier(profile ?? () async => _profile),
      ),
      analyticsNowProvider.overrideWithValue(
        now ?? () => DateTime.utc(2026, 10, 15, 12),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('analyticsRangeDaysProvider', () {
    test('defaults to 7', () {
      final container = _container(repository: _FakeAnalyticsRepository());

      expect(container.read(analyticsRangeDaysProvider), 7);
    });

    test('select() accepts 7, 14 and 30', () {
      final container = _container(repository: _FakeAnalyticsRepository());
      final notifier = container.read(analyticsRangeDaysProvider.notifier);

      for (final days in const [14, 30, 7]) {
        notifier.select(days);
        expect(container.read(analyticsRangeDaysProvider), days);
      }
    });

    test('select() rejects an unsupported period', () {
      final container = _container(repository: _FakeAnalyticsRepository());
      final notifier = container.read(analyticsRangeDaysProvider.notifier);

      expect(() => notifier.select(10), throwsArgumentError);
      expect(container.read(analyticsRangeDaysProvider), 7);
    });
  });

  group('analyticsStatsProvider', () {
    test('uses the business id from businessProfileProvider and a UTC '
        'range of today and the previous days-1 days', () async {
      final repository = _FakeAnalyticsRepository();
      final container = _container(repository: repository);

      await container.read(analyticsStatsProvider.future);

      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.businessId, 42);
      expect(repository.calls.single.to, DateTime.utc(2026, 10, 15));
      expect(repository.calls.single.from, DateTime.utc(2026, 10, 9));
    });

    test('"today" is the UTC date even when the device clock is in another '
        'zone', () async {
      final repository = _FakeAnalyticsRepository();
      // 2026-10-16 01:30 at UTC+3 is still 2026-10-15 22:30 UTC.
      final container = _container(
        repository: repository,
        now: () => DateTime.parse('2026-10-16T01:30:00+03:00'),
      );

      await container.read(analyticsStatsProvider.future);

      expect(repository.calls.single.to, DateTime.utc(2026, 10, 15));
    });

    test('returns rows ordered oldest first even if the repository does '
        'not', () async {
      final repository = _FakeAnalyticsRepository(
        rows: [_day(14, followers: 3), _day(10, followers: 1), _day(12)],
      );
      final container = _container(repository: repository);

      final stats = await container.read(analyticsStatsProvider.future);

      expect(stats.map((s) => s.date.day).toList(), [10, 12, 14]);
    });

    test('does not zero-fill: only returned rows come back', () async {
      final repository = _FakeAnalyticsRepository(rows: [_day(10), _day(14)]);
      final container = _container(repository: repository);

      final stats = await container.read(analyticsStatsProvider.future);

      expect(stats, hasLength(2));
    });

    test('an empty repository result stays an empty list (no error)', () async {
      final container = _container(repository: _FakeAnalyticsRepository());

      final stats = await container.read(analyticsStatsProvider.future);

      expect(stats, isEmpty);
    });

    test('changing the range re-requests with new dates', () async {
      final repository = _FakeAnalyticsRepository();
      final container = _container(repository: repository);
      // Keep the autoDispose provider alive across the range change.
      final subscription = container.listen(analyticsStatsProvider, (_, __) {});
      addTearDown(subscription.close);

      await container.read(analyticsStatsProvider.future);
      container.read(analyticsRangeDaysProvider.notifier).select(30);
      await container.read(analyticsStatsProvider.future);

      expect(repository.calls, hasLength(2));
      expect(repository.calls[0].from, DateTime.utc(2026, 10, 9));
      expect(repository.calls[1].from, DateTime.utc(2026, 9, 16));
      expect(repository.calls[1].to, DateTime.utc(2026, 10, 15));
    });

    test(
      'no business profile (null) is a clear error, not an empty list',
      () async {
        final repository = _FakeAnalyticsRepository();
        final container = _container(
          repository: repository,
          profile: () async => null,
        );
        final subscription = container.listen(
          analyticsStatsProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);

        await expectLater(
          container.read(analyticsStatsProvider.future),
          throwsA(isA<AnalyticsBusinessUnavailableException>()),
        );
        expect(repository.calls, isEmpty);
      },
    );

    test('a failing business profile load propagates as an error and no '
        'request is made', () async {
      final repository = _FakeAnalyticsRepository();
      final container = _container(
        repository: repository,
        profile: () async => throw StateError('profile failed'),
      );

      await expectLater(
        container.read(analyticsStatsProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(repository.calls, isEmpty);
    });

    test('a repository failure propagates as the provider error', () async {
      final repository = _FakeAnalyticsRepository(error: StateError('boom'));
      final container = _container(repository: repository);

      await expectLater(
        container.read(analyticsStatsProvider.future),
        throwsA(isA<StateError>()),
      );
    });

    test('invalidate() (the UI Retry) triggers a fresh request', () async {
      final repository = _FakeAnalyticsRepository(error: StateError('boom'));
      final container = _container(repository: repository);
      final subscription = container.listen(analyticsStatsProvider, (_, __) {});
      addTearDown(subscription.close);

      await expectLater(
        container.read(analyticsStatsProvider.future),
        throwsA(isA<StateError>()),
      );

      repository
        ..error = null
        ..rows = [_day(15, followers: 1)];
      container.invalidate(analyticsStatsProvider);
      final stats = await container.read(analyticsStatsProvider.future);

      expect(stats, hasLength(1));
      expect(repository.calls, hasLength(2));
    });
  });
}
