import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminPaymentsScreen extends StatelessWidget {
  static const String routeName = '/admin_payments';

  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const adminOrderService = AdminOrderService();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Payments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: adminOrderService.ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load payments: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          final paidOrders = docs.where((doc) {
            final status = ((doc.data()['paymentStatus'] as String?) ?? '')
                .trim()
                .toLowerCase();
            return status == 'paid';
          }).length;
          final refundedOrders = docs.where((doc) {
            final status = ((doc.data()['paymentStatus'] as String?) ?? '')
                .trim()
                .toLowerCase();
            return status == 'refunded';
          }).length;
          final pendingTransfers = docs.where((doc) {
            final status = ((doc.data()['sellerTransferStatus'] as String?) ?? '')
                .trim()
                .toLowerCase();
            return status == 'pending';
          }).length;
          final totalRevenue = docs.fold<double>(0, (totalValue, doc) {
            final data = doc.data();
            final status = ((data['paymentStatus'] as String?) ?? '')
                .trim()
                .toLowerCase();
            if (status != 'paid') return totalValue;
            return totalValue +
                ((data['totalPriceSar'] as num?)?.toDouble() ??
                    (data['total'] as num?)?.toDouble() ??
                    0);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Payment Overview',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track paid orders, refunds, and seller transfer progress.',
                style: TextStyle(color: Color(0xFF6B7C93)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PaymentStatCard(label: 'Revenue', value: 'SAR ${totalRevenue.toStringAsFixed(0)}'),
                  _PaymentStatCard(label: 'Paid Orders', value: '$paidOrders'),
                  _PaymentStatCard(label: 'Refunded', value: '$refundedOrders'),
                  _PaymentStatCard(label: 'Pending Transfers', value: '$pendingTransfers'),
                ],
              ),
              const SizedBox(height: 18),
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _paymentCardDecoration(),
                  child: const Text(
                    'No payment data available yet.',
                    style: TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...docs.take(20).map((doc) {
                  final data = doc.data();
                  final buyerName = (data['buyerName'] as String? ?? '').trim();
                  final paymentStatus =
                      ((data['paymentStatus'] as String?) ?? 'unknown').trim();
                  final transferStatus =
                      ((data['sellerTransferStatus'] as String?) ?? 'unknown')
                          .trim();
                  final total = (data['totalPriceSar'] as num?)?.toDouble() ??
                      (data['total'] as num?)?.toDouble() ??
                      0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: _paymentCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buyerName.isEmpty ? 'Unknown buyer' : buyerName,
                          style: const TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Payment Status: ${_prettyLabel(paymentStatus)}'),
                        Text('Seller Transfer: ${_prettyLabel(transferStatus)}'),
                        const SizedBox(height: 8),
                        Text(
                          'Total: SAR ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentStatCard extends StatelessWidget {
  const _PaymentStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: _paymentCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7C93))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: kTextColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

String _prettyLabel(String value) {
  if (value.isEmpty) return 'Unknown';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

BoxDecoration _paymentCardDecoration() {
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
