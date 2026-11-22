# Form 2 — Impact Analysis Form

**SWE 455 — Phase 1 · Part 2 — MR003** · Norah

| Field | Value |
|---|---|
| **MR ID** | MR003 |
| **Current State** | posted_products_screen.dart streams all products where ownerUid equals the current user and shows them in one list. The summary card shows Total, Active and Sold counts. There is no way to filter the list. The managed categories (CategoryService) are loaded, but they are only used in the edit sheet. |
| **Future State** | Two rows of chips, Status and Category, appear under the summary card. The list shows only the listings that match both filters, while the summary counts still describe all listings. "Showing X of Y listings", "Clear filters" and a no-match message guide the seller.<br><br>Category options are "All", the managed categories, and any category still used by one of the seller's listings. A listing with no category appears under "Other", and a listing with no status counts as Active. |
| **Gap / Required Change** | Add two filter values (_selectedStatus, _selectedCategory) and a filter bar to _PostedProductsScreenState, and filter the documents before the list is built.<br><br>Put the filter rules in a new helper, lib/helper/listing_filter.dart (categoryOf, categoryOptions, matchesCategory, matchesStatus), with unit tests in test/listing_filter_test.dart.<br><br>No change to the database, firestore.rules or indexes. |
| **Alternative solutions** | 1) Filter in Firestore with where('category') and where('status'): needs composite indexes with ownerUid, a new query each time a filter changes, and it would miss categories saved with different letter case.<br><br>2) Send sellers to the existing Search screen: it lists every seller's products, not the seller's own, and it hides Sold products.<br><br>3) Dropdown menus instead of chips: they save space but hide the options behind an extra tap.<br><br>Chosen: filter on the device, on the stream the screen already has (one seller's listings are a small list), with chip rows. |
| **Timing of Impact** | ☑ Immediate  ☐ Short-term  ☐ Long-term |
| **Level of Impact** | ☑ Low  ☐ Medium  ☐ High |
| **Type of Impact** | ☑ Functional  ☑ UI/UX  ☐ Performance  ☐ Security  ☐ Other: ____ |
| **Scale of Change** | ☐ Organization  ☐ Program  ☐ Project  ☑ Module |
| **Module / Component** | Listings module: lib/screens/profile/posted_products_screen.dart (Posted Products screen) and the new lib/helper/listing_filter.dart. |
| **Dependencies & Affected Components** | Firestore products collection (category, status and ownerUid fields, read only); CategoryService.categoriesStream (managed categories); the admin categories screen (deleting a category changes the options); the edit and delete actions on the same screen. The Home and Search filters (MR002) are not changed. |
| **Key Risks** | 1) A listing whose category was deleted could become unreachable: handled by adding every category used by the seller's listings to the options.<br><br>2) The selected category is deleted while selected: the filter falls back to "All".<br><br>3) The summary counts could be read as filtered counts: they stay unfiltered, and "Showing X of Y" makes the difference clear.<br><br>4) Filtering on the device fits one seller's listings, but would not scale to thousands of products.<br><br>Security and privacy: no impact. The query, the rules and the data read are the same; the seller only sees their own listings, as before. |
| **Roles Affected** | Sellers (end users), developers and testers. Admins only indirectly, through category management. |
| **Number Affected** | Every user who has posted products. One screen and one new helper class. Buyers and drivers are not affected. |
| **Communication Requirements** | Group chat and the Pull Request description. A short note to the Search & Filter owner (MR002), because both features use the categories. |
| **Training Requirements** | No. The chips are self-explanatory. |
| **Leadership Oversight** | The team leader reviews the Pull Request, and the course instructor oversees the maintenance process. |
| **Alignment & Collaboration Needed** | Coordination with the Search & Filter owner (MR002) so that categories behave the same way for buyers and sellers, and with whoever maintains the admin categories screen. |
| **Resources Required** | 1 developer and 1 tester; Flutter SDK, VS Code, an Android emulator, and a Firebase test account with listings in several categories and both statuses; GitHub. |
