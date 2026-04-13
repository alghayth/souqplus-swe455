import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/cart.dart';

class CartCard extends StatelessWidget {
  const CartCard({
    super.key,
    required this.cart,
  });

  final Cart cart;

  bool get _usesNetworkImage =>
      cart.product.images.isNotEmpty &&
      (cart.product.images.first.startsWith('http://') ||
          cart.product.images.first.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: AspectRatio(
            aspectRatio: 0.88,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: _usesNetworkImage
                  ? Image.network(
                      cart.product.images[0],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      ),
                    )
                  : Image.asset(
                      cart.product.images[0],
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cart.product.title,
              style: const TextStyle(color: Colors.black, fontSize: 16),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: "SAR ${cart.product.price.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kPrimaryColor,
                ),
                children: [
                  TextSpan(
                    text: " x${cart.numOfItem}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
