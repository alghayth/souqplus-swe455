# Refactoring Form — Refactoring #3 (Consolidate Conditional Expression)

**SWE 455 — Phase 2 · Part 4 — Refactoring** · Norah · Module: Listings (MR003)

| Item | Description |
|---|---|
| **Code smell** | Duplicated Conditionals. In the Listings module the rule "a listing with no status is Active" and the checks "is it active?" and "is it sold?" were written in five places, in three different forms: _effectiveStatus plus status.toLowerCase() == 'active' / 'sold' for the summary counts and twice for the status badge (posted_products_screen.dart); a different null-and-empty check plus == 'sold' in details_screen.dart; and the same rule again in ListingFilter.matchesStatus, which I added in MR003. The slice in Slicing #3 pointed to this repetition. |
| **Refactoring Type** | Consolidate Conditional Expression (major). The duplicated checks were combined into one named expression each, in a new class ListingStatus (of, isActive, isSold, isStatus). Every place now calls these methods instead of writing the condition. Inside the badge, the two identical ternary conditions now share one isActive value. |
| **Affected Class(es)** | New: lib/helper/listing_status.dart (ListingStatus) and test/listing_status_test.dart. Changed: lib/screens/profile/posted_products_screen.dart (_PostedProductsScreenState: summary counts and status badge; _effectiveStatus removed), lib/screens/details/details_screen.dart (_FirestorePostDetailsScreen) and lib/helper/listing_filter.dart (ListingFilter.matchesStatus). |
| **Original Code** | *Original code (the same conditions in three files):*<br><br>See the code block "Original Code" below the table. |
| **Code After Refactoring** | *Code after refactoring (one named expression for each condition):*<br><br>See the code block "Code After Refactoring" below the table. |
| **Explanation** | **Why this smell.** The status rule decides what a seller and a buyer see: the counts, the green or grey badge, the "Sold" button on the details screen, and now the status filter. Because it was written five times in three forms, a change such as adding a "Reserved" status would have to be made in every copy, and missing one would make the screens disagree.<br><br>**Why Consolidate Conditional Expression.** All the copies return the same answer for the same data, so they can be replaced by one expression with a name that says what it checks: of, isActive, isSold. The screens now read like the rule itself.<br><br>**Benefits:** one place for the status rule; fewer lines in both screens (the private _effectiveStatus helper is gone); the badge evaluates its condition once instead of twice; and the rule is plain Dart, so it can be unit-tested without Firebase.<br><br>**Behaviour preserved.** The new methods return exactly what the original expressions returned (see the tests below). Two other places use a different rule and were left unchanged on purpose: admin_records_screen.dart treats a missing status as not active, and product.dart does not trim the status. Changing them would change behaviour, so they are noted for a future MR instead. |
| **Validation / Testing Type** | ☐ Manual    ☒ Automated |
| **Test Description** | Automated: test/listing_status_test.dart keeps copies of the original expressions and checks that ListingStatus.of, isActive and isSold return the same values for 11 kinds of stored status (missing, null, empty, spaces, "Active", "active", " Active ", "Sold", "SOLD", " sold " and "Reserved"), plus 2 direct tests (13 tests). test/listing_filter_test.dart (12 tests) is run again to show that MR003 behaves the same. flutter analyze checks the changed files. The whole suite (flutter test) is run as regression testing. |
| **Expected Result** | All tests pass, and every new method returns the same value as the expression it replaced, so the summary counts, the status badge, the details screen and the status filter behave exactly as before. |
| **Actual Result** | 13 / 13 tests in listing_status_test.dart and 12 / 12 in listing_filter_test.dart passed (25 / 25), the whole suite passed (57 / 57), and flutter analyze found no issues. Every ListingStatus method returned the same value as the original expression. Not tested: a manual run of the app on a device, because no Android emulator was available. |

## Original Code

```dart
// Before: the same status checks, written in three different forms.

// 1) posted_products_screen.dart - helper, then summary counts and badge
String _effectiveStatus(Map<String, dynamic> data) {
  final statusValue = (data['status'] as String?)?.trim();
  return statusValue == null || statusValue.isEmpty ? 'Active' : statusValue;
}
final activeCount = docs.where((doc) {
  final status = _effectiveStatus(doc.data());
  return status.toLowerCase() == 'active';
}).length;
final soldCount = docs.where((doc) {
  final status = _effectiveStatus(doc.data());
  return status.toLowerCase() == 'sold';
}).length;
...
color: status.toLowerCase() == 'active' ? Colors.green... : Colors.grey...,
color: status.toLowerCase() == 'active' ? Colors.green : Colors.grey,

// 2) details_screen.dart - same rule, different form
final status = (post.data['status'] as String?)?.trim().isNotEmpty == true
    ? (post.data['status'] as String).trim()
    : 'Active';
final isSold = status.toLowerCase() == 'sold';

// 3) listing_filter.dart (MR003) - same rule again
final statusValue = (data['status'] as String?)?.trim();
final status =
    statusValue == null || statusValue.isEmpty ? 'Active' : statusValue;
return status.toLowerCase() == selectedStatus.toLowerCase();
```

## Code After Refactoring

```dart
// After: lib/helper/listing_status.dart (new)
class ListingStatus {
  ListingStatus._();

  static const String active = 'Active';
  static const String sold = 'Sold';

  // The stored status (trimmed), or "Active" when it is missing or blank.
  static String of(Map<String, dynamic> data) {
    final statusValue = (data['status'] as String?)?.trim();
    return statusValue == null || statusValue.isEmpty ? active : statusValue;
  }

  static bool isStatus(String status, String expected) =>
      status.toLowerCase() == expected.toLowerCase();
  static bool isActive(Map<String, dynamic> data) => isStatus(of(data), active);
  static bool isSold(Map<String, dynamic> data) => isStatus(of(data), sold);
}

// posted_products_screen.dart (_effectiveStatus removed)
final activeCount =
    docs.where((doc) => ListingStatus.isActive(doc.data())).length;
final soldCount =
    docs.where((doc) => ListingStatus.isSold(doc.data())).length;
final status = ListingStatus.of(data);
final isActive = ListingStatus.isActive(data);  // used by both badge colours

// details_screen.dart
final status = ListingStatus.of(post.data);
final isSold = ListingStatus.isSold(post.data);

// listing_filter.dart
return ListingStatus.isStatus(ListingStatus.of(data), selectedStatus);
```
