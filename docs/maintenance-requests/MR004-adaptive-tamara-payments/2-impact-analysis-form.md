# Form 2 — Impact Analysis Form

| Field | Value |
|---|---|
| **MR ID** | MR004 |
| **Current State** | Checkout supports only Stripe card payment. The order is saved after the payment succeeds, with `paymentStatus: 'paid'`. |
| **Future State** | Checkout offers Card or Tamara. A Tamara order is saved first as `paymentStatus: 'pending'`, becomes `paid` only when the verified Tamara webhook confirms it, and is closed as `canceled` if the customer cancels, the payment fails, or 10 minutes pass. The card flow is unchanged. |
| **Gap / Required Change** | New backend: `functions/tamara.js` (API client, payload builder, webhook signature check) and three functions in `index.js` (`createTamaraCheckout`, `tamaraWebhook`, `tamaraReturn`). New client code in `checkout_screen.dart`: payment-method selector, Tamara branch in `_placeOrder`, waiting dialog. New order fields: `paymentProvider`, `tamaraOrderId`, `tamaraCheckoutId`, `tamaraLastEvent`. |
| **Alternative Solutions** | 1) Embed Tamara's SDK/WebView (needs a native SDK and more app changes). 2) Create the order only after payment (no pending order, but the webhook then has no order to update). 3) Let the client call Tamara directly (rejected: the API token must stay on the server). **Chosen:** hosted checkout page, server-side session creation, webhook confirmation, and a pending order. |
| **Timing of Impact** | ☐ Immediate ☑ Short-term ☐ Long-term |
| **Level of Impact** | ☐ Low ☑ Medium ☐ High |
| **Type of Impact** | ☑ Functional ☑ UI/UX ☐ Performance ☑ Security ☐ Other |
| **Scale of Change** | ☐ Organization ☐ Program ☐ Project ☑ Module |
| **Module / Component** | Payments: `lib/screens/cart/checkout_screen.dart`, `functions/index.js`, new `functions/tamara.js`, new `functions/test/tamara.test.js`. |
| **Dependencies & Affected Components** | Tamara API (new external dependency; sandbox by default), Cloud Firestore `orders` and `products`, `url_launcher` (already used), Notifications (payment confirmation is reused), purchase history and the admin payments screen (they now see a new `paymentProvider` and the `pending`, `canceled` statuses), Delivery (reads orders with `status: ordered`). |
| **Key Risks** | 1) Seller payouts: Tamara pays the platform, not the sellers, so Tamara orders are marked `sellerTransferStatus: awaiting_tamara_settlement` and need a separate settlement process. 2) The webhook is public, so it is protected by HS256 signature verification with the Tamara notification token. 3) A webhook arriving after the customer pressed cancel could mark the order paid; the order is not lost, but it needs manual review. 4) Product reservation: products are marked `Sold` only on payment, so two buyers could start Tamara checkout on the same product. 5) Tamara credentials are not committed; they are read from environment variables. |
| **Roles Affected** | Buyers (new option), admins (new order states), sellers (settlement for Tamara orders is delayed), developers. |
| **Number Affected** | All buyers see the new option. Code change: 3 files plus tests and docs. |
| **Communication Requirements** | Pull Request description, a note to the Delivery and Notifications owners about the new `pending`/`canceled` order states. |
| **Training Requirements** | Admins should know the Tamara order states. |
| **Leadership Oversight** | The team lead or course instructor reviews the Pull Request. |
| **Alignment & Collaboration Needed** | Munirah (Notifications reuse), Person 5 (Delivery reads orders), Noura (listings fields). |
| **Resources Required** | 1 developer, Tamara sandbox merchant credentials (`TAMARA_API_TOKEN`, `TAMARA_NOTIFICATION_TOKEN`), existing Firebase project. No paid service in development. |
