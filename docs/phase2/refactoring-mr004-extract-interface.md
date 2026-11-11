# Refactoring Form — Refactoring #4 (Extract Interface)

**SWE 455 — Phase 2 · Part 4 — Refactoring** · Tojan Alnajjar · Module: Payments (MR004)

| Item | Description |
|---|---|
| **Code smell** | **Divergent Change.** `CheckoutScreen` had to change for several unrelated reasons: a change to the Stripe flow, a change to the Tamara flow, or a new payment method each meant editing the same class. After MR004 the screen held both providers (about 1,200 lines). |
| **Refactoring Type** | **Extract Interface** (major). A `PaymentProvider` interface was extracted, with one implementation per provider. |
| **Affected Class(es)** | `lib/screens/cart/checkout_screen.dart` (`_CheckoutScreenState`). New files: `lib/services/payments/payment_provider.dart`, `stripe_payment_provider.dart`, `tamara_payment_provider.dart`. |
| **Original Code** | See block 1 below. |
| **Code After Refactoring** | See blocks 2 and 3 below. |
| **Explanation** | See below. |
| **Validation / Testing Type** | ☐ Manual ☒ Automated |
| **Test Description** | `flutter analyze` (no issues); `flutter test`: the 12 existing tests plus 6 new tests in `test/services/payment_provider_test.dart` (provider contract: Stripe saves the order after payment, Tamara before; every payment method has its own provider; outcome values; the items payload sent to the Cloud Functions). `npm test` in `functions/` (5 Tamara tests) is unchanged. |
| **Expected Result** | Checkout behaves exactly as before for both payment methods. The screen depends only on `PaymentProvider`. |
| **Actual Result** | 18/18 Flutter tests pass and `flutter analyze` reports no issues. `checkout_screen.dart` went from 1,212 to 960 lines. The real payment flows (Stripe test mode, Tamara sandbox) were **not** run end to end, because the required credentials and a device were not available. |

## 1. Original Code (before)

```dart
// checkout_screen.dart — _placeOrder: provider-specific code is inside the screen
if (_paymentMethod == _PaymentMethod.tamara) {
  await _placeTamaraOrder(                      // Tamara: its own method in the screen
    user: user,
    deliveryAddress: deliveryAddress,
    purchasedItems: purchasedItems,
  );
  return;
}

final paymentIntent = await _createMarketplacePaymentIntent(user, purchasedItems);
try {
  await _presentPaymentSheet(paymentIntent.clientSecret);   // Stripe inline
} on StripeException catch (e) {
  _showSnack(e.error.localizedMessage ?? 'Payment cancelled.');
  return;
} catch (e) {
  _showSnack('Payment failed: $e');
  return;
}
// ... save order, notification, mark sold ...
await _finalizeMarketplaceOrder(/* Stripe transfers to sellers */);

// The same screen also contained:
//   _presentPaymentSheet, _createMarketplacePaymentIntent, _finalizeMarketplaceOrder,
//   _markProductsSold, _createTamaraCheckout, _placeTamaraOrder, three URL constants.
```

## 2. Code After Refactoring: the interface

```dart
// lib/services/payments/payment_provider.dart
enum CheckoutPaymentMethod { card, tamara }

abstract class PaymentProvider {
  CheckoutPaymentMethod get method;

  /// True if the order must be saved (as pending) before the buyer pays.
  bool get savesOrderBeforePayment;

  Future<PaymentOutcome> pay(PaymentRequest request);
  Future<void> onOrderSaved(PaidOrder order);
  Future<void> settleWithSellers(PaidOrder order);
}

class StripePaymentProvider implements PaymentProvider { /* PaymentSheet, transfers */ }
class TamaraPaymentProvider implements PaymentProvider { /* checkout URL, webhook wait */ }
```

## 3. Code After Refactoring: the screen

```dart
// checkout_screen.dart — _placeOrder now depends only on the interface
final provider = _paymentProviders[_paymentMethod]!;

_SavedOrderResult? savedOrder;
if (provider.savesOrderBeforePayment) {
  savedOrder = await _saveOrder(/* ... */ paymentMethod: provider.method);
}

final outcome = await provider.pay(
  PaymentRequest(user: user, items: purchasedItems, orderId: savedOrder?.orderId),
);
if (!outcome.isPaid) {
  if (savedOrder != null) await _closeUnpaidOrder(savedOrder.orderId);
  _showSnack(outcome.message ?? 'Payment failed.');
  return;
}

if (savedOrder == null) {
  savedOrder = await _saveOrder(/* ... */ paymentIntentId: outcome.reference);
}
final paidOrder = PaidOrder(/* ... */);
await _createPaymentConfirmationNotification(/* ... */);
await provider.onOrderSaved(paidOrder);
// ... clear cart, success dialog ...
await provider.settleWithSellers(paidOrder);
```

## Explanation

**Why this smell.** After MR004 the checkout screen was changing for two unrelated reasons (Stripe and Tamara), and a third payment method would have added a third reason. This is Divergent Change: one class, many reasons to change.

**Why Extract Interface.** The two payment flows do the same jobs in a different way: charge the buyer, save the order, and settle with the sellers. Those jobs are now the three methods of `PaymentProvider` (`pay`, `onOrderSaved`, `settleWithSellers`). The one real difference, *when* the order is saved, is the property `savesOrderBeforePayment`.

**Benefits.**
- **Single reason to change:** a Stripe change touches only `stripe_payment_provider.dart`; a Tamara change touches only `tamara_payment_provider.dart`; the screen stays untouched.
- **Easy to extend:** a new provider is a new class that implements the interface and one entry in the provider map.
- **Smaller, more readable screen:** 252 fewer lines, and `_placeOrder` has no `if (tamara)` branches or Stripe-specific code.
- **Testable:** the contract is covered by unit tests, which was not possible while the code lived inside the screen.
- **Less duplication:** the cart-to-request conversion that appeared three times is one function, `paymentItemsPayload`.

**Behavior preserved.** The code of each provider was moved without logic changes. Two small differences, both in rare edge cases: if the buyer closes the checkout screen while the Tamara waiting dialog should open, the unpaid order is now closed as canceled instead of being left pending, and the "payment cancelled / failed" messages come from the provider's outcome instead of being shown inside the screen's `catch` blocks (same text).

**Related slicing.** The dynamic forward slice in `slicing-mr004-dynamic-forward.md` shows which statements depend on the provider selection after this refactoring.
