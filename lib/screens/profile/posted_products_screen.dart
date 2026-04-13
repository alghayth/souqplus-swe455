import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/category_service.dart';
import 'package:souqplus/services/marketplace_cleanup_service.dart';

class PostedProductsScreen extends StatefulWidget {
  const PostedProductsScreen({super.key});

  static String routeName = "/posted_products";

  @override
  State<PostedProductsScreen> createState() => _PostedProductsScreenState();
}

class _PostedProductsScreenState extends State<PostedProductsScreen> {
  static const Color _dangerRed = Color(0xFFB3261E);
  final CollectionReference<Map<String, dynamic>> _productsRef =
      db.collection('products');
  final ImagePicker _picker = ImagePicker();
  List<String> _categories = [...CategoryService.defaultCategories];
  StreamSubscription<List<String>>? _categorySubscription;

  @override
  void initState() {
    super.initState();
    _categorySubscription = CategoryService.categoriesStream().listen((categories) {
      if (!mounted) return;
      setState(() {
        _categories = categories.isEmpty
            ? [...CategoryService.defaultCategories]
            : categories;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MarketplaceCleanupService.purgeInvalidProducts();
    });
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteProduct(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Color.fromARGB(255, 14, 14, 77),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Color.fromARGB(221, 54, 133, 224),
          fontSize: 14,
        ),
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: _dangerRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _productsRef.doc(docId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Product deleted")));
  }

  void _editProduct(String docId, Map<String, dynamic> data) {
    final titleController =
        TextEditingController(text: (data['title'] as String?) ?? '');
    final descController =
        TextEditingController(text: (data['description'] as String?) ?? '');
    final priceController = TextEditingController(
      text: ((data['price'] as num?)?.toDouble() ?? 0).toString(),
    );
    String category = (data['category'] as String?) ?? 'Books';
    File? newImage;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              final picked = await _picker.pickImage(source: source);
              if (picked == null) return;
              setModalState(() {
                newImage = File(picked.path);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey[200],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: newImage != null
                                  ? Image.file(newImage!, fit: BoxFit.cover)
                                  : ((data['imageUrl'] as String?) ?? '')
                                          .isNotEmpty
                                      ? Image.network(
                                          data['imageUrl'] as String,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.image,
                                              size: 40,
                                            );
                                          },
                                        )
                                      : const Icon(Icons.image, size: 40),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (_) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.photo),
                                        title: const Text("Gallery"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera),
                                        title: const Text("Camera"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: "Title",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return "Required";
                          if (text.length > 20) return "Max 20 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _categories.contains(category)
                            ? category
                            : _categories.first,
                        decoration: const InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLength: 100,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          return text.length < 10 || text.length > 100
                              ? "Description must be 10 to 100 characters"
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Price in Saudi Riyal",
                          helperText: "Enter the amount in Saudi riyal",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final p = double.tryParse((value ?? '').trim());
                          return (p == null || p <= 0)
                              ? "Invalid price (must be greater than 0)"
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.white,
                            foregroundColor:
                                const Color.fromARGB(255, 11, 48, 79),
                            elevation: 0,
                            side: const BorderSide(
                              color: Color.fromARGB(255, 14, 51, 80),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor:
                                const Color.fromARGB(255, 12, 43, 68),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            String imageUrl =
                                (data['imageUrl'] as String?) ?? '';
                            if (newImage != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('product_images')
                                  .child(user.uid)
                                  .child(
                                    '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  );

                              final snapshot = await ref.putFile(newImage!);
                              imageUrl = await snapshot.ref.getDownloadURL();
                            }

                            await _productsRef.doc(docId).update({
                              'title': titleController.text.trim(),
                              'description': descController.text.trim(),
                              'price':
                                  double.parse(priceController.text.trim()),
                              'category': category,
                              'imageUrl': imageUrl,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Product updated successfully"),
                              ),
                            );
                          },
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const PageHeaderTitle('Posted Product')),
      floatingActionButton: const AppNavFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
      body: user == null
          ? const Center(child: Text("Please login first"))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productsRef.where('ownerUid', isEqualTo: user.uid).snapshots(),
              builder: (context, productSnapshot) {
                if (productSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load products: ${productSnapshot.error}'),
                    ),
                  );
                }

                if (!productSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = productSnapshot.data!.docs;
                final activeCount = docs.where((doc) {
                  final status = _effectiveStatus(doc.data());
                  return status.toLowerCase() == 'active';
                }).length;
                final soldCount = docs.where((doc) {
                  final status = _effectiveStatus(doc.data());
                  return status.toLowerCase() == 'sold';
                }).length;

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('You have not posted any products yet.'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: docs.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Posted Product',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage your product status and keep your listings up to date.',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _SummaryChip(label: '${docs.length} Total'),
                                _SummaryChip(label: '$activeCount Active'),
                                _SummaryChip(label: '$soldCount Sold'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    final doc = docs[index - 1];
                    final data = doc.data();
                    final title =
                        (data['title'] as String?)?.trim() ?? 'Untitled';
                    final category =
                        (data['category'] as String?)?.trim() ?? 'Other';
                    final description = (data['description'] as String?)?.trim() ??
                        'No description';
                    final imageUrl = (data['imageUrl'] as String?)?.trim();
                    final status = _effectiveStatus(data);
                    final price = (data['price'] as num?)?.toDouble() ?? 0;
                    final createdAt = data['createdAt'] as Timestamp?;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: kPrimaryColor.withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return _buildImagePlaceholder();
                                          },
                                        )
                                      : _buildImagePlaceholder(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'SAR ${price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 86, 86, 86),
                                      ),
                                    ),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(createdAt),
                                        style: const TextStyle(
                                          color: kTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status.toLowerCase() == 'active'
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: status.toLowerCase() == 'active'
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 96,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              _editProduct(doc.id, data),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteProduct(doc.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kTextColor),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 32),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _effectiveStatus(Map<String, dynamic> data) {
    final statusValue = (data['status'] as String?)?.trim();
    return statusValue == null || statusValue.isEmpty ? 'Active' : statusValue;
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
