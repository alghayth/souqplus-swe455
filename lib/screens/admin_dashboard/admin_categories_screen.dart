import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/category_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  static const String routeName = '/admin_categories';

  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _adding = false;
  bool _deleting = false;

  Future<void> _addCategory() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name.')),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      await CategoryService.addCategory(value);
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add category: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteCategory(String category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    setState(() => _deleting = true);
    try {
      await CategoryService.deleteCategory(category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$category" deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete category: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Categories')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _categoryCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Categories',
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add categories, delete admin-created ones, or hide built-in categories from the active app list.',
                  style: TextStyle(color: Color(0xFF6B7C93)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  onSubmitted: (_) => _adding ? null : _addCategory(),
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    hintText: 'Add a new category',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _adding ? null : _addCategory,
                    child: _adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Category'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('categories').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load categories: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? const [];
              final hiddenDefaults = docs
                  .where(
                    (doc) =>
                        doc.data()['isDefault'] == true &&
                        doc.data()['deleted'] == true,
                  )
                  .map(
                    (doc) =>
                        (doc.data()['normalizedName'] as String? ?? '').trim(),
                  )
                  .where((name) => name.isNotEmpty)
                  .toSet();
              final visibleDefaultCategories = CategoryService.defaultCategories
                  .where(
                    (category) => !hiddenDefaults.contains(category.toLowerCase()),
                  )
                  .toList();
              final customDocs = docs
                  .where(
                    (doc) =>
                        doc.data()['isDefault'] != true &&
                        doc.data()['deleted'] != true,
                  )
                  .toList();

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _categoryCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Built-in Categories',
                          style: TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visibleDefaultCategories.isEmpty)
                          const Text(
                            'No built-in categories are currently active.',
                            style: TextStyle(color: Color(0xFF6B7C93)),
                          )
                        else
                          ...visibleDefaultCategories.map((category) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5FC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    color: kSecondaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: kTextColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _deleting
                                        ? null
                                        : () => _deleteCategory(category),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _categoryCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin-added Categories',
                          style: TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (customDocs.isEmpty)
                          const Text(
                            'No admin-added categories yet.',
                            style: TextStyle(color: Color(0xFF6B7C93)),
                          )
                        else
                          ...customDocs.map((doc) {
                            final category =
                                (doc.data()['name'] as String? ?? '').trim();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5FC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: kTextColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _deleting
                                        ? null
                                        : () => _deleteCategory(category),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

BoxDecoration _categoryCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFD8E3EE)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x140E0820),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
  );
}
