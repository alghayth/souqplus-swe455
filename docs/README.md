# SouqPlus — Maintenance Documentation (SWE 455)

This folder holds the Phase 1 forms (program comprehension and maintenance
requests), kept separate from the application code.

## Structure

```
docs/
├── README.md                                   ← this file
├── phase1-program-comprehension/
│   └── notifications-module.md                 ← how the Notifications module works
└── maintenance-requests/
    └── MR001-preventive-notifications/         ← Munirah — Preventive MR
        ├── 1-maintenance-request-form.md
        ├── 2-impact-analysis-form.md
        ├── 3-cost-estimation-form.md
        └── 4-implementation-and-test-report.md
```

## Maintenance requests

| ID | Type | Module | Owner | Branch | Status |
|---|---|---|---|---|---|
| MR001 | Preventive | Notifications | Munirah | `person1-notifications-mr` | Implemented and tested; waiting for PR review |

To add another request, copy the `MR001-…` folder, rename it (for example
`MR002-corrective-…`), and fill in the four forms.
