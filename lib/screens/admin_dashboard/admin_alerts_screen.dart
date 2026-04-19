import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminAlertsScreen extends StatelessWidget {
  static const String routeName = '/admin_alerts';

  const AdminAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const adminOrderService = AdminOrderService();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: adminOrderService.ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load alerts: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          final alerts = <_AlertItem>[];
          for (final doc in docs) {
            final data = doc.data();
            final buyerName = (data['buyerName'] as String? ?? 'Unknown buyer').trim();
            final orderStatus = AdminOrderService.normalizeOrderStatus(
              (data['status'] as String?) ?? '',
            );
            final paymentStatus =
                ((data['paymentStatus'] as String?) ?? '').trim().toLowerCase();

            if (orderStatus == 'ordered') {
              alerts.add(_AlertItem(
                title: 'Ordered item needs follow-up',
                message: 'Order for $buyerName is waiting to move in transit.',
                color: Colors.orange,
              ));
            }
            if (paymentStatus == 'refunded') {
              alerts.add(_AlertItem(
                title: 'Refund recorded',
                message: 'A payment for $buyerName has been refunded.',
                color: Colors.red,
              ));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'System Alerts',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Important order and payment items that may need admin action.',
                style: TextStyle(color: Color(0xFF6B7C93)),
              ),
              const SizedBox(height: 16),
              if (alerts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _alertCardDecoration(),
                  child: const Text(
                    'No alerts right now. Everything looks clear.',
                    style: TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...alerts.map((alert) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: _alertCardDecoration(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: alert.color.withValues(alpha: 0.15),
                            child: Icon(Icons.notifications_active_rounded,
                                color: alert.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: const TextStyle(
                                    color: kTextColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  alert.message,
                                  style: const TextStyle(color: Color(0xFF6B7C93)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _AlertItem {
  const _AlertItem({
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;
}

BoxDecoration _alertCardDecoration() {
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
