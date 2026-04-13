import 'package:flutter/foundation.dart';

import 'package:souqplus/models/cart.dart';
import 'package:souqplus/models/product.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  final ValueNotifier<List<Cart>> itemsListenable =
      ValueNotifier<List<Cart>>(<Cart>[]);

  List<Cart> get items => List<Cart>.unmodifiable(itemsListenable.value);

  int get totalItems =>
      items.fold<int>(0, (sum, item) => sum + item.numOfItem);

  double get totalPrice =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  String? mixedSellerMessage([List<Cart>? sourceItems]) {
    final itemsToCheck = sourceItems ?? items;
    final sellerIds = itemsToCheck
        .map(
          (item) =>
              item.product.ownerUid?.trim() ??
              item.product.sellerStripeAccountId?.trim() ??
              '',
        )
        .where((sellerId) => sellerId.isNotEmpty)
        .toSet();

    if (sellerIds.length > 1) {
      return 'You have different sellers in the cart.';
    }

    return null;
  }

  void addProduct(Product product) {
    final currentItems = List<Cart>.from(itemsListenable.value);
    final existingIndex = currentItems.indexWhere(
      (item) => _matchesProduct(item.product, product),
    );

    if (existingIndex >= 0) {
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(
        numOfItem: existing.numOfItem + 1,
      );
    } else {
      currentItems.add(Cart(product: product, numOfItem: 1));
    }

    itemsListenable.value = currentItems;
  }

  void removeProduct(Product product) {
    final currentItems = List<Cart>.from(itemsListenable.value)
      ..removeWhere((item) => _matchesProduct(item.product, product));
    itemsListenable.value = currentItems;
  }

  void clear() {
    itemsListenable.value = <Cart>[];
  }

  bool _matchesProduct(Product left, Product right) {
    final leftImage = left.images.isNotEmpty ? left.images.first : null;
    final rightImage = right.images.isNotEmpty ? right.images.first : null;

    return left.id == right.id &&
        left.title == right.title &&
        left.price == right.price &&
        leftImage == rightImage;
  }
}
