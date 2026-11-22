# Slicing Form — Slicing #3 (Static · Backward)

**SWE 455 — Phase 2 · Part 3 — Program Slicing** · Norah · Module: Listings (MR003)

Line numbers refer to the code after MR003 and before the refactoring (commit df12e0d).

| Item | Description |
|---|---|
| **Slicing Criteria** | The listing shown in each card of the seller's Posted Products screen: the variable doc at final doc = filteredDocs[index - 2]; (S21, line 527), C = <S21, doc>, in lib/screens/profile/posted_products_screen.dart, after MR003.<br><br>Question: which statements decide which listings the seller sees on this screen? |
| **Slicing Type** | Static · Backward. Static: we consider every statement that can affect the displayed listing, for any user, any filter choice and any data in Firestore, not one execution. Backward: we start at the listing shown in the card and follow its data and control dependencies back to where its values come from. |
| **Justification** | MR003 adds two filters in front of this list, so the most likely maintenance question becomes: "a seller says a listing is missing from Posted Products, what could have hidden it?". A backward slice from the displayed listing answers exactly that: it collects every statement that can decide what reaches the card, and nothing else.<br><br>A static slice fits because the screen has many possible states (two filters, categories that change at runtime, different sellers), and the answer must hold for all of them, not only for one run. |
| **Original Code** | *Original code (the statements of the screen that read or write the listings and the filters):*<br><br>See the code block "Original Code" below the table. |
| **Slicing Result** | Out of the 26 statements above, the slice keeps 22: S1 to S5, S7 to S10, S13 to S17, the predicates of S18 to S20, S21, and S23 to S26. It excludes S6, S11, S12, the bodies of S18 and S19, and S22.<br><br>*Resulting sliced code (what decides the displayed listing):*<br><br>See the code block "Slicing Result" below the table. |
| **File / Class name** | lib/screens/profile/posted_products_screen.dart (_PostedProductsScreenState: initState, build, _buildFilters, _clearFilters) and lib/helper/listing_filter.dart (ListingFilter), which the slice calls. |
| **Explanation** | The slice shows that a listing reaches the screen through four sources:<br><br>•  **The signed-in seller** (S7 to S9): the query only returns products whose ownerUid is the current user.<br><br>•  **The data in Firestore** (S10, S13): the snapshot of the seller's products.<br><br>•  **The two filter values** (S3, S4 and S23 to S26): set by the chips and by "Clear filters", and applied in S16.<br><br>•  **The managed categories** (S2, S5): they only act through S14 and S15. If the selected category is no longer in the options, S15 resets it to "All". Because S14 also adds every category still used by a listing, a filter can never hide a listing permanently.<br><br>The summary counts (S11, S12) are not in the slice, so the filters never change them. A maintainer who changes the filters does not need to re-test the counts.<br><br>**Latent risks surfaced by the slice:** (1) S9 has no orderBy, so the listings come in Firestore's default order, not newest first. Sorting would need orderBy('createdAt') and a composite index with ownerUid, and firestore.indexes.json is empty. (2) The status rule inside matchesStatus ("no status means Active") is written again in S11, S12 and the status badge (S22). This duplication is the smell I refactored in Refactoring #3.<br><br>**Relevance to maintenance:** when a seller reports a missing listing, these are the only statements to check: the owner query (S9), the two filters (S15, S16) and the rules in ListingFilter. The delete and edit actions and MarketplaceCleanupService (S6) can also change what is shown, but only through the data in Firestore, not through the program's dependencies, so a static slice of the code cannot show them. A maintainer has to remember them separately. |
| **Tool Usage (Optional)** | No automatic slicer was used (none is available for Dart). The data and control dependencies were traced by hand in VS Code, using "Find All References" on filteredDocs, _selectedStatus, _selectedCategory and _categories. The filter rules in the slice (S14 to S16) are covered by the 12 unit tests in test/listing_filter_test.dart (12 of 12 passing with flutter test). |

## Original Code

