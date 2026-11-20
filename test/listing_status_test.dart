import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/helper/listing_status.dart';

// ---------------------------------------------------------------------------
// The ORIGINAL expressions, copied unchanged from the code before the
// Consolidate Conditional Expression refactoring. The tests below check that
// ListingStatus gives exactly the same results.
// ---------------------------------------------------------------------------

// posted_products_screen.dart: _PostedProductsScreenState._effectiveStatus
String _effectiveStatus(Map<String, dynamic> data) {
  final statusValue = (data['status'] as String?)?.trim();
  return statusValue == null || statusValue.isEmpty ? 'Active' : statusValue;
}

// posted_products_screen.dart: activeCount / soldCount checks and the
// status-badge colour condition.
bool _oldIsActiveCount(Map<String, dynamic> data) {
  final status = _effectiveStatus(data);
  return status.toLowerCase() == 'active';
}

bool _oldIsSoldCount(Map<String, dynamic> data) {
  final status = _effectiveStatus(data);
  return status.toLowerCase() == 'sold';
}

// details_screen.dart: _FirestorePostDetailsScreen.build
String _oldDetailsStatus(Map<String, dynamic> data) {
  final status = (data['status'] as String?)?.trim().isNotEmpty == true
      ? (data['status'] as String).trim()
      : 'Active';
  return status;
}

bool _oldDetailsIsSold(Map<String, dynamic> data) {
  final status = _oldDetailsStatus(data);
  return status.toLowerCase() == 'sold';
}

void main() {
  group('Refactoring #3 - ListingStatus gives the same results as the originals', () {
    // Each sample is a listing document; "missing" has no 'status' key.
    final samples = <String, Map<String, dynamic>>{
      'missing': <String, dynamic>{'title': 'Item'},
      'null': <String, dynamic>{'status': null},
      "''": <String, dynamic>{'status': ''},
      "'   '": <String, dynamic>{'status': '   '},
      "'Active'": <String, dynamic>{'status': 'Active'},
      "'active'": <String, dynamic>{'status': 'active'},
      "' Active '": <String, dynamic>{'status': ' Active '},
      "'Sold'": <String, dynamic>{'status': 'Sold'},
      "'SOLD'": <String, dynamic>{'status': 'SOLD'},
      "' sold '": <String, dynamic>{'status': ' sold '},
      "'Reserved'": <String, dynamic>{'status': 'Reserved'},
    };

    samples.forEach((name, data) {
      test('status $name', () {
        expect(ListingStatus.of(data), _effectiveStatus(data));
        expect(ListingStatus.of(data), _oldDetailsStatus(data));
        expect(ListingStatus.isActive(data), _oldIsActiveCount(data));
        expect(ListingStatus.isSold(data), _oldIsSoldCount(data));
        expect(ListingStatus.isSold(data), _oldDetailsIsSold(data));
      });
    });
  });

  group('Refactoring #3 - ListingStatus rules', () {
    test('a missing or blank status is Active', () {
      for (final data in [
        <String, dynamic>{},
        <String, dynamic>{'status': null},
        <String, dynamic>{'status': ''},
        <String, dynamic>{'status': '  '},
      ]) {
        expect(ListingStatus.of(data), ListingStatus.active);
        expect(ListingStatus.isActive(data), isTrue);
        expect(ListingStatus.isSold(data), isFalse);
      }
    });

    test('Sold is recognised in any case', () {
      for (final value in ['Sold', 'sold', 'SOLD', ' sOlD ']) {
        final data = <String, dynamic>{'status': value};
        expect(ListingStatus.isSold(data), isTrue);
        expect(ListingStatus.isActive(data), isFalse);
      }
      expect(ListingStatus.isStatus('SOLD', ListingStatus.sold), isTrue);
    });
  });
}
