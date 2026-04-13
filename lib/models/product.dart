import 'package:flutter/material.dart';

class Product {
  final int id;
  final String title, description;
  final List<String> images;
  final String? firestoreId;
  final String? ownerUid;
  final String? sellerStripeAccountId;
  final String status;
  final List<Color> colors;
  final double rating, price;
  final bool isFavourite, isPopular;

  Product({
    required this.id,
    required this.images,
    this.firestoreId,
    this.ownerUid,
    this.sellerStripeAccountId,
    this.status = 'Active',
    required this.colors,
    this.rating = 0.0,
    this.isFavourite = false,
    this.isPopular = false,
    required this.title,
    required this.price,
    required this.description,
  });

  String get favoriteKey {
    if (firestoreId != null && firestoreId!.trim().isNotEmpty) {
      return firestoreId!.trim();
    }
    final raw = '${title.trim()}|${price.toStringAsFixed(2)}|${images.first}';
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  bool get isSold => status.toLowerCase() == 'sold';

  Map<String, dynamic> toFavoriteMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'images': images,
      'firestoreId': firestoreId,
      'ownerUid': ownerUid,
      'sellerStripeAccountId': sellerStripeAccountId,
      'status': status,
      'price': price,
      'rating': rating,
      'isFavourite': true,
      'isPopular': isPopular,
      'colors': colors.map((color) => color.toARGB32()).toList(),
    };
  }

  factory Product.fromFavoriteMap(Map<String, dynamic> map) {
    final imageList = (map['images'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    final colorValues = (map['colors'] as List<dynamic>? ?? [])
        .map((item) => item as int)
        .toList();

    return Product(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: (map['title'] as String?) ?? 'Untitled',
      description: (map['description'] as String?) ?? '',
      images: imageList.isEmpty ? [''] : imageList,
      firestoreId: (map['firestoreId'] as String?)?.trim(),
      ownerUid: (map['ownerUid'] as String?)?.trim(),
      sellerStripeAccountId: (map['sellerStripeAccountId'] as String?)?.trim(),
      status: (map['status'] as String?)?.trim().isNotEmpty == true
          ? map['status'] as String
          : 'Active',
      colors: colorValues.isEmpty
          ? [Colors.white]
          : colorValues.map((value) => Color(value)).toList(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      isFavourite: true,
      isPopular: (map['isPopular'] as bool?) ?? false,
    );
  }

  factory Product.fromMarketplacePost({
    required String postId,
    required Map<String, dynamic> data,
  }) {
    final imageUrl = (data['imageUrl'] as String?)?.trim();
    final title = (data['title'] as String?)?.trim();
    final description = (data['description'] as String?)?.trim();

    return Product(
      id: postId.hashCode,
      firestoreId: postId,
      ownerUid: (data['ownerUid'] as String?)?.trim(),
      sellerStripeAccountId:
          (data['sellerStripeAccountId'] as String?)?.trim(),
      status: (data['status'] as String?)?.trim().isNotEmpty == true
          ? data['status'] as String
          : 'Active',
      title: title == null || title.isEmpty ? 'Untitled product' : title,
      description: description ?? '',
      images: [if (imageUrl != null && imageUrl.isNotEmpty) imageUrl else ''],
      colors: [Colors.white],
      price: _readDouble(data['price']),
      rating: 0,
    );
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }
}

// Our demo Products

List<Product> demoProducts = [
  Product(
    id: 1,
    images: [
      "assets/images/ps4_console_white_1.png",
      "assets/images/ps4_console_white_2.png",
      "assets/images/ps4_console_white_3.png",
      "assets/images/ps4_console_white_4.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Wireless Controller for PS4™",
    price: 64.99,
    description: description,
    rating: 4.8,
    isFavourite: true,
    isPopular: true,
  ),
  Product(
    id: 2,
    images: [
      "assets/images/Image Popular Product 2.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Nike Sport White - Man Pant",
    price: 50.5,
    description: description,
    rating: 4.1,
    isPopular: true,
  ),
  Product(
    id: 3,
    images: [
      "assets/images/glap.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Gloves XC Omega - Polygon",
    price: 36.55,
    description: description,
    rating: 4.1,
    isFavourite: true,
    isPopular: true,
  ),
  Product(
    id: 4,
    images: [
      "assets/images/wireless headset.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Logitech Head",
    price: 20.20,
    description: description,
    rating: 4.1,
    isFavourite: true,
  ),
  Product(
    id: 1,
    images: [
      "assets/images/ps4_console_white_1.png",
      "assets/images/ps4_console_white_2.png",
      "assets/images/ps4_console_white_3.png",
      "assets/images/ps4_console_white_4.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Wireless Controller for PS4™",
    price: 64.99,
    description: description,
    rating: 4.8,
    isFavourite: true,
    isPopular: true,
  ),
  Product(
    id: 2,
    images: [
      "assets/images/Image Popular Product 2.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Nike Sport White - Man Pant",
    price: 50.5,
    description: description,
    rating: 4.1,
    isPopular: true,
  ),
  Product(
    id: 3,
    images: [
      "assets/images/glap.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Gloves XC Omega - Polygon",
    price: 36.55,
    description: description,
    rating: 4.1,
    isFavourite: true,
    isPopular: true,
  ),
  Product(
    id: 4,
    images: [
      "assets/images/wireless headset.png",
    ],
    colors: [
      const Color(0xFFF6625E),
      const Color(0xFF836DB8),
      const Color(0xFFDECB9C),
      Colors.white,
    ],
    title: "Logitech Head",
    price: 20.20,
    description: description,
    rating: 4.1,
    isFavourite: true,
  ),
];

const String description =
    "Wireless Controller for PS4™ gives you what you want in your gaming from over precision control your games to sharing …";
