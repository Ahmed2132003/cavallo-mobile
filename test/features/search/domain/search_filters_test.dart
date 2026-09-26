import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/search/domain/search_filters.dart';

void main() {
  group('SearchFilters', () {
    test('isEmpty is true for the default instance', () {
      expect(const SearchFilters().isEmpty, isTrue);
    });

    test('isEmpty is false when any single field is set', () {
      expect(const SearchFilters(categoryId: 1).isEmpty, isFalse);
      expect(const SearchFilters(featuredOnly: true).isEmpty, isFalse);
      expect(const SearchFilters(minPrice: '10').isEmpty, isFalse);
    });

    test('copyWith sets a field without touching the others', () {
      const original = SearchFilters(country: 'Egypt', minRating: '3');
      final updated = original.copyWith(city: 'Cairo');

      expect(updated.country, 'Egypt');
      expect(updated.minRating, '3');
      expect(updated.city, 'Cairo');
    });

    test('copyWith clearX explicitly resets a field to null', () {
      const original = SearchFilters(country: 'Egypt');
      final cleared = original.copyWith(clearCountry: true);

      expect(cleared.country, isNull);
    });

    test('equality and hashCode are value-based', () {
      const a = SearchFilters(categoryId: 5, featuredOnly: true);
      const b = SearchFilters(categoryId: 5, featuredOnly: true);
      const c = SearchFilters(categoryId: 6, featuredOnly: true);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}