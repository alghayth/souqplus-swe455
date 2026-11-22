# Form 1 — Maintenance Request Form

**SWE 455 — Phase 1 · Part 2 — Maintenance Request (MR003)**
Perfective maintenance: add categories / filters to the Listings module (SouqPlus) · Norah

| Field | Value |
|---|---|
| **MR ID** | MR003 |
| **Date Logged** | 2026-10-10 |
| **Reported By** | Norah |
| **Change / Request Name** | Add categories / filters to the Listings module |
| **Description** | Add a category filter and a status filter (All / Active / Sold) to the seller's Posted Products screen, which is the Listings module. The seller can narrow their own listings by category and by status. The screen also shows "Showing X of Y listings", a "Clear filters" action, and a message when no listing matches.<br><br>Expected outcome: a seller with many listings can find a listing to edit, delete or check in a few taps. Nothing changes for buyers, drivers or admins. |
| **Justification** | The Posted Products screen shows every listing of the seller in one long list, with only the Total / Active / Sold counts at the top. As a seller posts more products, finding one listing means scrolling the whole list. The buyer screens (Home and Search) can already filter by category, but the seller's own screen cannot.<br><br>In Part 1 (Analysis #3) I also found that a product stores its category as plain text, so a listing can keep a category that the admin has since deleted. The new filter has to keep such listings reachable. This is an improvement opportunity, not a defect, so the request is perfective. |
| **Request Type** | ☐ Bug Fix<br>☑ Feature Enhancement<br>☐ Performance Optimization<br>☐ Security Update<br>☐ Compatibility Update<br>☐ Other: ______ |
| **Maintenance Type** | ☐ Corrective<br>☑ Perfective<br>☐ Adaptive<br>☐ Preventive |
| **Severity** | ☐ High  ☐ Medium  ☑ Low |
| **Priority** | ☐ High  ☑ Medium  ☐ Low |
