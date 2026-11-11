# Slicing Form — Slicing #4 (Dynamic · Forward)

**SWE 455 — Phase 2 · Part 3 — Program Slicing** · Tojan Alnajjar · Module: Payments (MR004)

Line numbers refer to the code **after maintenance** (branch `person4-refactoring`).

| Item | Description |
|---|---|
| **Slicing Criteria** | Variable `provider` at line 616 of `_placeOrder` (`final provider = _paymentProviders[_paymentMethod]!;`), for this **execution scenario**: the buyer selects **Tamara**, the Tamara checkout opens, the buyer approves, and the webhook sets the order to `paid`. Question: which executed statements are affected by the payment-provider selection? |
| **Slicing Type** | **Dynamic · Forward.** Dynamic: only the statements actually executed in this scenario are considered. Forward: we start at the selection and follow its effects forward. |
| **Justification** | MR004 adds a second payment method, and the maintenance risk is: *when the provider changes, what else changes?* A forward slice from the selection shows every statement that depends on it, so a maintainer knows what to re-test when a provider is added or changed. A dynamic slice for one real scenario keeps the result small and exact, because the checkout contains two different paths (Stripe and Tamara) and a static slice would mix them. |
| **Original Code** | `_placeOrder`, lines 599–689 (shortened here; comments added). See the block below this table. |
| **Slicing Result** | The code after slicing is in the second block below: 11 statements of `_placeOrder`, plus the dependent statements in `_saveOrder` and `TamaraPaymentProvider.pay`, out of about 90 lines of the method. |
| **File / Class name** | `lib/screens/cart/checkout_screen.dart` (`_CheckoutScreenState._placeOrder`, `_saveOrder`), `lib/services/payments/tamara_payment_provider.dart` (`TamaraPaymentProvider.pay`, `onOrderSaved`, `settleWithSellers`). |
| **Explanation** | See the explanation after the code blocks. |
| **Tool Usage (Optional)** | No automatic slicer was used (none is available for Dart). The execution path was traced by hand through the code. The provider choices that drive the trace (`savesOrderBeforePayment` is `true` for Tamara, `false` for Stripe; the outcome of a paid payment) are checked by the unit tests in `test/services/payment_provider_test.dart` (18/18 tests pass with `flutter test`). The scenario was **not** run against the real Tamara service, because no Tamara sandbox credentials were available. |

## Original Code (before slicing)

```dart
// checkout_screen.dart — _CheckoutScreenState._placeOrder (shortened)
final user = FirebaseAuth.instance.currentUser;                  // 599
final purchasedItems = List<Cart>.from(_cartItems);              // 600
// ... login check and _validateCheckoutItems (lines 602-614) ...

final provider = _paymentProviders[_paymentMethod]!;             // 616  <-- criterion

// Providers that confirm by webhook need the order to exist first.
_SavedOrderResult? savedOrder;                                   // 619
if (provider.savesOrderBeforePayment) {                          // 620
  savedOrder = await _saveOrder(                                 // 621
    user: user,
    deliveryAddress: deliveryAddress,
    purchasedItems: purchasedItems,
    paymentMethod: provider.method,                              // 625
  );
}

final PaymentOutcome outcome;                                    // 629
try {
  outcome = await provider.pay(                                  // 631
    PaymentRequest(
      user: user,
      items: purchasedItems,
      orderId: savedOrder?.orderId,                              // 635
    ),
  );
} catch (e) {                                                    // 638
  if (savedOrder != null) {
    await _closeUnpaidOrder(savedOrder.orderId);
  }
  rethrow;
}

if (!outcome.isPaid) {                                           // 645
  if (savedOrder != null) {
    await _closeUnpaidOrder(savedOrder.orderId);
  }
  _showSnack(outcome.message ?? 'Payment failed.');
  return;
}

if (savedOrder == null) {                                        // 653
  if (!mounted) return;
  savedOrder = await _saveOrder(/* Stripe: order saved after payment */);
}

final paidOrder = PaidOrder(                                     // 664
  user: user,
  orderId: savedOrder.orderId,
  reference: outcome.reference,
  items: purchasedItems,
  productIds: savedOrder.productIds,
);

await _createPaymentConfirmationNotification(                    // 672
  user: user,
  orderId: paidOrder.orderId,
  paymentIntentId: paidOrder.reference,
);

await provider.onOrderSaved(paidOrder);                          // 678

_clearPurchasedItems(purchasedItems);                            // 680
if (!mounted) return;                                            // 682
await _showOrderPlacedSuccess();                                 // 683

try {
  await provider.settleWithSellers(paidOrder);                   // 686
} catch (e) {
  debugPrint('ORDER FINALIZATION ERROR: $e');
}
```

## Slicing Result (dynamic forward slice, scenario: Tamara, approved)

