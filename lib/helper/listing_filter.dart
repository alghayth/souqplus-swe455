/// Filter rules for the seller's own listings on the Posted Products screen.
///
/// MR003 (Perfective): the seller can narrow their listings by status and by
/// category. Filtering happens on the documents that were already loaded, so
/// the Firestore query does not change. This class is plain Dart, so every
/// rule can be unit-tested without Firebase.
class ListingFilter {
  ListingFilter._();

  /// The chip value that turns a filter off.
  static const String all = 'All';

  /// The choices of the Status chip row.
  static const List<String> statusOptions = [all, 'Active', 'Sold'];

  /// The listing category, trimmed. A missing or blank category is 'Other'.
  static String categoryOf(Map<String, dynamic> data) {
    final category = (data['category'] as String?)?.trim() ?? '';
    return category.isEmpty ? 'Other' : category;
  }

  /// The choices of the Category chip row: 'All', then the categories managed
  /// by the admin, then any other category used by one of the [listings].
  /// Duplicates are compared case-insensitively; the first spelling wins.
  static List<String> categoryOptions(
    List<String> managedCategories,
    Iterable<Map<String, dynamic>> listings,
  ) {
    final options = <String>[all];
    final seen = <String>{all.toLowerCase()};

    void add(String category) {
      if (category.isEmpty) return;
      if (seen.add(category.toLowerCase())) options.add(category);
    }

    for (final category in managedCategories) {
      add(category.trim());
    }
    for (final data in listings) {
      add(categoryOf(data));
    }
    return options;
  }

  /// True when [selectedCategory] is 'All' or equals the listing category
  /// (case-insensitive).
  static bool matchesCategory(
    Map<String, dynamic> data,
    String selectedCategory,
  ) {
    if (selectedCategory == all) return true;
    return categoryOf(data).toLowerCase() == selectedCategory.toLowerCase();
  }

  /// True when [selectedStatus] is 'All' or equals the listing status
  /// (case-insensitive). A missing or blank status counts as 'Active'.
  static bool matchesStatus(Map<String, dynamic> data, String selectedStatus) {
    if (selectedStatus == all) return true;
    final statusValue = (data['status'] as String?)?.trim();
    final status =
        statusValue == null || statusValue.isEmpty ? 'Active' : statusValue;
    return status.toLowerCase() == selectedStatus.toLowerCase();
  }
}
