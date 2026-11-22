# Implementation and Test Report — MR003

**Branch:** `person3-mr003` · **Date:** TODO

## 1. Changes made

### `lib/helper/listing_filter.dart` (new)
| Member | Purpose |
|---|---|
| `all`, `statusOptions` | Chip values: `All`, `Active`, `Sold` |
| `categoryOf(data)` | Trimmed category; `Other` if missing or blank |
| `categoryOptions(managed, listings)` | `All`, the managed categories, then any other category a listing uses (case-insensitive, first spelling wins) |
| `matchesCategory(data, selected)` | `All` or case-insensitive category match |
| `matchesStatus(data, selected)` | `All` or case-insensitive status match; missing/blank status is `Active` |

### `lib/screens/profile/posted_products_screen.dart`
| Change |
|---|
| Fields `_selectedStatus`, `_selectedCategory` (default `All`) |
| `categoryOptions`, `selectedCategory` and `filteredDocs` computed in `build()`; the Firestore query is unchanged |
| List items: summary card (counts all listings), filters, then filtered listings or `_buildNoMatch()` |
| New `_buildFilters`, `_buildNoMatch`, `_clearFilters`, and `_FilterChipRow` |

### Refactoring #3 (Consolidate Conditional Expression)
See `docs/phase2/refactoring-mr003-consolidate-conditional.md`.

## 2. Automated tests

| Command | Result |
|---|---|
| `flutter test test/listing_filter_test.dart test/listing_status_test.dart` | TODO |
| `flutter test` | TODO |
| `flutter analyze` | TODO |

## 3. Manual testing

TODO
