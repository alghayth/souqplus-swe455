import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/models/cart.dart';

/// The payment methods the buyer can choose at checkout.
enum CheckoutPaymentMethod { card, tamara }

/// What a provider needs to charge the buyer.
class PaymentRequest {
  const PaymentRequest({
    required this.user,
    required this.items,
    this.orderId,
  });

  final User user;
  final List<Cart> items;

  /// Set only for providers that save the order before the buyer pays
  /// (see [PaymentProvider.savesOrderBeforePayment]).
  final String? orderId;
}

/// Result of [PaymentProvider.pay].
class PaymentOutcome {
  const PaymentOutcome.paid({required this.reference})
      : isPaid = true,
        message = null;

  const PaymentOutcome.failed(this.message)
      : isPaid = false,
        reference = '';

  final bool isPaid;

  /// Provider reference of the payment (Stripe PaymentIntent id, Tamara order id).
  final String reference;

  /// Message to show the buyer when the payment did not go through.
  final String? message;
}

/// An order that has been paid and saved.
class PaidOrder {
  const PaidOrder({
    required this.user,
    required this.orderId,
    required this.reference,
    required this.items,
    required this.productIds,
  });

  final User user;
  final String orderId;
  final String reference;
  final List<Cart> items;
  final List<String> productIds;
}

/// One way of paying for an order. Checkout talks only to this interface, so a
/// new payment method needs a new implementation, not changes to the screen.
abstract class PaymentProvider {
  CheckoutPaymentMethod get method;

  /// True if the order must exist (as pending) before the buyer pays, because
  /// the provider confirms the payment later by webhook (Tamara). False if the
  /// order is saved after the payment succeeds (Stripe).
  bool get savesOrderBeforePayment;

  /// Charges the buyer. Returns a failed outcome when the buyer cancels or the
  /// provider declines; throws for unexpected errors.
  Future<PaymentOutcome> pay(PaymentRequest request);

  /// Called right after a paid order has been saved.
  Future<void> onOrderSaved(PaidOrder order);

  /// Called after the buyer has been told the order succeeded.
  Future<void> settleWithSellers(PaidOrder order);
}

/// The cart items in the shape the Cloud Functions expect.
List<Map<String, dynamic>> paymentItemsPayload(List<Cart> items) {
  return items
      .map(
        (item) => <String, dynamic>{
          'productFirestoreId': item.product.firestoreId,
          'quantity': item.numOfItem,
        },
      )
      .toList();
}
