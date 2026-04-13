import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:souqplus/screens/favorite/favorite_screen.dart';
import 'package:souqplus/screens/cart/checkout_screen.dart';

import '../../models/cart.dart';
import '../../services/cart_service.dart';
import 'components/cart_card.dart';
import 'components/check_out_card.dart';

class CartScreen extends StatefulWidget {
  static String routeName = "/cart";

  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService.instance;

  void _goToCheckout() {
    Navigator.pushNamed(context, CheckoutScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<List<Cart>>(
          valueListenable: _cartService.itemsListenable,
          builder: (context, carts, _) => Column(
            children: [
              const Text(
                "Your Cart",
                style: TextStyle(color: Colors.black),
              ),
              Text(
                "${_cartService.totalItems} items",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Favorites',
            onPressed: () =>
                Navigator.pushNamed(context, FavoriteScreen.routeName),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Cart>>(
        valueListenable: _cartService.itemsListenable,
        builder: (context, carts, _) {
          if (carts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Your cart is empty. Add products from the homepage to see them here.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              itemCount: carts.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Dismissible(
                  key: Key(
                    '${carts[index].product.id}_${carts[index].product.price}',
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _cartService.removeProduct(carts[index].product);
                  },
                  background: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE6E6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        SvgPicture.asset("assets/icons/Trash.svg"),
                      ],
                    ),
                  ),
                  child: CartCard(cart: carts[index]),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: CheckoutCard(
        onCheckout: _goToCheckout,
      ),
    );
  }
}
