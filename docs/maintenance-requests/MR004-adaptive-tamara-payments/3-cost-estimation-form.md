# Form 3 — Cost Estimation Form

| | |
|---|---|
| **MR ID** | MR004 |

| Activity | Estimate (person-days) | Notes / Assumptions |
|---|:---:|---|
| 1. Understand the problem and identify the required changes. | 0.5 | Read the checkout and payment code; study Tamara's API. |
| 2. Design the changes. | 0.5 | Pending-order flow, webhook, states. |
| 3. Perform impact analysis. | 0.5 | Orders, delivery, notifications, admin payments. |
| 4. Implement the changes in the source code. | 2 | Backend module and endpoints, checkout UI and flow. |
| 5. Update SRS, SDD, STP, and configuration documentation. | 0.5 | Control flow, MR forms, environment variables. |
| 6. Compile and integrate into the baseline. | 0.25 | Merge through a Pull Request. |
| 7. Test the functionality of the changes. | 1 | Unit tests; sandbox end-to-end run once credentials exist. |
| 8. Perform regression testing. | 0.5 | Card checkout, order history, notifications. |
| 9. Release the new baseline and report the results. | 0.25 | Deploy functions, set secrets, report. |
| **Total** | **5.5** | person-days |

*Note: estimates are in person-days and can be adjusted to match the team's pace.*
