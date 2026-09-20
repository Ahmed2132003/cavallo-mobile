import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/moderation/data/dtos/queue_item_response_dto.dart';
import 'package:social_commerce_app/features/moderation/domain/queue_item_entity.dart';

/// Part P-040 scope. Exercises [QueueItemResponseDto] against JSON shaped
/// exactly like the real `ModerationQueueSerializer` (P-038) output,
/// including its two optional shapes: `preview: null` and a `submitter`
/// key that is OMITTED (not null) when the content has no business.
void main() {
  Map<String, dynamic> fullJson() => {
    'id': 5,
    'content_type': 'post',
    'object_id': 12,
    'status': 'pending',
    'priority': 'fast_path',
    'created_at': '2026-09-20T10:00:00Z',
    'age': 754,
    'preview': {
      'preview_text': 'Summer sale caption',
      'preview_image_url': 'https://cdn.example.com/p/12.jpg',
    },
    'submitter': {'business_name': 'Elegance Store'},
  };

  group('QueueItemResponseDto.fromJson + toEntity', () {
    test('maps a full row, including preview and submitter', () {
      final item = QueueItemResponseDto.fromJson(fullJson()).toEntity();

      expect(
        item,
        QueueItem(
          id: 5,
          contentType: 'post',
          status: QueueItemStatus.pending,
          priority: QueuePriority.fastPath,
          createdAt: DateTime.utc(2026, 9, 20, 10),
          ageDuration: const Duration(seconds: 754),
          previewText: 'Summer sale caption',
          previewImageUrl: 'https://cdn.example.com/p/12.jpg',
          submitterBusinessName: 'Elegance Store',
        ),
      );
      expect(item.isFastPath, isTrue);
    });

    test('an omitted submitter key parses to a null business name', () {
      final json = fullJson()..remove('submitter');

      final item = QueueItemResponseDto.fromJson(json).toEntity();

      expect(item.submitterBusinessName, isNull);
      expect(item.previewText, 'Summer sale caption');
    });

    test('a null preview parses to null preview text and image', () {
      final json = fullJson()..['preview'] = null;

      final item = QueueItemResponseDto.fromJson(json).toEntity();

      expect(item.previewText, isNull);
      expect(item.previewImageUrl, isNull);
    });

    test('a preview with a null image keeps the text', () {
      final json = fullJson()
        ..['preview'] = {
          'preview_text': 'Caption only',
          'preview_image_url': null,
        };

      final item = QueueItemResponseDto.fromJson(json).toEntity();

      expect(item.previewText, 'Caption only');
      expect(item.previewImageUrl, isNull);
    });

    test('a normal-priority row is not fast path', () {
      final json = fullJson()..['priority'] = 'normal';

      final item = QueueItemResponseDto.fromJson(json).toEntity();

      expect(item.priority, QueuePriority.normal);
      expect(item.isFastPath, isFalse);
    });

    test('an unknown priority throws FormatException instead of defaulting', () {
      final json = fullJson()..['priority'] = 'urgent';

      expect(
        () => QueueItemResponseDto.fromJson(json).toEntity(),
        throwsFormatException,
      );
    });

    test('an unknown status throws FormatException instead of defaulting', () {
      final json = fullJson()..['status'] = 'escalated';

      expect(
        () => QueueItemResponseDto.fromJson(json).toEntity(),
        throwsFormatException,
      );
    });
  });

  group('wire conversions', () {
    test('QueuePriority.toWire is the inverse of fromWire', () {
      for (final priority in QueuePriority.values) {
        expect(QueuePriority.fromWire(priority.toWire()), priority);
      }
      expect(QueuePriority.fastPath.toWire(), 'fast_path');
      expect(QueuePriority.normal.toWire(), 'normal');
    });

    test('QueueItemStatus.fromWire parses all three backend values', () {
      expect(QueueItemStatus.fromWire('pending'), QueueItemStatus.pending);
      expect(QueueItemStatus.fromWire('approved'), QueueItemStatus.approved);
      expect(QueueItemStatus.fromWire('rejected'), QueueItemStatus.rejected);
    });
  });
}