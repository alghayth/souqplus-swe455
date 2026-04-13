import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.paymentIntentId,
    this.amountSar,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId;
  final String? paymentIntentId;
  final double? amountSar;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];

    return AppNotification(
      id: doc.id,
      type: (data['type'] as String? ?? 'general').trim(),
      title: (data['title'] as String? ?? 'Notification').trim(),
      message: (data['message'] as String? ?? '').trim(),
      isRead: data['isRead'] as bool? ?? false,
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      orderId: (data['orderId'] as String?)?.trim(),
      paymentIntentId: (data['paymentIntentId'] as String?)?.trim(),
      amountSar: (data['amountSar'] as num?)?.toDouble(),
    );
  }
}
