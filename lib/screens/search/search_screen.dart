import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/product_card.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/models/product.dart';
import 'package:souqplus/screens/details/details_screen.dart';
import 'package:souqplus/screens/favorite/favorite_screen.dart';
import 'package:souqplus/screens/home/components/search_field.dart';
import 'package:souqplus/screens/home/components/search_state.dart';
import 'package:souqplus/services/marketplace_cleanup_service.dart';
import 'package:souqplus/services/category_service.dart';

const Color _kNavy = Color.fromARGB(255, 27, 58, 104);
const Color _kBackground = Color.fromARGB(255, 253, 246, 210);
const Color _kChipBg = Color.fromARGB(255, 240, 230, 180);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static String routeName = '/search';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CollectionReference<Map<String, dynamic>> _productsRef = db.collection(
    'products',
  );
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  static const List<Map<String, dynamic>> _kPriceRanges = [
    {'label': 'Any price', 'min': 0, 'max': double.infinity},
    {'label': 'Under SAR 25', 'min': 0, 'max': 25},
    {'label': 'SAR 25 - SAR 50', 'min': 25, 'max': 50},
    {'label': 'SAR 50 - SAR 100', 'min': 50, 'max': 100},
    {'label': 'SAR 100 - SAR 250', 'min': 100, 'max': 250},
    {'label': 'SAR 250 - SAR 500', 'min': 250, 'max': 500},
    {'label': 'SAR 500 - SAR 1000', 'min': 500, 'max': 1000},
    {'label': 'Over SAR 1000', 'min': 1000, 'max': double.infinity},
  ];
  Map<String, dynamic> _selectedPriceRange = _kPriceRanges.first;

  List<String> _categories = ['All', ...CategoryService.defaultCategories];
  StreamSubscription<List<String>>? _categorySubscription;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _categorySubscription = CategoryService.categoriesStream(
      includeAll: true,
    ).listen((categories) {
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MarketplaceCleanupService.purgeInvalidProducts();
    });
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kNavy.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Price range',
                    style: TextStyle(
                      color: _kNavy,
                      fontFamily: 'Muli',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedPriceRange,
                    dropdownColor: _kBackground,
                    style: const TextStyle(
                      color: _kNavy,
                      fontFamily: 'Muli',
                      fontSize: 14,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, color: _kNavy),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: _kNavy),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: _kNavy, width: 2),
                      ),
                    ),
                    items: _kPriceRanges.map((range) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: range,
                        child: Text(range['label'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _selectedPriceRange = value);
                        setState(() => _selectedPriceRange = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Category',
                    style: TextStyle(
                      color: _kNavy,
                      fontFamily: 'Muli',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(
                          category,
                          style: TextStyle(
                            fontFamily: 'Muli',
                            color: isSelected ? Colors.white : _kNavy,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: _kNavy,
                        backgroundColor: _kChipBg,
                        side: const BorderSide(color: _kNavy),
                        onSelected: (_) {
                          setSheetState(() => _selectedCategory = category);
                          setState(() => _selectedCategory = category);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kNavy,
                            side: const BorderSide(color: _kNavy),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            setSheetState(() {
                              _selectedPriceRange = _kPriceRanges.first;
                              _selectedCategory = 'All';
                            });
                            setState(() {
                              _selectedPriceRange = _kPriceRanges.first;
                              _selectedCategory = 'All';
                            });
                          },
                          child: const Text(
                            'Reset all',
                            style: TextStyle(fontFamily: 'Muli'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontFamily: 'Muli'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool anyFilterActive =
        _searchKeyword.isNotEmpty ||
        _selectedPriceRange != _kPriceRanges.first ||
        _selectedCategory != 'All';

    return SearchState(
      controller: _searchController,
      onChanged: (value) =>
          setState(() => _searchKeyword = value.trim().toLowerCase()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kNavy,
          title: const SearchField(),
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Favorites',
              onPressed: () =>
                  Navigator.pushNamed(context, FavoriteScreen.routeName),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Filter',
                  icon: const Icon(Icons.tune),
                  onPressed: _showFilterSheet,
                ),
                if (anyFilterActive)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: Colors.amber,
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _productsRef.snapshots(),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Firestore error: ${productSnapshot.error}'),
              );
            }
            if (productSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...(productSnapshot.data?.docs ?? [])];
            docs.sort((a, b) {
              final aTs = _effectiveTimestamp(a.data());
              final bTs = _effectiveTimestamp(b.data());
              return bTs.compareTo(aTs);
            });

            final filteredDocs = docs.where((doc) {
              final rawStatus =
                  ((doc.data()['status'] as String?) ?? '').trim().toLowerCase();
              final title =
                  ((doc.data()['title'] as String?) ?? '').toLowerCase();
              final category =
                  ((doc.data()['category'] as String?) ?? '').toLowerCase();
              final price = (doc.data()['price'] as num?)?.toDouble() ?? 0.0;

              final matchesText =
                  _searchKeyword.isEmpty ||
                  title.contains(_searchKeyword) ||
                  category.contains(_searchKeyword);
              final inPrice =
                  price >= (_selectedPriceRange['min'] as num).toDouble() &&
                  price <= (_selectedPriceRange['max'] as num).toDouble();
              final inCategory =
                  _selectedCategory == 'All' ||
                  category == _selectedCategory.toLowerCase();
              final isAvailable = rawStatus.isEmpty || rawStatus == 'active';

              return isAvailable && matchesText && inPrice && inCategory;
            }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    anyFilterActive
                        ? 'No products match your search or filters.'
                        : 'No products yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: filteredDocs.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.72,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data();
                final product = Product.fromMarketplacePost(
                  postId: doc.id,
                  data: data,
                );

                return ProductCard(
                  product: product,
                  onPress: () => Navigator.pushNamed(
                    context,
                    DetailsScreen.routeName,
                    arguments: FirestorePostDetailsArguments(
                      postId: doc.id,
                      data: data,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  DateTime _effectiveTimestamp(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    final clientCreatedAt = data['clientCreatedAt'];
    if (clientCreatedAt is Timestamp) {
      return clientCreatedAt.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
