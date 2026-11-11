import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/services/payments/payment_provider.dart';

/// Card payment through Stripe: the buyer pays in the Stripe PaymentSheet,
/// then the order is saved and the sellers are paid by transfer.
class StripePaymentProvider implements PaymentProvider {
  static const String _createPaymentIntentUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createMarketplacePaymentIntent';
  static const String _finalizeMarketplaceOrderUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/finalizeMarketplaceOrder';

  @override
  CheckoutPaymentMethod get method => CheckoutPaymentMethod.card;

  @override
  bool get savesOrderBeforePayment => false;

  @override
  Future<PaymentOutcome> pay(PaymentRequest request) async {
    final paymentIntent = await _createMarketplacePaymentIntent(
      request.user,
      request.items,
    );

    try {
      await _presentPaymentSheet(paymentIntent.clientSecret);
    } on StripeException catch (e) {
      return PaymentOutcome.failed(
        e.error.localizedMessage ?? 'Payment cancelled.',
      );
    } catch (e) {
      return PaymentOutcome.failed('Payment failed: $e');
    }

    return PaymentOutcome.paid(reference: paymentIntent.paymentIntentId);
  }

  @override
  Future<void> onOrderSaved(PaidOrder order) async {
    try {
      await _markProductsSold(order.productIds);
    } on FirebaseException catch (e) {
      debugPrint('PRODUCT STATUS UPDATE ERROR (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> settleWithSellers(PaidOrder order) async {
    final httpClient = HttpClient();

    try {
      final idToken = await order.user.getIdToken();
      final request = await httpClient.postUrl(
        Uri.parse(_finalizeMarketplaceOrderUrl),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'orderId': order.orderId,
          'paymentIntentId': order.reference,
          'items': paymentItemsPayload(order.items),
        }),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Marketplace transfer request failed (${response.statusCode}): $responseBody',
        );
      }
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<void> _presentPaymentSheet(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'Souqplus',
        paymentIntentClientSecret: clientSecret,
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }

  Future<_MarketplacePaymentIntent> _createMarketplacePaymentIntent(
    User user,
    List<Cart> purchasedItems,
  ) async {
    final httpClient = HttpClient();

    try {
      final idToken = await user.getIdToken();
      final request = await httpClient.postUrl(
        Uri.parse(_createPaymentIntentUrl),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'items': paymentItemsPayload(purchasedItems),
        }),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Payment intent request failed (${response.statusCode}): $responseBody',
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected payment response format.');
      }

      final clientSecret =
          (decoded['clientSecret'] as String? ??
                  decoded['client_secret'] as String?)
              ?.trim();
      final paymentIntentId = (decoded['paymentIntentId'] as String? ?? '')
          .trim();

      if (clientSecret == null ||
          clientSecret.isEmpty ||
          paymentIntentId.isEmpty) {
        throw Exception('Payment response did not include a clientSecret.');
      }

      return _MarketplacePaymentIntent(
        clientSecret: clientSecret,
        paymentIntentId: paymentIntentId,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<void> _markProductsSold(List<String> productIds) async {
    if (productIds.isEmpty) return;

    final batch = db.batch();
    for (final productId in productIds) {
      batch.set(db.collection('products').doc(productId), {
        'status': 'Sold',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

class _MarketplacePaymentIntent {
  const _MarketplacePaymentIntent({
    required this.clientSecret,
    required this.paymentIntentId,
  });

  final String clientSecret;
  final String paymentIntentId;
}
