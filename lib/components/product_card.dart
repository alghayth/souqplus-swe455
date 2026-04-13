import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants.dart';
import '../models/product.dart';
import '../services/favorites_service.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    this.width = 140,
    this.aspectRetio = 1.02,
    required this.product,
    required this.onPress,
  });

  final double width, aspectRetio;
  final Product product;
  final VoidCallback onPress;

  bool get _hasImage => product.images.isNotEmpty && product.images.first.isNotEmpty;

  bool get _usesNetworkImage =>
      _hasImage &&
      (product.images.first.startsWith('http://') ||
          product.images.first.startsWith('https://'));

  void _showFavoriteMessage(BuildContext context, bool added) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Product saved to favorites.' : 'Product removed from favorites.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteButton = StreamBuilder<bool>(
      stream: FavoritesService.isFavorite(product),
      initialData: product.isFavourite,
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            if (FavoritesService.currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log in to save favorites.'),
                ),
              );
              return;
            }

            final wasFavorite = isFavorite;
            await FavoritesService.toggleFavorite(product);
            if (!context.mounted) return;
            _showFavoriteMessage(context, !wasFavorite);
          },
          child: Container(
            padding: const EdgeInsets.all(7),
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: isFavorite ? const Color(0xFFFFE5E5) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFavorite
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFD1D5DB),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.asset(
              "assets/icons/Heart Icon_2.svg",
              colorFilter: ColorFilter.mode(
                isFavorite ? const Color(0xFFFF4848) : const Color(0xFF6B7280),
                BlendMode.srcIn,
              ),
            ),
          ),
        );
      },
    );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: GestureDetector(
          onTap: onPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.02,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: !_hasImage
                          ? const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            )
                          : _usesNetworkImage
                              ? Image.network(
                                  product.images[0],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey,
                                  ),
                                )
                              : Image.asset(
                                  product.images[0],
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: favoriteButton,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "SAR ${product.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
