import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/saved/domain/saved_item.dart';

/// Part P-113 (STEP 3B): parsing one row of `GET /api/v1/saves/me/`.
void main() {
  group('SavedContentType', () {
    test('wire values are exactly the backend whitelist', () {
      expect(
        SavedContentType.values.map((SavedContentType t) => t.wireValue),
        <String>['post', 'reel', 'product'],
      );
    });

    test('fromWire maps known values and returns null for unknown ones', () {
      expect(SavedContentType.fromWire('post'), SavedContentType.post);
      expect(SavedContentType.fromWire('reel'), SavedContentType.reel);
      expect(SavedContentType.fromWire('product'), SavedContentType.product);
      expect(SavedContentType.fromWire('story'), isNull);
      expect(SavedContentType.fromWire(null), isNull);
    });
  });

  group('SavedItem.tryFromJson', () {
    test('parses a full row', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 12,
        'content_type': 'reel',
        'object_id': 345,
        'preview': <String, dynamic>{
          'preview_text': 'Factory tour',
          'preview_image_url': 'https://cdn.example.com/t.jpg',
        },
        'created_at': '2026-10-05T10:00:00Z',
      });

      expect(item, isNotNull);
      expect(item!.id, 12);
      expect(item.contentType, SavedContentType.reel);
      expect(item.objectId, 345);
      expect(item.previewText, 'Factory tour');
      expect(item.previewImageUrl, 'https://cdn.example.com/t.jpg');
      expect(item.createdAt, DateTime.utc(2026, 10, 5, 10));
      expect(item.isUnavailable, isFalse);
    });

    test('preview null means the target is gone (unavailable)', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 1,
        'content_type': 'post',
        'object_id': 2,
        'preview': null,
        'created_at': '2026-10-05T10:00:00Z',
      });

      expect(item, isNotNull);
      expect(item!.isUnavailable, isTrue);
      expect(item.previewText, isNull);
      expect(item.previewImageUrl, isNull);
    });

    test('an empty image URL becomes null and empty text stays available', () {
      final SavedItem? item = SavedItem.tryFromJson(<String, dynamic>{
        'id': 1,
        'content_type': 'post',
        'object_id': 2,
        'preview': <String, dynamic>{
          'preview_text': '',
          'preview_image_url': '',
        },
        'created_at': 'not-a-date',
      });

      expect(item!.previewImageUrl, isNull);
      expect(item.previewText, '');
      expect(item.isUnavailable, isFalse);
      expect(item.createdAt, isNull);
    });

    test('an unknown content type or a malformed row is skipped', () {
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 1,
          'content_type': 'story',
          'object_id': 2,
          'preview': null,
        }),
        isNull,
      );
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 'x',
          'content_type': 'post',
          'object_id': 2,
        }),
        isNull,
      );
      expect(
        SavedItem.tryFromJson(<String, dynamic>{
          'id': 1,
          'content_type': 'post',
        }),
        isNull,
      );
    });
  });
}
