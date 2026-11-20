import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/helper/listing_filter.dart';

Map<String, dynamic> listing({String? category, String? status}) => {
  'title': 'Item',
  'category': category,
  'status': status,
};

void main() {
  group('MR003 - categoryOf', () {
    test('returns the trimmed category', () {
      expect(ListingFilter.categoryOf(listing(category: '  Books ')), 'Books');
    });

    test('missing or blank category gives Other', () {
      expect(ListingFilter.categoryOf(listing()), 'Other');
      expect(ListingFilter.categoryOf(listing(category: '')), 'Other');
      expect(ListingFilter.categoryOf(listing(category: '   ')), 'Other');
      expect(ListingFilter.categoryOf(<String, dynamic>{}), 'Other');
    });
  });

  group('MR003 - category filter', () {
    test('All keeps every listing', () {
      final listings = [
        listing(category: 'Books'),
        listing(category: 'Electronics'),
        listing(),
      ];
      expect(
        listings.where((l) => ListingFilter.matchesCategory(l, ListingFilter.all)),
        hasLength(3),
      );
    });

    test('matches the category case-insensitively', () {
      final books = listing(category: 'books');
      expect(ListingFilter.matchesCategory(books, 'Books'), isTrue);
      expect(ListingFilter.matchesCategory(books, 'BOOKS'), isTrue);
      expect(ListingFilter.matchesCategory(books, 'Electronics'), isFalse);
    });

    test('a listing with no category is found under Other', () {
      expect(ListingFilter.matchesCategory(listing(), 'Other'), isTrue);
      expect(
        ListingFilter.matchesCategory(listing(category: ' '), 'Other'),
        isTrue,
      );
      expect(ListingFilter.matchesCategory(listing(), 'Books'), isFalse);
    });
  });

  group('MR003 - status filter', () {
    test('All keeps every listing', () {
      expect(ListingFilter.matchesStatus(listing(status: 'Active'), 'All'), isTrue);
      expect(ListingFilter.matchesStatus(listing(status: 'Sold'), 'All'), isTrue);
      expect(ListingFilter.matchesStatus(listing(), 'All'), isTrue);
    });

    test('separates Active from Sold', () {
      final active = listing(status: 'active');
      final sold = listing(status: 'SOLD');
      expect(ListingFilter.matchesStatus(active, 'Active'), isTrue);
      expect(ListingFilter.matchesStatus(active, 'Sold'), isFalse);
      expect(ListingFilter.matchesStatus(sold, 'Sold'), isTrue);
      expect(ListingFilter.matchesStatus(sold, 'Active'), isFalse);
    });

    test('a missing or blank status counts as Active', () {
      expect(ListingFilter.matchesStatus(listing(), 'Active'), isTrue);
      expect(ListingFilter.matchesStatus(listing(status: '  '), 'Active'), isTrue);
      expect(ListingFilter.matchesStatus(listing(), 'Sold'), isFalse);
    });
  });

  group('MR003 - categoryOptions', () {
    test('starts with All, then the managed categories in order', () {
      expect(
        ListingFilter.categoryOptions(['Books', ' Electronics ', ''], []),
        ['All', 'Books', 'Electronics'],
      );
    });

    test('adds an unmanaged category that a listing uses', () {
      expect(
        ListingFilter.categoryOptions(
          ['Books'],
          [listing(category: 'Books'), listing(category: 'Toys')],
        ),
        ['All', 'Books', 'Toys'],
      );
    });

    test('does not add case duplicates; the first spelling wins', () {
      expect(
        ListingFilter.categoryOptions(
          ['Books', 'books'],
          [listing(category: 'BOOKS'), listing(category: 'toys'), listing(category: 'Toys')],
        ),
        ['All', 'Books', 'toys'],
      );
    });

    test('adds Other when the admin removed it but a listing needs it', () {
      expect(
        ListingFilter.categoryOptions(['Books'], [listing()]),
        ['All', 'Books', 'Other'],
      );
    });
  });
}
