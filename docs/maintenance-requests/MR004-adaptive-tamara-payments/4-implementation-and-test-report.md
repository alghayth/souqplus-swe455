# Implementation and Test Report — MR004

**Branch:** `person4-tamara-mr` · **Date:** 2026-10-09

## 1. Changes made

### `functions/tamara.js` (new)
| Function | Purpose |
|---|---|
| `getTamaraConfig` | Reads `TAMARA_API_URL` (default: Tamara sandbox), `TAMARA_API_TOKEN`, `TAMARA_NOTIFICATION_TOKEN` |
| `buildTamaraCheckoutPayload` | Builds the `POST /checkout` body from server-verified items (prices come from Firestore, never from the app); amounts are converted from halalas to SAR |
| `createTamaraCheckoutSession` / `authoriseTamaraOrder` | Calls `POST /checkout` and `POST /orders/{id}/authorise` |
| `verifyTamaraWebhookToken` | Verifies the HS256 JWT signature (constant-time compare) and expiry |
| `paymentStatusForTamaraEvent` | Maps `order_approved`, `order_authorised`, `order_declined`, `order_canceled`, `order_expired` to an order status |

### `functions/index.js`
| Function | Change |
|---|---|
| `createTamaraCheckout` | New. Checks the Firebase token, that the order belongs to the caller and is a pending Tamara order, creates the Tamara session, stores `tamaraOrderId`, returns `checkoutUrl` |
| `tamaraWebhook` | New. Verifies the signature, matches `tamaraOrderId`, ignores unknown events, is idempotent for paid orders. On `order_approved` it authorises the order, sets `paid` and `sellerTransferStatus: awaiting_tamara_settlement`, and marks products `Sold`. Failed and canceled events set `canceled` |
| `tamaraReturn` | New. Simple page shown after leaving Tamara (success, failure, cancel) |

### `lib/screens/cart/checkout_screen.dart`
| Location | Change |
|---|---|
| `_PaymentMethod`, selector widget | New Card / Tamara choice; button text changes to "Pay with Tamara" |
| `_saveOrder` | Records `paymentProvider`; Tamara orders start as `pending` and have no Stripe `paymentIntentId`. The Stripe path writes the same data as before |
| `_placeOrder` | New branch to `_placeTamaraOrder` before the Stripe flow |
| `_placeTamaraOrder`, `_createTamaraCheckout`, `_waitForTamaraPayment`, `_closeUnpaidOrder` | Save pending order, get checkout URL, open it, wait for the webhook result (or Cancel / 10-minute timeout), then finish or close the order |

## 2. Automated tests

| Command | Result |
|---|---|
| `npm test` in `functions/` | **5/5 passed** |
| `flutter test` | **12/12 passed** (existing tests, no regressions) |
| `flutter analyze lib/screens/cart/checkout_screen.dart` | **No issues found** |
| `node --check functions/index.js` | OK |

Unit tests in `functions/test/tamara.test.js`: payload amounts and names,
valid webhook signature accepted, wrong secret / malformed / expired / missing
token rejected, event-to-status mapping, sandbox default.

## 3. Manual test plan (needs Tamara sandbox credentials)

| # | Scenario | Expected |
|---|---|---|
| 1 | Pay with Card | Same as before the change |
| 2 | Tamara, approve in sandbox | Webhook sets `paid`; waiting dialog closes; cart cleared; success dialog; products `Sold` |
| 3 | Tamara, press Cancel payment | Order becomes `canceled`; cart kept |
| 4 | Tamara, declined | Event `order_declined`; order `canceled`; message shown |
| 5 | No answer in 10 minutes | Dialog closes; order `canceled` |
| 6 | Webhook with a wrong token | HTTP 401; order unchanged |
| 7 | Webhook sent twice | Second call returns `paid` without changing anything |

## 4. Configuration needed before deploying

```
TAMARA_API_URL=https://api-sandbox.tamara.co   # production: https://api.tamara.co
TAMARA_API_TOKEN=<merchant API token>
TAMARA_NOTIFICATION_TOKEN=<notification token>
```

Register `https://us-central1-souqplus-1bb34.cloudfunctions.net/tamaraWebhook`
as the notification URL in the Tamara merchant portal.

## 5. Known limitations

- The scenarios in section 3 were not run against Tamara, because no sandbox credentials were available. Only the checks in section 2 were run.
- Seller payouts for Tamara orders are not automated (`awaiting_tamara_settlement`).
- Products are not reserved while the customer is on Tamara's page.
- Tamara's amount limits and availability check are not applied before showing the option.
