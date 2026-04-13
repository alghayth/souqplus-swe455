import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  static const String routeName = '/admin_orders';

  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final AdminOrderService _adminOrderService = const AdminOrderService();
  String _selectedStatus = 'All';
  String? _updatingOrderId;

  Future<void> _updateField({
    required String orderId,
    required String field,
    required String value,
  }) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await _adminOrderService.updateOrderField(
        orderId: orderId,
        field: field,
        value: value,
      );
      if (!mounted) return;
      final fieldLabel = switch (field) {
        'status' => 'Order status',
        'paymentStatus' => 'Payment status',
        'sellerTransferStatus' => 'Seller transfer status',
        _ => _prettyLabel(field),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fieldLabel updated successfully to ${_prettyLabel(value)}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyUpdateErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(
        title: const PageHeaderTitle('Orders'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminOrderService.ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load orders: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          final statuses = <String>{
            'All',
            ...AdminOrderService.orderLifecycle,
          };
          for (final doc in docs) {
            final status = ((doc.data()['status'] as String?) ?? '').trim().toLowerCase();
            if (status.isNotEmpty) statuses.add(status);
          }
          final filteredDocs = _selectedStatus == 'All'
              ? docs
              : docs.where((doc) {
                  final status = ((doc.data()['status'] as String?) ?? '').trim().toLowerCase();
                  return status == _selectedStatus.toLowerCase();
                }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Manage order workflow',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Update fulfillment, payment, and seller transfer status for each order.',
                style: TextStyle(color: Color(0xFF6B7C93)),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: statuses.map((status) {
                    final selected = status == _selectedStatus;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_prettyLabel(status)),
                        selected: selected,
                        selectedColor: kSecondaryColor,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : kTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _selectedStatus = status),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (filteredDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: const Text(
                    'No orders available for this filter.',
                    style: TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final data = doc.data();
                  final buyerName = (data['buyerName'] as String? ?? '').trim();
                  final buyerEmail = (data['buyerEmail'] as String? ?? '').trim();
                  final total = (data['totalPriceSar'] as num?)?.toDouble() ??
                      (data['total'] as num?)?.toDouble() ??
                      0;
                  final orderStatus = ((data['status'] as String?) ?? 'pending')
                      .trim()
                      .toLowerCase();
                  final paymentStatus =
                      ((data['paymentStatus'] as String?) ?? 'paid')
                          .trim()
                          .toLowerCase();
                  final transferStatus =
                      ((data['sellerTransferStatus'] as String?) ?? 'pending')
                          .trim()
                          .toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buyerName.isEmpty ? 'Unknown buyer' : buyerName,
                          style: const TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 14),
                        _StatusSection(
                          label: 'Order Status',
                          value: orderStatus,
                          values: AdminOrderService.orderLifecycle,
                          busy: _updatingOrderId == doc.id,
                          onChanged: (value) => _updateField(
                            orderId: doc.id,
                            field: 'status',
                            value: value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusSection(
                          label: 'Payment Status',
                          value: paymentStatus,
                          values: AdminOrderService.paymentLifecycle,
                          busy: _updatingOrderId == doc.id,
                          onChanged: (value) => _updateField(
                            orderId: doc.id,
                            field: 'paymentStatus',
                            value: value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusSection(
                          label: 'Seller Transfer',
                          value: transferStatus,
                          values: AdminOrderService.transferLifecycle,
                          busy: _updatingOrderId == doc.id,
                          onChanged: (value) => _updateField(
                            orderId: doc.id,
                            field: 'sellerTransferStatus',
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

String _friendlyUpdateErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase denied this update. Deploy firestore.rules and confirm this admin user has role "admin" or isAdmin true in the Firestore database "souqplus".';
  }

  return 'Could not update order. Please try again.';
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.label,
    required this.value,
    required this.values,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
              value: values.contains(value) ? value : values.first,
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

String _prettyLabel(String value) {
  if (value.isEmpty) return 'Unknown';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

BoxDecoration _cardDecoration() {
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
