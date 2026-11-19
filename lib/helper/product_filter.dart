/// Filter conditions used by the product lists in the Search screen and the
/// Home screen.
///
/// Refactoring (Decompose Conditional): the long condition that was written
/// inline inside `docs.where(...)` is split into small checks, each with a
/// clear name, so every rule can be read and tested on its own.
class ProductFilter {
  ProductFilter._();

  /// A product is shown only when it has no status or its status is "active".
  static bool isAvailable(Map<String, dynamic> data) {
    final status = ((data['status'] as String?) ?? '').trim().toLowerCase();
    return status.isEmpty || status == 'active';
  }

  /// True when [keyword] is empty or appears in the product title or category.
  /// [keyword] is expected to be already trimmed and lower-cased.
  static bool matchesKeyword(Map<String, dynamic> data, String keyword) {
    if (keyword.isEmpty) return true;
    final title = ((data['title'] as String?) ?? '').toLowerCase();
    final category = ((data['category'] as String?) ?? '').toLowerCase();
    return title.contains(keyword) || category.contains(keyword);
  }

  /// True when the product price is inside [range].
  ///
  /// MR002: the range is half-open (min <= price < max), so a price that is
  /// exactly on a boundary (for example SAR 25) belongs to one range only.
  static bool isInPriceRange(
    Map<String, dynamic> data,
    Map<String, dynamic> range,
  ) {
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final min = (range['min'] as num).toDouble();
    final max = (range['max'] as num).toDouble();
    return price >= min && price < max;
  }

  /// True when "All" is selected or the product category matches it.
  static bool isInCategory(
    Map<String, dynamic> data,
    String selectedCategory,
  ) {
    if (selectedCategory == 'All') return true;
    final category = ((data['category'] as String?) ?? '').toLowerCase();
    return category == selectedCategory.toLowerCase();
  }
}
