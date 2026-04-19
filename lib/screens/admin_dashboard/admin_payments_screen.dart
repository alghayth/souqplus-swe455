import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminPaymentsScreen extends StatefulWidget {
  static const String routeName = '/admin_payments';

  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final AdminOrderService _adminOrderService = const AdminOrderService();
  String? _updatingOrderId;

  Future<void> _updatePaymentStatus({
    required String orderId,
    required String value,
  }) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await _adminOrderService.updateOrderField(
        orderId: orderId,
        field: 'paymentStatus',
        value: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment status updated successfully to ${_prettyLabel(value)}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyPaymentErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Payments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminOrderService.ordersStream(),
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
                'Track and update payment status for each order.',
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
                  final buyerEmail = (data['buyerEmail'] as String? ?? '').trim();
                  final paymentStatus =
                      ((data['paymentStatus'] as String?) ?? 'unpaid')
                          .trim()
                          .toLowerCase();
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
                        Text(
                          buyerEmail.isEmpty ? 'No email available' : buyerEmail,
                          style: const TextStyle(color: Color(0xFF6B7C93)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: SAR ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_updatingOrderId == doc.id) ...[
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Updating in Firebase...',
                                style: TextStyle(
                                  color: Color(0xFF6B7C93),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _PaymentStatusSection(
                          value: paymentStatus,
                          busy: _updatingOrderId == doc.id,
                          onChanged: (value) => _updatePaymentStatus(
                            orderId: doc.id,
                            value: value,
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

class _PaymentStatusSection extends StatelessWidget {
  const _PaymentStatusSection({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String value;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = AdminOrderService.paymentLifecycle;
    final selectedValue = values.contains(value) ? value : values.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Status',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              onChanged: busy
                  ? null
                  : (selected) {
                      if (selected != null && selected != value) {
                        onChanged(selected);
                      }
                    },
              items: values
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(_prettyLabel(item)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
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

String _friendlyPaymentErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase denied this payment update. Confirm this admin user has role "admin" or isAdmin true in the Firestore database "souqplus".';
  }

  return 'Could not update payment status. Please try again.';
}
