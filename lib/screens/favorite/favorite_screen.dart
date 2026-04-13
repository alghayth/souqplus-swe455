import 'package:flutter/material.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/components/product_card.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/models/product.dart';
import 'package:souqplus/services/favorites_service.dart';

import '../details/details_screen.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});
  static String routeName = '/favorites';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(title: const PageHeaderTitle('My Favorites')),
        floatingActionButton: const AppNavFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: const AppBottomNav(selectedIndex: -1),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FavoritesService.currentUser == null
                    ? const _FavoriteInfoState(
                        icon: Icons.person_outline,
                        title: 'Sign in to use favorites',
                        message:
                            'Save products you like and come back to them later from this page.',
                      )
                    : StreamBuilder<List<Product>>(
                        stream: FavoritesService.favoriteProducts(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _FavoriteInfoState(
                              icon: Icons.error_outline,
                              title: 'Could not load favorites',
                              message:
                                  'Please try again in a moment. ${snapshot.error}',
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final favorites = snapshot.data ?? const <Product>[];
                          if (favorites.isEmpty) {
                            return const _FavoriteInfoState(
                              icon: Icons.favorite_border,
                              title: 'No favorites yet',
                              message:
                                  'Tap the heart on any product card to save it here.',
                            );
                          }

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withAlpha(230),
                                        kPrimaryLightColor.withAlpha(185),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: kPrimaryColor.withAlpha(80),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bookmark_outline,
                                        color: kSecondaryColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${favorites.length} saved ${favorites.length == 1 ? 'item' : 'items'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: kSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    90,
                                  ),
                                  child: GridView.builder(
                                    itemCount: favorites.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 220,
                                          childAspectRatio: 0.72,
                                          mainAxisSpacing: 18,
                                          crossAxisSpacing: 14,
                                        ),
                                    itemBuilder: (context, index) =>
                                        ProductCard(
                                          product: favorites[index],
                                          onPress: () => Navigator.pushNamed(
                                            context,
                                            DetailsScreen.routeName,
                                            arguments: ProductDetailsArguments(
                                              product: favorites[index],
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteInfoState extends StatelessWidget {
  const _FavoriteInfoState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withAlpha(240),
                kPrimaryLightColor.withAlpha(170),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kPrimaryColor.withAlpha(70)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: kSecondaryColor.withAlpha(24),
                child: Icon(icon, color: kSecondaryColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextColor, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
