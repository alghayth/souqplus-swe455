import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants.dart';
import '../../../models/product.dart';
import '../../../services/favorites_service.dart';
import '../../favorite/favorite_screen.dart';

class ProductDescription extends StatelessWidget {
  const ProductDescription({
    super.key,
    required this.product,
    this.pressOnSeeMore,
  });

  final Product product;
  final GestureTapCallback? pressOnSeeMore;

  void _showFavoriteMessage(BuildContext context, bool added) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? 'Product saved to favorites.'
                : 'Product removed from favorites.',
          ),
          action: added
              ? SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.pushNamed(context, FavoriteScreen.routeName);
                  },
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            product.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: StreamBuilder<bool>(
            stream: FavoritesService.isFavorite(product),
            initialData: product.isFavourite,
            builder: (context, snapshot) {
              final isFavorite = snapshot.data ?? false;
              return InkWell(
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
                  padding: const EdgeInsets.all(16),
                  width: 48,
                  decoration: BoxDecoration(
                    color: isFavorite
                        ? const Color(0xFFFFE6E6)
                        : const Color(0xFFF5F6F9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: SvgPicture.asset(
                    "assets/icons/Heart Icon_2.svg",
                    colorFilter: ColorFilter.mode(
                      isFavorite
                          ? const Color(0xFFFF4848)
                          : const Color(0xFFDBDEE4),
                      BlendMode.srcIn,
                    ),
                    height: 16,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 64),
          child: Text(
            product.description,
            maxLines: 3,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GestureDetector(
            onTap: pressOnSeeMore,
            child: const Row(
              children: [
                Text(
                  "See More Detail",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kPrimaryColor,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: kPrimaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
