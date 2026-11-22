# MR003 — Implementation and Test Report

**Branch:** `person3-mr003` · **Owner:** Norah

## What changed

MR003 is implemented on the branch person3-mr003 (commit df12e0d). New: lib/helper/listing_filter.dart (the filter rules) and test/listing_filter_test.dart (12 unit tests). Changed: posted_products_screen.dart, which now has a Status and a Category filter, "Showing X of Y listings", "Clear filters" and a no-match message. No database, rules or index changes.

| File | Change |
|---|---|
| `lib/helper/listing_filter.dart` | New. Filter rules: `categoryOf`, `categoryOptions`, `matchesCategory`, `matchesStatus`. |
| `lib/screens/profile/posted_products_screen.dart` | Status and Category chip rows, filtered list, "Showing X of Y listings", "Clear filters", no-match message. |
| `test/listing_filter_test.dart` | New. 12 unit tests for the filter rules. |

## Refactoring that followed (Phase 2, Part 4)

| File | Change |
|---|---|
| `lib/helper/listing_status.dart` | New. `ListingStatus.of / isActive / isSold / isStatus` (Consolidate Conditional Expression). |
| `lib/screens/profile/posted_products_screen.dart` | Summary counts and status badge use `ListingStatus`; `_effectiveStatus` removed. |
| `lib/screens/details/details_screen.dart` | Status and `isSold` use `ListingStatus`. |
| `lib/helper/listing_filter.dart` | `matchesStatus` uses `ListingStatus`. |
| `test/listing_status_test.dart` | New. 13 tests comparing `ListingStatus` with the original expressions. |

## How to verify

```bash
flutter test test/listing_filter_test.dart test/listing_status_test.dart
flutter analyze
```

Manual check: sign in as a seller with listings in several categories (including one with a deleted
custom category) and both statuses, open **Posted Products**, and try every Status and Category chip,
"Clear filters", and edit / delete while a filter is on.

## Results

| Check | Result |
|---|---|
| `flutter test test/listing_filter_test.dart` | 12 / 12 passed |
| `flutter test test/listing_status_test.dart` | 13 / 13 passed |
| `flutter test` (whole suite) | 57 / 57 passed |
| `flutter analyze` | No issues found |
| Manual check on a device | Not done (no Android emulator available) |

Commits: `df12e0d` (MR003), `95a16fe` (refactoring), `e388988` (docs).
