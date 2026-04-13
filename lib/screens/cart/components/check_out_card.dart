import 'package:flutter/material.dart';

import '../../../models/cart.dart';
import '../../../services/cart_service.dart';

class CheckoutCard extends StatelessWidget {
  final VoidCallback onCheckout;

  const CheckoutCard({
    super.key,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Cart>>(
      valueListenable: CartService.instance.itemsListenable,
      builder: (context, carts, _) {
        final total = CartService.instance.totalPrice;
        final mixedSellerMessage = CartService.instance.mixedSellerMessage(carts);

        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -15),
                blurRadius: 20,
                color: const Color(0xFFDADADA).withValues(alpha: 0.15),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mixedSellerMessage != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      mixedSellerMessage,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: "Total:\n",
                          children: [
                            TextSpan(
                              text: 'SAR ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: carts.isEmpty || mixedSellerMessage != null
                            ? null
                            : onCheckout,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Check Out"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