```dart
// lib/screens/profile/posted_products_screen.dart (_PostedProductsScreenState)
// after MR003, before refactoring
final _productsRef = db.collection('products');                     // S1  (28)
List<String> _categories = [...CategoryService.defaultCategories];  // S2  (31)
String _selectedStatus = ListingFilter.all;                         // S3  (33)
String _selectedCategory = ListingFilter.all;                       // S4  (34)
...
// initState(): the managed categories arrive from Firestore
_categories = categories.isEmpty                                    // S5  (42)
    ? [...CategoryService.defaultCategories] : categories;
MarketplaceCleanupService.purgeInvalidProducts();                   // S6  (48)
...
// build()
final user = FirebaseAuth.instance.currentUser;                     // S7  (409)
body: user == null ? ... : StreamBuilder(                           // S8  (417)
  stream: _productsRef.where('ownerUid', isEqualTo: user.uid)       // S9  (420)
                      .snapshots(),
final docs = productSnapshot.data!.docs;                            // S10 (435)
final activeCount = docs.where(... == 'active').length;              // S11 (436)
final soldCount = docs.where(... == 'sold').length;                  // S12 (440)
if (docs.isEmpty) return ... 'You have not posted any products';    // S13 (445)
final categoryOptions = ListingFilter.categoryOptions(              // S14 (454)
    _categories, docs.map((doc) => doc.data()));
final selectedCategory = categoryOptions.contains(_selectedCategory) // S15 (458)
    ? _selectedCategory : ListingFilter.all;
final filteredDocs = docs.where((doc) {                             // S16 (462)
  final data = doc.data();
  return ListingFilter.matchesCategory(data, selectedCategory) &&
      ListingFilter.matchesStatus(data, _selectedStatus);
}).toList();
itemCount: filteredDocs.isEmpty ? 3 : filteredDocs.length + 2,      // S17 (470)
if (index == 0) { ... '${docs.length} Total' ... }                  // S18 (475)
if (index == 1) { return _buildFilters(...); }                      // S19 (514)
if (filteredDocs.isEmpty) { return _buildNoMatch(); }               // S20 (523)
final doc = filteredDocs[index - 2];      // S21 (527) <-- slicing point
final title = ...; final status = _effectiveStatus(data); ...       // S22 (528+)  
...
// event handlers that change the filters
onSelected: (value) => setState(() => _selectedStatus = value),     // S23 (701)
onSelected: (value) => setState(() => _selectedCategory = value),   // S24 (710)
_selectedStatus = ListingFilter.all;      // S25 (755) in _clearFilters()
_selectedCategory = ListingFilter.all;    // S26 (756) in _clearFilters()
```

## Slicing Result

```dart
// Static backward slice for C = <S21, doc>
final _productsRef = db.collection('products');                     // S1
List<String> _categories = [...CategoryService.defaultCategories];  // S2
String _selectedStatus = ListingFilter.all;                         // S3
String _selectedCategory = ListingFilter.all;                       // S4
_categories = categories.isEmpty ? [...defaults] : categories;      // S5

final user = FirebaseAuth.instance.currentUser;                     // S7
if (user != null)                                                   // S8
  stream: _productsRef.where('ownerUid', isEqualTo: user.uid)       // S9
final docs = productSnapshot.data!.docs;                            // S10
if (docs.isEmpty) return;                                           // S13
final categoryOptions = ListingFilter.categoryOptions(              // S14
    _categories, docs.map((doc) => doc.data()));
final selectedCategory = categoryOptions.contains(_selectedCategory) // S15
    ? _selectedCategory : ListingFilter.all;
final filteredDocs = docs.where((doc) =>                            // S16
    ListingFilter.matchesCategory(doc.data(), selectedCategory) &&
    ListingFilter.matchesStatus(doc.data(), _selectedStatus)).toList();
itemCount: filteredDocs.isEmpty ? 3 : filteredDocs.length + 2,      // S17
if (index == 0) return;        // S18 (predicate only)
if (index == 1) return;        // S19 (predicate only)
if (filteredDocs.isEmpty) return;  // S20 (predicate only)
final doc = filteredDocs[index - 2];                                // S21 criterion

_selectedStatus = value;  _selectedCategory = value;                // S23, S24
_selectedStatus = ListingFilter.all;  _selectedCategory = ...all;   // S25, S26

// Called rules (lib/helper/listing_filter.dart):
//   categoryOf, categoryOptions, matchesCategory, matchesStatus

// NOT in the slice: S6 (cleanup), S11 and S12 (summary counts), the bodies
// of S18 and S19 (summary card, filter bar) and S22 (card contents).
```
