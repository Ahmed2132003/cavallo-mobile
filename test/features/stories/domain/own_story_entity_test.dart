import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';

OwnStory _story({required OwnStoryStatus status, required DateTime expiresAt}) {
  return OwnStory(
    id: 1,
    businessId: 7,
    mediaUrl: 'https://cdn.example.com/stories/1.png',
    status: status,
    publishedAt: expiresAt.subtract(const Duration(hours: 24)),
    expiresAt: expiresAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 30, 12);
  final future = now.add(const Duration(hours: 5, minutes: 30));
  final past = now.subtract(const Duration(minutes: 1));

  test(
    'OwnStoryStatus.fromWire maps real values and falls back to unknown',
    () {
      expect(
        OwnStoryStatus.fromWire('pending_review'),
        OwnStoryStatus.pendingReview,
      );
      expect(OwnStoryStatus.fromWire('published'), OwnStoryStatus.published);
      expect(OwnStoryStatus.fromWire('rejected'), OwnStoryStatus.rejected);
      expect(OwnStoryStatus.fromWire('approved'), OwnStoryStatus.unknown);
      expect(OwnStoryStatus.fromWire(null), OwnStoryStatus.unknown);
    },
  );

  group('displayStatus', () {
    test('published and not yet expired is published', () {
      final s = _story(status: OwnStoryStatus.published, expiresAt: future);
      expect(s.displayStatus(now), OwnStoryDisplayStatus.published);
    });

    test('published at or after expires_at is expired', () {
      final atBoundary = _story(
        status: OwnStoryStatus.published,
        expiresAt: now,
      );
      final after = _story(status: OwnStoryStatus.published, expiresAt: past);
      expect(atBoundary.displayStatus(now), OwnStoryDisplayStatus.expired);
      expect(after.displayStatus(now), OwnStoryDisplayStatus.expired);
    });

    test('pending_review and not yet expired is pending', () {
      final s = _story(status: OwnStoryStatus.pendingReview, expiresAt: future);
      expect(s.displayStatus(now), OwnStoryDisplayStatus.pending);
    });

    test('pending_review past expires_at is expired', () {
      final s = _story(status: OwnStoryStatus.pendingReview, expiresAt: past);
      expect(s.displayStatus(now), OwnStoryDisplayStatus.expired);
    });

    test('rejected stays rejected even after expires_at', () {
      final s = _story(status: OwnStoryStatus.rejected, expiresAt: past);
      expect(s.displayStatus(now), OwnStoryDisplayStatus.rejected);
    });

    test('unknown status stays unknown', () {
      final s = _story(status: OwnStoryStatus.unknown, expiresAt: future);
      expect(s.displayStatus(now), OwnStoryDisplayStatus.unknown);
    });
  });

  group('remaining', () {
    test('published and not yet expired returns the time left', () {
      final s = _story(status: OwnStoryStatus.published, expiresAt: future);
      expect(s.remaining(now), const Duration(hours: 5, minutes: 30));
    });

    test('pending and rejected have no countdown', () {
      final pending = _story(
        status: OwnStoryStatus.pendingReview,
        expiresAt: future,
      );
      final rejected = _story(
        status: OwnStoryStatus.rejected,
        expiresAt: future,
      );
      expect(pending.remaining(now), isNull);
      expect(rejected.remaining(now), isNull);
    });

    test('an expired published story has no countdown', () {
      final s = _story(status: OwnStoryStatus.published, expiresAt: past);
      expect(s.remaining(now), isNull);
    });
  });
}
