# Form 1 — Maintenance Request Form

**SWE 455 — Phase 1 · Part 2 — Maintenance Request (MR004)**
Adaptive maintenance: integrate the Tamara API for installment payments in the Payments module (SouqPlus) · Tojan

| Field | Value |
|---|---|
| **MR ID** | MR004 |
| **Date Logged** | 2026-10-09 |
| **Reported By** | Tojan |
| **Change / Request Name** | Integrate the Tamara API for installment payments in the Payments module |
| **Description** | Add "Pay with Tamara" (buy now, pay later in installments) as a second payment method at checkout, next to the existing Stripe card payment. The app creates a pending order, the backend creates a Tamara checkout session, the customer completes the plan on Tamara's page, and a Tamara webhook confirms and authorises the payment. Expected outcome: customers can split a purchase into installments, and Stripe card payments keep working unchanged. |
| **Justification** | The Payments module only supports full card payment through Stripe. Installment payment is common and expected in Saudi Arabia, and Tamara is a widely used provider there. Supporting it adapts the system to the external payment environment and can increase completed purchases for higher-priced items. |
| **Request Type** | ☐ Bug Fix<br>☑ Feature Enhancement<br>☐ Performance Optimization<br>☐ Security Update<br>☑ Compatibility Update (new external API)<br>☐ Other |
| **Maintenance Type** | ☐ Corrective<br>☐ Perfective<br>☑ Adaptive<br>☐ Preventive |
| **Severity** | ☐ High ☑ Medium ☐ Low |
| **Priority** | ☐ High ☑ Medium ☐ Low |

## Appendix — Why the current code cannot support it directly

| # | File | Location | Limitation |
|---|---|---|---|
| 1 | `checkout_screen.dart` | `_placeOrder` | The only path is Stripe PaymentSheet, and there is no payment-method choice |
| 2 | `checkout_screen.dart` | `_saveOrder` | Always writes `paymentStatus: 'paid'` and a Stripe `paymentIntentId` |
| 3 | `functions/index.js` | whole file | No Tamara endpoint and no webhook receiver |
| 4 | `functions/index.js` | `finalizeMarketplaceOrder` | Seller transfers depend on a Stripe charge, which does not exist for Tamara payments |
