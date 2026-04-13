import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:souqplus/main.dart';

class MarketplaceCleanupService {
  MarketplaceCleanupService._();

  static Future<void>? _inFlight;

  static Future<void> purgeInvalidProducts() {
    return _inFlight ??= _purgeInvalidProducts().whenComplete(() {
      _inFlight = null;
    });
  }

  static Future<void> _purgeInvalidProducts() async {
    final productsSnapshot = await db.collection('products').get();
    if (productsSnapshot.docs.isEmpty) {
      return;
    }

    final ownerUids = productsSnapshot.docs
        .map((doc) => (doc.data()['ownerUid'] as String? ?? '').trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();

    final userStripeByUid = <String, String>{};
    for (final uid in ownerUids) {
      final userDoc = await db.collection('users').doc(uid).get();
      final stripeAccountId =
          (userDoc.data()?['stripeAccountId'] as String? ?? '').trim();
      userStripeByUid[uid] = stripeAccountId;
    }

    final docsToDelete = productsSnapshot.docs.where((doc) {
      final data = doc.data();
      final ownerUid = (data['ownerUid'] as String? ?? '').trim();
      final sellerStripeAccountId =
          (data['sellerStripeAccountId'] as String? ?? '').trim();
      final ownerStripeAccountId = userStripeByUid[ownerUid] ?? '';

      return ownerUid.isEmpty ||
          sellerStripeAccountId.isEmpty ||
          ownerStripeAccountId.isEmpty;
    }).toList();

    if (docsToDelete.isEmpty) {
      return;
    }

    WriteBatch? batch;
    var operations = 0;
    for (final doc in docsToDelete) {
      batch ??= db.batch();
      batch.delete(doc.reference);
      operations++;

      if (operations == 400) {
        await batch.commit();
        batch = null;
        operations = 0;
      }
    }

    if (batch != null && operations > 0) {
      await batch.commit();
    }
  }
}
