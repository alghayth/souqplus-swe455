import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/helper/product_filter.dart';

// Same price ranges as _kPriceRanges in search_screen.dart and home_screen.dart.
const Map<String, dynamic> anyPrice = {'min': 0, 'max': double.infinity};
const Map<String, dynamic> under25 = {'min': 0, 'max': 25};
const Map<String, dynamic> from25To50 = {'min': 25, 'max': 50};
const Map<String, dynamic> from50To100 = {'min': 50, 'max': 100};
const Map<String, dynamic> from500To1000 = {'min': 500, 'max': 1000};
const Map<String, dynamic> over1000 = {'min': 1000, 'max': double.infinity};

Map<String, dynamic> product({
  String? title,
  String? category,
  String? status,
  num? price,
}) => {
  'title': title,
  'category': category,
  'status': status,
  'price': price,
};

void main() {
  group('MR002 - price range boundaries', () {
    test('SAR 25 appears only in "SAR 25 - SAR 50"', () {
      final p = product(price: 25);
      expect(ProductFilter.isInPriceRange(p, under25), isFalse);
      expect(ProductFilter.isInPriceRange(p, from25To50), isTrue);
    });

    test('SAR 50 appears only in "SAR 50 - SAR 100"', () {
      final p = product(price: 50);
      expect(ProductFilter.isInPriceRange(p, from25To50), isFalse);
      expect(ProductFilter.isInPriceRange(p, from50To100), isTrue);
    });

    test('SAR 1000 appears only in "Over SAR 1000"', () {
      final p = product(price: 1000);
      expect(ProductFilter.isInPriceRange(p, from500To1000), isFalse);
      expect(ProductFilter.isInPriceRange(p, over1000), isTrue);
    });

    test('prices inside a range are still included', () {
      expect(ProductFilter.isInPriceRange(product(price: 24.99), under25), isTrue);
      expect(ProductFilter.isInPriceRange(product(price: 30), from25To50), isTrue);
    });

    test('"Any price" includes every price', () {
      expect(ProductFilter.isInPriceRange(product(price: 0), anyPrice), isTrue);
      expect(ProductFilter.isInPriceRange(product(price: 99999), anyPrice), isTrue);
    });

    test('a product without a price is treated as SAR 0', () {
      expect(ProductFilter.isInPriceRange(product(), under25), isTrue);
    });
  });

  group('Refactoring - other conditions keep their behavior', () {
    test('status: empty or "active" is available, anything else is not', () {
      expect(ProductFilter.isAvailable(product()), isTrue);
      expect(ProductFilter.isAvailable(product(status: ' Active ')), isTrue);
      expect(ProductFilter.isAvailable(product(status: 'sold')), isFalse);
    });

    test('keyword: empty keyword matches everything', () {
      expect(ProductFilter.matchesKeyword(product(title: 'Lamp'), ''), isTrue);
    });

    test('keyword: matches title or category, ignoring case', () {
      final p = product(title: 'iPhone 13', category: 'Electronics');
      expect(ProductFilter.matchesKeyword(p, 'iphone'), isTrue);
      expect(ProductFilter.matchesKeyword(p, 'electro'), isTrue);
      expect(ProductFilter.matchesKeyword(p, 'sofa'), isFalse);
    });

    test('category: "All" matches everything, otherwise exact match', () {
      final p = product(category: 'electronics');
      expect(ProductFilter.isInCategory(p, 'All'), isTrue);
      expect(ProductFilter.isInCategory(p, 'Electronics'), isTrue);
      expect(ProductFilter.isInCategory(p, 'Furniture'), isFalse);
    });
  });
}
