import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:souqplus/main.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/screens/profile/purchase_history_screen.dart';
import 'package:souqplus/services/cart_service.dart';
import 'package:souqplus/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PaymentMethod { card, tamara }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.initialItems,
  });

  static String routeName = "/checkout";
  final List<Cart>? initialItems;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const latlng.LatLng _defaultCenter = latlng.LatLng(24.7136, 46.6753);
  static const String _ordersCollection = 'orders';
  static const String _createPaymentIntentUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createMarketplacePaymentIntent';
  static const String _finalizeMarketplaceOrderUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/finalizeMarketplaceOrder';
  static const String _createTamaraCheckoutUrl =
      'https://us-central1-souqplus-1bb34.cloudfunctions.net/createTamaraCheckout';
  static const Duration _tamaraPaymentTimeout = Duration(minutes: 10);

  final MapController _mapController = MapController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();

  latlng.LatLng? _selectedLatLng;
  String? _selectedLocationDetails;

  bool _isLocatingUser = false;
  bool _isResolvingAddress = false;
  bool _isPlacingOrder = false;
  _PaymentMethod _paymentMethod = _PaymentMethod.card;

  List<Cart> get _cartItems =>
      widget.initialItems != null
          ? List<Cart>.unmodifiable(widget.initialItems!)
          : CartService.instance.items;
  double get _cartTotal =>
      _cartItems.fold<double>(0, (total, item) => total + item.lineTotal);
  String? get _checkoutValidationMessage => _validateCheckoutItems(_cartItems);

  @override
  void initState() {
    super.initState();
    _loadSavedBuyerAddress();
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedBuyerAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await db.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final savedAddress = (data?['address'] as String? ?? '').trim();
      if (savedAddress.isNotEmpty && mounted) {
        setState(() {
          _deliveryAddressController.text = savedAddress;
          _selectedLocationDetails ??= savedAddress;
        });
      }
    } catch (_) {
      // Keep checkout usable even if the user profile is missing.
    }
  }

  Future<void> _autoDetectUserLocation() async {
    setState(() => _isLocatingUser = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showSnack('Enable location services');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied');
        return;
      }

      Position? currentPosition;

      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        currentPosition = await Geolocator.getLastKnownPosition();
      }

      if (currentPosition == null) {
        _showSnack('Could not get location');
        return;
      }

      final point = latlng.LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      _mapController.move(point, 16);

      setState(() {
        _selectedLatLng = point;
        _isResolvingAddress = true;
      });

      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (places.isNotEmpty) {
        final resolvedAddress = _placemarkToAddress(places.first);
        setState(() {
          _selectedLocationDetails = resolvedAddress;
          _deliveryAddressController.text = resolvedAddress;
        });
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLocatingUser = false;
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _setPickedLocation(latlng.LatLng point) async {
    setState(() {
      _selectedLatLng = point;
      _isResolvingAddress = true;
    });

    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (places.isNotEmpty) {
        final resolvedAddress = _placemarkToAddress(places.first);
        setState(() {
          _selectedLocationDetails = resolvedAddress;
          _deliveryAddressController.text = resolvedAddress;
        });
      } else {
        setState(() {
          _selectedLocationDetails = "Unknown location";
        });
      }
    } catch (_) {
      setState(() {
        _selectedLocationDetails = "Error getting address";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAddress = false;
        });
      }
    }
  }

  String _placemarkToAddress(Placemark placemark) {
    final parts = [
      placemark.street,
      placemark.locality,
      placemark.administrativeArea,
      placemark.country,
    ].whereType<String>().where((part) => part.trim().isNotEmpty);

    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validateCheckoutItems(List<Cart> items, {String? currentUserId}) {
    final mixedSellerMessage = CartService.instance.mixedSellerMessage(items);
    if (mixedSellerMessage != null) {
      return mixedSellerMessage;
    }

    for (final item in items) {
      final firestoreId = item.product.firestoreId?.trim() ?? '';
      if (firestoreId.isEmpty) {
        return 'This item cannot be purchased yet because it is not linked to a marketplace listing.';
      }

      final sellerStripeAccountId =
          item.product.sellerStripeAccountId?.trim() ?? '';
      if (sellerStripeAccountId.isEmpty) {
        return 'The seller has not finished payment setup for "${item.product.title}".';
      }

      final ownerUid = item.product.ownerUid?.trim() ?? '';
      if (ownerUid.isEmpty) {
        return 'Seller information is missing for "${item.product.title}".';
      }

      if (currentUserId != null && ownerUid == currentUserId) {
        return 'You cannot buy your own product.';
      }
    }

    return null;
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
          'items': purchasedItems
              .map(
                (item) => <String, dynamic>{
                  'productFirestoreId': item.product.firestoreId,
                  'quantity': item.numOfItem,
                },
              )
              .toList(),
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

  Future<_SavedOrderResult> _saveOrder({
    required User user,
    required String deliveryAddress,
    required List<Cart> purchasedItems,
    String paymentIntentId = '',
    _PaymentMethod paymentMethod = _PaymentMethod.card,
  }) async {
    final isTamara = paymentMethod == _PaymentMethod.tamara;
    final purchasedProductIds = purchasedItems
        .map((item) => item.product.firestoreId)
        .whereType<String>()
        .toSet()
        .toList();
    final userDoc = await db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final deliveryLocationDetails =
        (_selectedLocationDetails ?? deliveryAddress).trim();
    final pickupDetails = await _readPickupDetails(purchasedItems);
    final products = purchasedItems
        .map(
          (item) => <String, dynamic>{
            'productId': item.product.id,
            'productFirestoreId': item.product.firestoreId,
            'title': item.product.title,
            'imageUrl': item.product.images.isNotEmpty
                ? item.product.images.first
                : '',
            'priceSar': item.product.price,
            'quantity': item.numOfItem,
            'lineTotalSar': item.lineTotal,
            'sellerUid': item.product.ownerUid ?? '',
            'sellerStripeAccountId': item.product.sellerStripeAccountId ?? '',
          },
        )
        .toList();

    final data = <String, dynamic>{
      'userId': user.uid,
      'buyerName': (userData['fullName'] as String? ?? '').trim(),
      'buyerEmail': (userData['email'] as String? ?? user.email ?? '').trim(),
      'buyerPhoneNumber': (userData['phoneNumber'] as String? ?? '').trim(),
      'currency': 'SAR',
      'products': products,
      'items': products,
      'subtotalSar': _cartTotal,
      'totalPriceSar': _cartTotal,
      'paymentProvider': isTamara ? 'tamara' : 'stripe',
      if (!isTamara) 'paymentIntentId': paymentIntentId,
      // Tamara orders become 'paid' only when the Tamara webhook confirms them.
      'paymentStatus': isTamara ? 'pending' : 'paid',
      'sellerTransferStatus': 'pending',
      'subtotal': _cartTotal,
      'total': _cartTotal,
      'deliveryAddress': deliveryAddress,
      'deliveryLocationDetails': deliveryLocationDetails,
      'pickupLocationDetails': pickupDetails.addressText,
      'pickupAddressText': pickupDetails.addressText,
      'status': 'ordered',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (pickupDetails.latitude != null && pickupDetails.longitude != null) {
      data['pickupAddress'] = <String, dynamic>{
        'details': pickupDetails.addressText,
        'latitude': pickupDetails.latitude,
        'longitude': pickupDetails.longitude,
        'geoPoint': GeoPoint(
          pickupDetails.latitude!,
          pickupDetails.longitude!,
        ),
      };
    }

    if (_selectedLatLng != null) {
      data['buyerDeliveryLocation'] = <String, dynamic>{
        'address': deliveryAddress,
        'details': deliveryLocationDetails,
        'geoPoint': GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),
        'latitude': _selectedLatLng!.latitude,
        'longitude': _selectedLatLng!.longitude,
      };
      data['deliveryGeoPoint'] = GeoPoint(
        _selectedLatLng!.latitude,
        _selectedLatLng!.longitude,
      );
    } else {
      data['buyerDeliveryLocation'] = <String, dynamic>{
        'address': deliveryAddress,
        'details': deliveryLocationDetails,
      };
    }

    final orderRef = db.collection(_ordersCollection).doc();
    await orderRef.set(data);

    return _SavedOrderResult(
      orderId: orderRef.id,
      productIds: purchasedProductIds,
    );
  }

  Future<void> _createPaymentConfirmationNotification({
    required User user,
    required String orderId,
    required String paymentIntentId,
  }) async {
    try {
      await NotificationService.instance.createPaymentConfirmationNotification(
        userId: user.uid,
        orderId: orderId,
        paymentIntentId: paymentIntentId,
        amountSar: _cartTotal,
      );
    } catch (e) {
      debugPrint('PAYMENT NOTIFICATION WRITE ERROR: $e');
    }
  }

  Future<void> _finalizeMarketplaceOrder({
    required User user,
    required String orderId,
    required String paymentIntentId,
    required List<Cart> purchasedItems,
  }) async {
    final httpClient = HttpClient();

    try {
      final idToken = await user.getIdToken();
      final request = await httpClient.postUrl(
        Uri.parse(_finalizeMarketplaceOrderUrl),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'orderId': orderId,
          'paymentIntentId': paymentIntentId,
          'items': purchasedItems
              .map(
                (item) => <String, dynamic>{
                  'productFirestoreId': item.product.firestoreId,
                  'quantity': item.numOfItem,
                },
              )
              .toList(),
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

  void _clearPurchasedItems(List<Cart> purchasedItems) {
    if (widget.initialItems != null) {
      return;
    }
    for (final item in purchasedItems) {
      CartService.instance.removeProduct(item.product);
    }
  }

  Future<_PickupDetails> _readPickupDetails(List<Cart> purchasedItems) async {
    if (purchasedItems.isEmpty) {
      return const _PickupDetails(addressText: 'Pickup address unavailable');
    }

    final firstProductId = purchasedItems.first.product.firestoreId?.trim() ?? '';
    if (firstProductId.isEmpty) {
      return const _PickupDetails(addressText: 'Pickup address unavailable');
    }

    try {
      final productDoc = await db.collection('products').doc(firstProductId).get();
      final productData = productDoc.data() ?? <String, dynamic>{};
      final addressText =
          (productData['pickupLocationDetails'] as String? ?? '').trim();
      final geoPoint = productData['pickupAddress'];

      if (geoPoint is GeoPoint) {
        return _PickupDetails(
          addressText: addressText.isEmpty
              ? 'Seller pickup location'
              : addressText,
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
        );
      }

      if (addressText.isNotEmpty) {
        return _PickupDetails(addressText: addressText);
      }
    } catch (_) {
      // Keep checkout working even if pickup metadata is missing.
    }

    return const _PickupDetails(addressText: 'Pickup address unavailable');
  }

  Future<void> _showOrderPlacedSuccess() async {
    final navigator = Navigator.of(context, rootNavigator: true);

    await showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Order placed"),
        content: const Text("Your order was placed successfully."),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001F54),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                navigator.pop();
                Navigator.of(context).pushReplacementNamed(
                  PurchaseHistoryScreen.routeName,
                );
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Color(0xFF7EC8E3),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          'items': purchasedItems
              .map(
                (item) => <String, dynamic>{
                  'productFirestoreId': item.product.firestoreId,
                  'quantity': item.numOfItem,
                },
              )
              .toList(),
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

  /// Waits until the Tamara webhook updates the order's paymentStatus, the
  /// customer presses "Cancel payment", or the timeout is reached.
  /// Returns 'paid', 'failed' or 'canceled'.
  Future<String> _waitForTamaraPayment(String orderId) async {
    final cancelRequested = Completer<String>();
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Waiting for Tamara'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Complete the payment in Tamara, then return to the app.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!cancelRequested.isCompleted) {
                cancelRequested.complete('canceled');
              }
            },
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );

    final webhookResult = db
        .collection(_ordersCollection)
        .doc(orderId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['paymentStatus'] as String? ?? '')
        .firstWhere(
          (status) =>
              status == 'paid' || status == 'failed' || status == 'canceled',
        );

    String result;
    try {
      result = await Future.any<String>([
        webhookResult,
        cancelRequested.future,
      ]).timeout(_tamaraPaymentTimeout);
    } on TimeoutException {
      result = 'canceled';
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    await dialogFuture;
    return result;
  }

  Future<void> _placeTamaraOrder({
    required User user,
    required String deliveryAddress,
    required List<Cart> purchasedItems,
  }) async {
    // The order is saved first (paymentStatus: pending) so the backend can
    // reference it as Tamara's order_reference_id.
    final savedOrder = await _saveOrder(
      user: user,
      deliveryAddress: deliveryAddress,
      purchasedItems: purchasedItems,
      paymentMethod: _PaymentMethod.tamara,
    );

    final _TamaraCheckout checkout;
    try {
      checkout = await _createTamaraCheckout(
        user,
        savedOrder.orderId,
        purchasedItems,
      );
      final launched = await launchUrl(
        Uri.parse(checkout.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open the Tamara payment page.');
      }
    } catch (e) {
      await _closeUnpaidOrder(savedOrder.orderId);
      rethrow;
    }

    if (!mounted) return;
    final result = await _waitForTamaraPayment(savedOrder.orderId);

    if (result != 'paid') {
      await _closeUnpaidOrder(savedOrder.orderId);
      _showSnack(
        result == 'failed'
            ? 'Tamara could not approve this payment.'
            : 'Tamara payment was canceled.',
      );
      return;
    }

    await _createPaymentConfirmationNotification(
      user: user,
      orderId: savedOrder.orderId,
      paymentIntentId: checkout.tamaraOrderId,
    );

    _clearPurchasedItems(purchasedItems);

    if (!mounted) return;
    await _showOrderPlacedSuccess();
  }

  /// Marks a Tamara order that was never paid as canceled so it does not
  /// stay in the buyer's history as an active order.
  Future<void> _closeUnpaidOrder(String orderId) async {
    try {
      await db.collection(_ordersCollection).doc(orderId).set({
        'paymentStatus': 'canceled',
        'status': 'canceled',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('UNPAID ORDER CLOSE ERROR: $e');
    }
  }

  Widget _buildPaymentMethodSelector() {
    Widget option(_PaymentMethod method, String title, String subtitle) {
      return RadioListTile<_PaymentMethod>(
        value: method,
        enabled: !_isPlacingOrder,
        title: Text(title),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey),
        color: Colors.white.withAlpha(80),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment Method",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          RadioGroup<_PaymentMethod>(
            groupValue: _paymentMethod,
            onChanged: (value) {
              if (value != null) setState(() => _paymentMethod = value);
            },
            child: Column(
              children: [
                option(_PaymentMethod.card, 'Card', 'Pay in full with Stripe'),
                option(
                  _PaymentMethod.tamara,
                  'Tamara',
                  'Split into installments, no fees',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final deliveryAddress = _deliveryAddressController.text.trim();

    if (_cartItems.isEmpty) {
      _showSnack("No product selected");
      return;
    }

    if (deliveryAddress.isEmpty && _selectedLatLng == null) {
      _showSnack("Please add a delivery address or select a location");
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final purchasedItems = List<Cart>.from(_cartItems);

      if (user == null) {
        _showSnack("You must be logged in");
        return;
      }

      final checkoutError = _validateCheckoutItems(
        purchasedItems,
        currentUserId: user.uid,
      );
      if (checkoutError != null) {
        _showSnack(checkoutError);
        return;
      }

      if (_paymentMethod == _PaymentMethod.tamara) {
        await _placeTamaraOrder(
          user: user,
          deliveryAddress: deliveryAddress,
          purchasedItems: purchasedItems,
        );
        return;
      }

      final paymentIntent = await _createMarketplacePaymentIntent(
        user,
        purchasedItems,
      );

      try {
        await _presentPaymentSheet(paymentIntent.clientSecret);
      } on StripeException catch (e) {
        final stripeMessage = e.error.localizedMessage ?? 'Payment cancelled.';
        _showSnack(stripeMessage);
        return;
      } catch (e) {
        _showSnack('Payment failed: $e');
        return;
      }

      if (!mounted) return;
      final savedOrder = await _saveOrder(
        user: user,
        deliveryAddress: deliveryAddress,
        purchasedItems: purchasedItems,
        paymentIntentId: paymentIntent.paymentIntentId,
      );

      await _createPaymentConfirmationNotification(
        user: user,
        orderId: savedOrder.orderId,
        paymentIntentId: paymentIntent.paymentIntentId,
      );

      try {
        await _markProductsSold(savedOrder.productIds);
      } on FirebaseException catch (e) {
        debugPrint('PRODUCT STATUS UPDATE ERROR (${e.code}): ${e.message}');
      }

      _clearPurchasedItems(purchasedItems);

      if (!mounted) return;
      await _showOrderPlacedSuccess();

      try {
        await _finalizeMarketplaceOrder(
          user: user,
          orderId: savedOrder.orderId,
          paymentIntentId: paymentIntent.paymentIntentId,
          purchasedItems: purchasedItems,
        );
      } catch (e) {
        debugPrint('ORDER FINALIZATION ERROR: $e');
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'ORDER WRITE ERROR (${e.code}) on $_ordersCollection: ${e.message}',
      );
      final message = e.code == 'permission-denied'
          ? 'Order save was blocked by Firestore rules for database "souqplus". '
                'Deploy the orders rule to that named database, then try again.'
          : 'Order save failed: ${e.message ?? e.code}';
      _showSnack(message);
    } catch (e) {
      debugPrint("ERROR: $e");
      _showSnack("Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkoutValidationMessage = _checkoutValidationMessage;

    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (checkoutValidationMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Text(
                checkoutValidationMessage,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Order Summary",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ..._cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.product.title} x${item.numOfItem}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SAR ${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Total",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      'SAR ${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey),
              color: Colors.white.withAlpha(80),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delivery Address",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _deliveryAddressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: "Enter delivery address",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey),
              color: Colors.white.withAlpha(80),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delivery Location",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _defaultCenter,
                        initialZoom: 13,
                        onTap: (tapPosition, point) =>
                            _setPickedLocation(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.example.souqplus',
                        ),
                        if (_selectedLatLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedLatLng == null
                      ? "Tap on map to select location"
                      : "Location selected",
                ),
                const SizedBox(height: 6),
                Text(
                  _isResolvingAddress
                      ? "Resolving..."
                      : (_selectedLocationDetails ?? ""),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLocatingUser ? null : _autoDetectUserLocation,
                    child: Text(
                      _isLocatingUser ? "Loading..." : "Use Current Location",
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodSelector(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -5),
              blurRadius: 10,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isPlacingOrder || checkoutValidationMessage != null
                  ? null
                  : _placeOrder,
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _paymentMethod == _PaymentMethod.tamara
                          ? "Pay with Tamara"
                          : "Place Order",
                    ),
            ),
          ),
        ),
      ),
    );
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

class _TamaraCheckout {
  const _TamaraCheckout({
    required this.checkoutUrl,
    required this.tamaraOrderId,
  });

  final String checkoutUrl;
  final String tamaraOrderId;
}

class _SavedOrderResult {
  const _SavedOrderResult({required this.orderId, required this.productIds});

  final String orderId;
  final List<String> productIds;
}

class _PickupDetails {
  const _PickupDetails({
    required this.addressText,
    this.latitude,
    this.longitude,
  });

  final String addressText;
  final double? latitude;
  final double? longitude;
}
