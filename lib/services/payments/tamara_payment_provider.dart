import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/services/payments/payment_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Installment payment through Tamara. The order is saved as pending first;
/// the Tamara webhook (Cloud Function) later marks it paid and marks the
/// products sold, so nothing is left to do in the app afterwards.
class TamaraPaymentProvider implements PaymentProvider {
  /// [waitForResult] shows the waiting UI and returns 'paid', 'failed' or
  /// 'canceled' for the given order id.
  TamaraPaymentProvider({required this.waitForResult});

  static const String _createTamaraCheckoutUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createTamaraCheckout';

  final Future<String> Function(String orderId) waitForResult;

  @override
  CheckoutPaymentMethod get method => CheckoutPaymentMethod.tamara;

  @override
  bool get savesOrderBeforePayment => true;

  @override
  Future<PaymentOutcome> pay(PaymentRequest request) async {
    final orderId = request.orderId;
    if (orderId == null || orderId.isEmpty) {
      throw StateError('Tamara payment needs a saved order id.');
    }

    final checkout = await _createTamaraCheckout(
      request.user,
      orderId,
      request.items,
    );
    final launched = await launchUrl(
      Uri.parse(checkout.checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open the Tamara payment page.');
    }

    final result = await waitForResult(orderId);
    if (result == 'paid') {
      return PaymentOutcome.paid(reference: checkout.tamaraOrderId);
    }
    return PaymentOutcome.failed(
      result == 'failed'
          ? 'Tamara could not approve this payment.'
          : 'Tamara payment was canceled.',
    );
  }

  @override
  Future<void> onOrderSaved(PaidOrder order) async {}

  @override
  Future<void> settleWithSellers(PaidOrder order) async {}

  Future<_TamaraCheckout> _createTamaraCheckout(
    User user,
    String orderId,
    List<Cart> purchasedItems,
  ) async {
    final httpClient = HttpClient();

    try {
      final idToken = await user.getIdToken();
      final request = await httpClient.postUrl(
        Uri.parse(_createTamaraCheckoutUrl),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'orderId': orderId,
          'items': paymentItemsPayload(purchasedItems),
        }),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Tamara checkout request failed (${response.statusCode}): $responseBody',
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected Tamara response format.');
      }

      final checkoutUrl = (decoded['checkoutUrl'] as String? ?? '').trim();
      final tamaraOrderId = (decoded['tamaraOrderId'] as String? ?? '').trim();
      if (checkoutUrl.isEmpty || tamaraOrderId.isEmpty) {
        throw Exception('Tamara response did not include a checkout URL.');
      }

      return _TamaraCheckout(
        checkoutUrl: checkoutUrl,
        tamaraOrderId: tamaraOrderId,
      );
    } finally {
      httpClient.close(force: true);
    }
  }
}

class _TamaraCheckout {
  const _TamaraCheckout({
    required this.checkoutUrl,
    required this.tamaraOrderId,
  });

  final String checkoutUrl;
  final String tamaraOrderId;
}
