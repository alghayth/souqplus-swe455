# Form 3 — Cost Estimation Form

| | |
|---|---|
| **MR ID** | MR001 |

| Activity | Estimate (person-days) | Notes / Assumptions |
|---|:---:|---|
| 1. Understand the problem and identify the required changes. | 0.25 | Code already reviewed; the gaps are known. |
| 2. Design the changes. | 0.25 | Simple try/catch and logging pattern. |
| 3. Perform impact analysis. | 0.5 | Trace the callers (checkout, screens). |
| 4. Implement the changes in the source code. | 0.5 | 3–4 files, small edits and 1 logger. |
| 5. Update SRS, SDD, STP, and configuration documentation. | 0.5 | Document the error-handling behavior (see `docs/`). |
| 6. Compile and integrate into the baseline. | 0.25 | Merge the branch through a Pull Request. |
| 7. Test the functionality of the changes. | 0.5 | Verify notifications still work; simulate a failure. |
| 8. Perform regression testing. | 0.25 | Checkout, notifications screen, bell counter. |
| 9. Release the new baseline and report the results. | 0.25 | Tag and summarize in the PR. |
| **Total** | **3.25** | person-days |

*Note: estimates are in
person-days and can be adjusted to match the team's pace.*
