import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';

void main() {
  group('PaginatedResponse.fromJson', () {
    test('parses results, next, and previous', () {
      final json = {
        'results': [
          {'value': 1},
          {'value': 2},
        ],
        'next': 'https://api.example.com/things/?cursor=abc',
        'previous': null,
      };

      final page = PaginatedResponse.fromJson<int>(
        json,
        (item) => item['value'] as int,
      );

      expect(page.results, [1, 2]);
      expect(page.next, 'https://api.example.com/things/?cursor=abc');
      expect(page.previous, isNull);
    });

    test('parses an empty results list on the last page', () {
      final json = {'results': [], 'next': null, 'previous': null};

      final page = PaginatedResponse.fromJson<int>(
        json,
        (item) => item['value'] as int,
      );

      expect(page.results, isEmpty);
      expect(page.next, isNull);
      expect(page.previous, isNull);
    });
  });
}