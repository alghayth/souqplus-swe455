# Form 3 — Cost Estimation Form

**SWE 455 — Phase 1 · Part 2 — MR003** · Norah

| Activity | Estimate (person-days) | Notes / Assumptions |
|---|---|---|
| 1. Understand the problem and identify required changes. | 0.25 | The gap was found in Part 1 (database structure) and by reviewing the Posted Products screen. |
| 2. Design the changes. | 0.5 | Filter rules, chip layout, and how to treat blank or deleted categories. |
| 3. Perform impact analysis. | 0.25 | One screen plus CategoryService; no database, rules or index changes. |
| 4. Implement changes in source code. | 1.0 | ListingFilter helper, filter bar, filtered list and no-match message. |
| 5. Update SRS, SDD, STP, configuration documentation. | 0.5 | MR forms, slicing and refactoring forms, and the docs folder in the repo. |
| 6. Compile and integrate into the baseline. | 0.25 | Branch person3-mr003 and a Pull Request into main. |
| 7. Test functionality of changes. | 0.5 | Unit tests for every filter rule, plus a manual check on the emulator. |
| 8. Perform regression testing. | 0.5 | Edit and delete actions, summary counts, the product details screen, and the Home and Search filters. |
| 9. Release new baseline and report results. | 0.25 | Merge, tag, and a short report of the change and the test results. |
| **Total** | **4.0** | person-days. Assumes one developer familiar with the Listings module. |
