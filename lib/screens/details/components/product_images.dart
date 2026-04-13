import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/product.dart';

class ProductImages extends StatefulWidget {
  const ProductImages({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  State<ProductImages> createState() => _ProductImagesState();
}

class _ProductImagesState extends State<ProductImages> {
  int selectedImage = 0;

  bool _isNetworkImage(String image) {
    return image.startsWith('http://') || image.startsWith('https://');
  }

  Widget _buildImage(String image, {BoxFit fit = BoxFit.contain}) {
    if (_isNetworkImage(image)) {
      return Image.network(
        image,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }
    return Image.asset(image, fit: fit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 238,
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildImage(widget.product.images[selectedImage]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...List.generate(
              widget.product.images.length,
              (index) => SmallProductImage(
                isSelected: index == selectedImage,
                press: () {
                  setState(() {
                    selectedImage = index;
                  });
                },
                image: widget.product.images[index],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SmallProductImage extends StatelessWidget {
  const SmallProductImage({
    super.key,
    required this.isSelected,
    required this.press,
    required this.image,
  });

  final bool isSelected;
  final VoidCallback press;
  final String image;

  bool _isNetworkImage() {
    return image.startsWith('http://') || image.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: AnimatedContainer(
        duration: defaultDuration,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(8),
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: kPrimaryColor.withValues(alpha: isSelected ? 1 : 0),
          ),
        ),
        child: _isNetworkImage()
            ? Image.network(
                image,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              )
            : Image.asset(image),
      ),
    );
  }
}
