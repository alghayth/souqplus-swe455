# SouqPlus — Maintenance Documentation (SWE 455)

This folder holds the team's maintenance documentation (program
comprehension, maintenance request forms, and Phase 2 work), kept separate
from the application code.

## Structure

```
docs/
├── README.md                                   ← this file
├── phase1-program-comprehension/
│   ├── notifications-module.md                 ← Munirah: how the Notifications module works
│   └── control-flow.md                         ← Tojan: checkout and payment control flow
├── maintenance-requests/
│   ├── MR001-preventive-notifications/         ← Munirah — Preventive MR
│   │   ├── 1-maintenance-request-form.md
│   │   ├── 2-impact-analysis-form.md
│   │   ├── 3-cost-estimation-form.md
│   │   └── 4-implementation-and-test-report.md
│   ├── MR003-perfective-listings-filters/      ← Norah — Perfective MR
│   │   ├── 1-maintenance-request-form.md
│   │   ├── 2-impact-analysis-form.md
│   │   ├── 3-cost-estimation-form.md
│   │   └── 4-implementation-and-test-report.md
│   └── MR004-adaptive-tamara-payments/         ← Tojan — Adaptive MR
│       ├── 1-maintenance-request-form.md
│       ├── 2-impact-analysis-form.md
│       ├── 3-cost-estimation-form.md
│       └── 4-implementation-and-test-report.md
└── phase2/
    ├── slicing-mr003-static-backward.md        ← Norah: Program Slicing
    ├── refactoring-mr003-consolidate-conditional.md ← Norah: Refactoring
    ├── slicing-mr004-dynamic-forward.md        ← Tojan: Program Slicing
    └── refactoring-mr004-extract-interface.md  ← Tojan: Refactoring
```

## Maintenance requests

| ID | Type | Module | Owner | Branch | Status |
|---|---|---|---|---|---|
| MR001 | Preventive | Notifications | Munirah | `person1-notifications-mr` | Merged into `main` (PR #1) |
| MR003 | Perfective | Listings | Norah | `person3-mr003` | Implemented; pending review |
| MR004 | Adaptive | Payments | Tojan | `person4-tamara-mr` | Implemented; sandbox end-to-end test pending credentials |

To add another request, copy the `MR001-…` folder, rename it with the next
free ID (for example `MR002-corrective-…`), and fill in the four forms.

## Phase 2 (Norah, Listings / MR003)

| Part | File |
|---|---|
| Part 3: Program Slicing (Static, Backward) | `phase2/slicing-mr003-static-backward.md` |
| Part 4: Refactoring (Consolidate Conditional Expression) | `phase2/refactoring-mr003-consolidate-conditional.md` |

## Phase 2 (Tojan, Payments / MR004)

| Part | File |
|---|---|
| Part 3: Program Slicing (Dynamic, Forward) | `phase2/slicing-mr004-dynamic-forward.md` |
| Part 4: Refactoring (Extract Interface) | `phase2/refactoring-mr004-extract-interface.md` |
