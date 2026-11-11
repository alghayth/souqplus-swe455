import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/models/product.dart';
import 'package:souqplus/services/payments/payment_provider.dart';
import 'package:souqplus/services/payments/stripe_payment_provider.dart';
import 'package:souqplus/services/payments/tamara_payment_provider.dart';

void main() {
  group('PaymentProvider implementations', () {
    test('Stripe saves the order after the payment', () {
      final provider = StripePaymentProvider();

      expect(provider.method, CheckoutPaymentMethod.card);
      expect(provider.savesOrderBeforePayment, isFalse);
    });

    test('Tamara saves the order before the payment', () {
      final provider = TamaraPaymentProvider(
        waitForResult: (orderId) async => 'paid',
      );

      expect(provider.method, CheckoutPaymentMethod.tamara);
      expect(provider.savesOrderBeforePayment, isTrue);
    });

    test('every checkout payment method has its own provider type', () {
      final providers = <PaymentProvider>[
        StripePaymentProvider(),
        TamaraPaymentProvider(waitForResult: (orderId) async => 'paid'),
      ];

      expect(
        providers.map((p) => p.method).toSet(),
        CheckoutPaymentMethod.values.toSet(),
      );
    });
  });

  group('PaymentOutcome', () {
    test('paid outcome carries the provider reference', () {
      const outcome = PaymentOutcome.paid(reference: 'pi_123');

      expect(outcome.isPaid, isTrue);
      expect(outcome.reference, 'pi_123');
      expect(outcome.message, isNull);
    });

    test('failed outcome carries the message for the buyer', () {
      const outcome = PaymentOutcome.failed('Payment cancelled.');

      expect(outcome.isPaid, isFalse);
      expect(outcome.message, 'Payment cancelled.');
    });
  });

  test('paymentItemsPayload keeps product id and quantity only', () {
    final product = Product(
      id: 1,
      images: const [],
      colors: const [],
      title: 'Shoes',
      price: 100,
      description: 'd',
      firestoreId: 'abc',
    );

    final payload = paymentItemsPayload([Cart(product: product, numOfItem: 2)]);

    expect(payload, [
      {'productFirestoreId': 'abc', 'quantity': 2},
    ]);
  });
}