```dart
// ===== checkout_screen.dart — _placeOrder =====
final provider = _paymentProviders[_paymentMethod]!;             // 616  CRITERION
_SavedOrderResult? savedOrder;                                   // 619  assigned inside the provider branch below
if (provider.savesOrderBeforePayment) {                          // 620  control-dependent on provider -> TRUE
  savedOrder = await _saveOrder(                                 // 621  executed
    /* ... */ paymentMethod: provider.method,                    // 625  data-dependent on provider
  );
}

outcome = await provider.pay(                                    // 631  provider decides what runs
  PaymentRequest(/* ... */ orderId: savedOrder?.orderId),        // 635  uses savedOrder from line 621
);

if (!outcome.isPaid) { /* skipped */ }                           // 645  condition uses outcome -> FALSE
if (savedOrder == null) { /* skipped */ }                        // 653  condition uses savedOrder -> FALSE

final paidOrder = PaidOrder(                                     // 664  built from outcome and savedOrder
  orderId: savedOrder.orderId,
  reference: outcome.reference,
  productIds: savedOrder.productIds, /* ... */
);

await _createPaymentConfirmationNotification(                    // 672  uses paidOrder
  orderId: paidOrder.orderId,
  paymentIntentId: paidOrder.reference,
);

await provider.onOrderSaved(paidOrder);                          // 678  Tamara: empty method
await provider.settleWithSellers(paidOrder);                     // 686  Tamara: empty method

// ===== checkout_screen.dart — _saveOrder (called from line 621) =====
final isTamara = paymentMethod == CheckoutPaymentMethod.tamara;  // 261
'paymentProvider': isTamara ? 'tamara' : 'stripe',               // 300
if (!isTamara) 'paymentIntentId': paymentIntentId,               // 301  not added for Tamara
'paymentStatus': isTamara ? 'pending' : 'paid',                  // 303  -> 'pending'

// ===== tamara_payment_provider.dart — TamaraPaymentProvider.pay (called from line 631) =====
final checkout = await _createTamaraCheckout(/* ... */);         // 35   Cloud Function createTamaraCheckout
final launched = await launchUrl(/* checkout.checkoutUrl */);   // 40   opens the Tamara page
final result = await waitForResult(orderId);                     // 48   -> _waitForTamaraPayment (checkout_screen 465)
return PaymentOutcome.paid(reference: checkout.tamaraOrderId);   // 50   result == 'paid'
```

## Explanation

**What the slice shows.** In this scenario the selection of the provider at line 616 controls three things:

1. **Which path runs.** `provider.savesOrderBeforePayment` (line 620) is `true`, so the order is saved *before* the payment (line 621) with `paymentStatus = 'pending'` and no Stripe `paymentIntentId` (lines 300–303). Because `savedOrder` is now set, the Stripe-only save at line 653 is skipped.
2. **What the payment does.** `provider.pay` (line 631) runs the Tamara steps: create the checkout (35), open the Tamara page (40), wait for the webhook result (48), and return a paid outcome (50).
3. **What happens after the payment.** The values `outcome.reference` and `savedOrder` flow into `paidOrder` (664) and then into the confirmation notification (672). The two provider hooks at lines 678 and 686 are empty for Tamara, because the Cloud Function `tamaraWebhook` already marked the order paid and the products sold.

**What is not in the slice.** Validation (602–614), clearing the cart (680) and the success dialog (683) run in every scenario and do not depend on the provider. All Stripe code (`StripePaymentProvider`, the PaymentSheet, `finalizeMarketplaceOrder`) is not executed in this scenario, so a dynamic slice leaves it out; a static slice would have included it.

**Relevance to maintenance.**
- The slice is the *impact set* of the provider selection. When a maintainer changes how Tamara payments work, these are the statements to review and re-test: the provider branch (620), the `pay` call (631), the order fields (300–303), and the way `paidOrder` is built (664).
- It explains the design after the refactoring (Part 4): the provider-specific behaviour is now behind the interface (`pay`, `onOrderSaved`, `settleWithSellers`), so the slice crosses the screen/provider boundary only at those calls.
- It also shows a **dependency to remember**: the Stripe-only save at line 653 works only because `savedOrder` is still `null` for Stripe. A third provider must set `savesOrderBeforePayment` correctly, or it would create two orders.

## Execution trace of the scenario

| Step | Line | Statement | Executed | In the slice |
|---|---|---|---|---|
| 1 | 599–614 | user, items, validation | yes | no (independent of the provider) |
| 2 | 616 | `provider = _paymentProviders[_paymentMethod]!` | yes | **criterion** |
| 3 | 620 | `if (provider.savesOrderBeforePayment)` | yes → true | yes |
| 4 | 621 | `savedOrder = await _saveOrder(...)` | yes | yes |
| 5 | 631 | `outcome = await provider.pay(...)` | yes | yes |
| 6 | 645 | `if (!outcome.isPaid)` | yes → false | yes |
| 7 | 653 | `if (savedOrder == null)` | yes → false | yes |
| 8 | 664 | `paidOrder = PaidOrder(...)` | yes | yes |
| 9 | 672 | confirmation notification | yes | yes |
| 10 | 678 | `provider.onOrderSaved(paidOrder)` | yes (empty) | yes |
| 11 | 680–683 | clear cart, success dialog | yes | no (independent) |
| 12 | 686 | `provider.settleWithSellers(paidOrder)` | yes (empty) | yes |
| — | 638–643, 646–650 | error and failure branches | no | no (not executed) |
| — | 654–661 | Stripe save after payment | no | no (not executed) |
