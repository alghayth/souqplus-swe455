# Form 2 — Impact Analysis Form

| Field | Value |
|---|---|
| **MR ID** | MR003 |
| **Current State** | The Posted Products screen shows every listing of the seller in one list, with no way to narrow it. |
| **Future State** | The seller can filter by status and by category, sees how many listings are shown, and can clear the filters. Summary counts still count all listings. |
| **Gap / Required Change** | New `lib/helper/listing_filter.dart` (`ListingFilter`); filter UI in `lib/screens/profile/posted_products_screen.dart`; unit tests in `test/listing_filter_test.dart`. |
| **Alternative Solutions** | TODO |
| **Timing of Impact** | ☐ Immediate ☐ Short-term ☐ Long-term (TODO) |
| **Level of Impact** | ☐ Low ☐ Medium ☐ High (TODO) |
| **Type of Impact** | ☐ Functional ☐ UI/UX ☐ Performance ☐ Security ☐ Other: ____ (TODO) |
| **Scale of Change** | ☐ Organization ☐ Program ☐ Project ☑ Module |
| **Module / Component** | Listings module: `posted_products_screen.dart`, `listing_filter.dart`, `listing_status.dart` (Refactoring #3), `details_screen.dart` (Refactoring #3). |
| **Dependencies & Affected Components** | Cloud Firestore `products` collection (read only, query unchanged), `CategoryService.categoriesStream()`. No change to `firestore.rules` or `firestore.indexes.json`. |
| **Key Risks** | TODO |
| **Roles Affected** | Sellers. |
| **Number Affected** | TODO |
| **Communication Requirements** | TODO |
| **Training Requirements** | No. |
| **Leadership Oversight** | TODO |
| **Alignment & Collaboration Needed** | TODO |
| **Resources Required** | 1 developer, existing Flutter/Dart tooling. No new packages. |
