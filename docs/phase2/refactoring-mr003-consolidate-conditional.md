# Refactoring Form — Refactoring #3 (Consolidate Conditional Expression)

**SWE 455 — Phase 2 · Part 4 — Refactoring** · Norah · Module: Listings (MR003)

| Item | Description |
|---|---|
| **Refactoring Type** | Consolidate Conditional Expression |
| **Problem** | The rule "a missing or blank status means Active; compare case-insensitively" was written separately in `_effectiveStatus` and the count checks of `posted_products_screen.dart`, in `details_screen.dart`, and in `ListingFilter.matchesStatus`. |
| **Change** | New `lib/helper/listing_status.dart` (`ListingStatus.of`, `isStatus`, `isActive`, `isSold`). `_effectiveStatus` is removed; all three places call `ListingStatus`. `admin_records_screen.dart` and `models/product.dart` are intentionally not changed (they use a slightly different rule). |
| **Behavior** | Unchanged. `test/listing_status_test.dart` compares `ListingStatus` with copies of the original expressions for 11 sample statuses. |

## 1. Original Code (before)

TODO

## 2. Code After Refactoring

TODO

## Explanation

TODO
