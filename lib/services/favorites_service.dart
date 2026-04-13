import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../models/product.dart';

class FavoritesService {
  FavoritesService._();

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) {
    return db.collection('users').doc(uid).collection('favorites');
  }

  static DocumentReference<Map<String, dynamic>> favoriteDoc(Product product) {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to manage favorites.');
    }
    return _favoritesRef(user.uid).doc(product.favoriteKey);
  }

  static Stream<bool> isFavorite(Product product) {
    final user = currentUser;
    if (user == null) return Stream<bool>.value(false);
    return _favoritesRef(user.uid)
        .doc(product.favoriteKey)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  static Stream<List<Product>> favoriteProducts() {
    final user = currentUser;
    if (user == null) return Stream<List<Product>>.value(const []);
    return _favoritesRef(user.uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromFavoriteMap(doc.data()))
              .toList(),
        );
  }

  static Future<void> toggleFavorite(Product product) async {
    final doc = favoriteDoc(product);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      await doc.delete();
      return;
    }
    await doc.set({
      ...product.toFavoriteMap(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }
}
