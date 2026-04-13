import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/screens/cart/checkout_screen.dart';

import '../../models/product.dart';
import 'components/color_dots.dart';
import 'components/product_description.dart';
import 'components/product_images.dart';
import 'components/top_rounded_container.dart';

class DetailsScreen extends StatelessWidget {
  static String routeName = "/details";

  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;

    if (args is FirestorePostDetailsArguments) {
      return _FirestorePostDetailsScreen(post: args);
    }

    final product = (args as ProductDetailsArguments).product;
    final isSold = product.isSold;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              elevation: 0,
              backgroundColor: Colors.white,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text(
                      "4.7",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SvgPicture.asset("assets/icons/Star Icon.svg"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          ProductImages(product: product),
          TopRoundedContainer(
            color: Colors.white,
            child: Column(
              children: [
                ProductDescription(product: product, pressOnSeeMore: () {}),
                TopRoundedContainer(
                  color: const Color(0xFFF6F7F9),
                  child: Column(
                    children: [
                      ColorDots(product: product),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: TopRoundedContainer(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ElevatedButton(
              onPressed: isSold
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        CheckoutScreen.routeName,
                        arguments: <Cart>[
                          Cart(product: product, numOfItem: 1),
                        ],
                      );
                    },
              child: Text(isSold ? "Sold" : "Buy Now"),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductDetailsArguments {
  final Product product;

  ProductDetailsArguments({required this.product});
}

class FirestorePostDetailsArguments {
  final String postId;
  final Map<String, dynamic> data;

  FirestorePostDetailsArguments({required this.postId, required this.data});
}

class _FirestorePostDetailsScreen extends StatelessWidget {
  const _FirestorePostDetailsScreen({required this.post});

  final FirestorePostDetailsArguments post;

  @override
  Widget build(BuildContext context) {
    final title = (post.data['title'] as String?)?.trim();
    final description = (post.data['description'] as String?)?.trim();
    final imageUrl = (post.data['imageUrl'] as String?)?.trim();
    final category = (post.data['category'] as String?)?.trim();
    final status = (post.data['status'] as String?)?.trim().isNotEmpty == true
        ? (post.data['status'] as String).trim()
        : 'Active';
    final isSold = status.toLowerCase() == 'sold';
    final price = _readDouble(post.data['price']);
    final createdAt = _formatTimestamp(post.data['createdAt'] as Object?);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text('Product Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _FirestorePostPlaceholder(),
                    )
                  : const _FirestorePostPlaceholder(),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title == null || title.isEmpty ? 'Untitled product' : title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SAR ${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (isSold) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE4E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Sold',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _DetailRow(label: 'Category', value: category),
                _DetailRow(label: 'Status', value: status),
                _DetailRow(label: 'Posted', value: createdAt),
                _DetailRow(
                  label: 'Description',
                  value: description,
                  multiline: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton(
            onPressed: isSold
                ? null
                : () {
                    Navigator.pushNamed(
                      context,
                      CheckoutScreen.routeName,
                      arguments: <Cart>[
                        Cart(
                          product: Product.fromMarketplacePost(
                            postId: post.postId,
                            data: post.data,
                          ),
                          numOfItem: 1,
                        ),
                      ],
                    );
                  },
            child: Text(isSold ? 'Sold' : 'Buy Now'),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Object? value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate();
    final month = _monthName(date.month);
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${date.year} $hour:$minute $suffix';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String? value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        value == null || value!.isEmpty ? 'Not provided' : value!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _FirestorePostPlaceholder extends StatelessWidget {
  const _FirestorePostPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F3F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Colors.black38,
      ),
    );
  }
}
