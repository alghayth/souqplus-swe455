import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:souqplus/main.dart';

class CategoryService {
  CategoryService._();

  static const List<String> defaultCategories = [
    'Books',
    'Furniture',
    'Clothes',
    'Electronics',
    'Other',
  ];

  static CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      db.collection('categories');

  static bool isDefaultCategory(String name) {
    final normalized = name.trim().toLowerCase();
    return defaultCategories.any(
      (category) => category.toLowerCase() == normalized,
    );
  }

  static Stream<List<String>> categoriesStream({bool includeAll = false}) {
    return _categoriesRef.orderBy('name').snapshots().map((snapshot) {
      final disabledDefaults = snapshot.docs
          .where(
            (doc) =>
                doc.data()['isDefault'] == true && doc.data()['deleted'] == true,
          )
          .map((doc) => (doc.data()['normalizedName'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toSet();

      final customCategories = snapshot.docs
          .where(
            (doc) =>
                doc.data()['isDefault'] != true && doc.data()['deleted'] != true,
          )
          .map((doc) => (doc.data()['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList();

      final values = <String>[
        ...defaultCategories.where(
          (category) => !disabledDefaults.contains(category.toLowerCase()),
        ),
        ...customCategories.where(
          (name) => !defaultCategories.any(
            (defaultName) => defaultName.toLowerCase() == name.toLowerCase(),
          ),
        ),
      ];
      return includeAll ? ['All', ...values] : values;
    });
  }

  static Future<void> addCategory(String name) async {
    final trimmedName = name.trim();
    final normalizedName = trimmedName.toLowerCase();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    final data = <String, dynamic>{
      'name': trimmedName,
      'normalizedName': normalizedName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _categoriesRef.doc(normalizedName).set(data, SetOptions(merge: true));
  }

  static Future<void> deleteCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    final normalizedName = trimmedName.toLowerCase();
    if (isDefaultCategory(trimmedName)) {
      await _categoriesRef.doc(normalizedName).set({
        'name': trimmedName,
        'normalizedName': normalizedName,
        'isDefault': true,
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await _categoriesRef.doc(normalizedName).delete();
  }
}
