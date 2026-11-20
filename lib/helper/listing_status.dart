/// The status rule of a seller's listing, in one place.
///
/// Refactoring (Consolidate Conditional Expression): the same "missing or
/// blank status means Active, compare case-insensitively" check was written
/// separately in the Posted Products screen, the post details screen and the
/// MR003 status filter. It is now one set of named methods, so the rule is
/// defined once. Behavior is unchanged.
class ListingStatus {
  ListingStatus._();

  static const String active = 'Active';
  static const String sold = 'Sold';

  /// The trimmed status of the listing, or 'Active' if it is missing or blank.
  static String of(Map<String, dynamic> data) {
    final statusValue = (data['status'] as String?)?.trim();
    return statusValue == null || statusValue.isEmpty ? active : statusValue;
  }

  /// True when [status] equals [expected], ignoring case.
  static bool isStatus(String status, String expected) {
    return status.toLowerCase() == expected.toLowerCase();
  }

  /// True when the listing is active (including a missing or blank status).
  static bool isActive(Map<String, dynamic> data) => isStatus(of(data), active);

  /// True when the listing is sold.
  static bool isSold(Map<String, dynamic> data) => isStatus(of(data), sold);
}
