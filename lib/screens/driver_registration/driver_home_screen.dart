// ignore_for_file: file_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';
import 'package:souqplus/services/admin_order_service.dart';

class DriverHomeScreen extends StatefulWidget {
  static String routeName = "/driver_home";

  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AdminOrderService _orderService = const AdminOrderService();
  bool _isLoggingOut = false;
  String? _updatingOrderId;

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully.')),
      );
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        SignInScreen.routeName,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log out: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _updateOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await _orderService.updateOrderField(
        orderId: orderId,
        field: 'status',
        value: nextStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delivery updated to ${_prettyLabel(nextStatus)}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyUpdateErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final driverUid = currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6D2),
      appBar: AppBar(
        title: const PageHeaderTitle('Driver Dashboard'),
        actions: [
          IconButton(
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _isLoggingOut ? null : _confirmLogout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: driverUid.isEmpty
            ? null
            : _orderService.driverOrdersStream(driverId: driverUid),
        builder: (context, snapshot) {
          if (driverUid.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Driver session is not available. Please sign in again.'),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load deliveries: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignedDocs = snapshot.data?.docs ?? const [];
          final activeDocs = assignedDocs.where((doc) {
            final status = AdminOrderService.normalizeOrderStatus(
              (doc.data()['status'] as String? ?? ''),
            );
            return status != 'delivered';
          }).toList()
            ..sort((a, b) => _compareByCreatedAtDescending(a.data(), b.data()));
          final deliveredCount = assignedDocs.where((doc) {
            final status = AdminOrderService.normalizeOrderStatus(
              (doc.data()['status'] as String? ?? ''),
            );
            return status == 'delivered';
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDashboardCard(
                activeCount: activeDocs.length,
                deliveredCount: deliveredCount,
              ),
              const SizedBox(height: 16),
              const Text(
                'My Deliveries',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Showing deliveries assigned to your driver account.',
                style: TextStyle(color: Color(0xFF6B7C93)),
              ),
              const SizedBox(height: 12),
              if (activeDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: const Text(
                    'No active deliveries are available right now.',
                    style: TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...activeDocs.map((doc) {
                  final data = doc.data();
                  final status = AdminOrderService.normalizeOrderStatus(
                    (data['status'] as String? ?? ''),
                  );
                  final pickupAddress = _pickupAddress(data);
                  final dropOffAddress = _dropOffAddress(data);
                  final buyerName = _readText(data, 'buyerName');
                  final buyerPhone = _readText(data, 'buyerPhoneNumber');
                  final buyerEmail = _readText(data, 'buyerEmail');
                  final itemCount = _itemCount(data);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    buyerName.isEmpty
                                        ? 'Unknown buyer'
                                        : buyerName,
                                    style: const TextStyle(
                                      color: kTextColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order #${doc.id.substring(0, 6).toUpperCase()}',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7C93),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$itemCount item(s) in this delivery',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7C93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.store_mall_directory_outlined,
                          label: 'Pickup address',
                          value: pickupAddress,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Drop-off address',
                          value: dropOffAddress,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Buyer phone',
                          value: buyerPhone.isEmpty
                              ? 'Phone number not available'
                              : buyerPhone,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'Buyer email',
                          value: buyerEmail.isEmpty
                              ? 'Email not available'
                              : buyerEmail,
                        ),
                        if (_updatingOrderId == doc.id) ...[
                          const SizedBox(height: 14),
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
                                'Updating delivery status...',
                                style: TextStyle(
                                  color: Color(0xFF6B7C93),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _buildStatusActions(
                            orderId: doc.id,
                            status: status,
                            busy: _updatingOrderId == doc.id,
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

  Widget _buildDashboardCard({
    required int activeCount,
    required int deliveredCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor,
            kPrimaryColor.withAlpha(200),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DashboardStat(title: 'Active', value: '$activeCount'),
              _DashboardStat(title: 'Delivered', value: '$deliveredCount'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Open a delivery below to view pickup, drop-off, and buyer contact details.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusActions({
    required String orderId,
    required String status,
    required bool busy,
  }) {
    final actions = <Widget>[];

    if (status == 'ordered') {
      actions.add(
        _ActionButton(
          label: 'Start Transit',
          color: Colors.orange,
          onPressed: busy
              ? null
              : () => _updateOrderStatus(
                    orderId: orderId,
                    nextStatus: 'in transit',
                  ),
        ),
      );
    }

    if (status == 'in transit') {
      actions.add(
        _ActionButton(
          label: 'Mark Delivered',
          color: Colors.green,
          onPressed: busy
              ? null
              : () => _updateOrderStatus(
                    orderId: orderId,
                    nextStatus: 'delivered',
                  ),
        ),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        const _ActionButton(
          label: 'Delivered',
          color: Colors.green,
          onPressed: null,
        ),
      );
    }

    return actions;
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ordered' => Colors.orange,
      'in transit' => Colors.blue,
      'delivered' => Colors.green,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _prettyLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kSecondaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7C93),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

int _compareByCreatedAtDescending(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aTimestamp = a['createdAt'];
  final bTimestamp = b['createdAt'];
  final aMillis = aTimestamp is Timestamp ? aTimestamp.millisecondsSinceEpoch : 0;
  final bMillis = bTimestamp is Timestamp ? bTimestamp.millisecondsSinceEpoch : 0;
  return bMillis.compareTo(aMillis);
}

String _pickupAddress(Map<String, dynamic> data) {
  final directPickup = _readText(data, 'pickupLocationDetails');
  if (directPickup.isNotEmpty) return directPickup;

  final fallbackPickup = _readText(data, 'pickupAddressText');
  if (fallbackPickup.isNotEmpty) return fallbackPickup;

  final rawPickup = data['pickupAddress'];
  if (rawPickup is Map) {
    final pickupMap = Map<String, dynamic>.from(rawPickup);
    final details = _readText(pickupMap, 'details');
    if (details.isNotEmpty) return details;
    final address = _readText(pickupMap, 'address');
    if (address.isNotEmpty) return address;
  }

  return 'Pickup address not available on this order yet';
}

String _dropOffAddress(Map<String, dynamic> data) {
  final deliveryLocation = data['buyerDeliveryLocation'];
  if (deliveryLocation is Map) {
    final deliveryMap = Map<String, dynamic>.from(deliveryLocation);
    final details = _readText(deliveryMap, 'details');
    if (details.isNotEmpty) return details;
    final address = _readText(deliveryMap, 'address');
    if (address.isNotEmpty) return address;
  }

  final detailedLocation = _readText(data, 'deliveryLocationDetails');
  if (detailedLocation.isNotEmpty) return detailedLocation;

  final deliveryAddress = _readText(data, 'deliveryAddress');
  if (deliveryAddress.isNotEmpty) return deliveryAddress;

  return 'Drop-off address not available';
}

String _readText(Map<String, dynamic> data, String key) {
  return (data[key] as String? ?? '').trim();
}

int _itemCount(Map<String, dynamic> data) {
  final rawItems = data['products'] ?? data['items'];
  if (rawItems is! List) return 0;

  var count = 0;
  for (final item in rawItems) {
    if (item is Map) {
      count += (item['quantity'] as num?)?.toInt() ?? 1;
    }
  }
  return count;
}

String _prettyLabel(String value) {
  if (value.isEmpty) return 'Unknown';
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'in transit' => 'In Transit',
    'ordered' => 'Ordered',
    'delivered' => 'Delivered',
    _ => value[0].toUpperCase() + value.substring(1),
  };
}

String _friendlyUpdateErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase denied this update. Deploy firestore.rules and confirm drivers can update delivery status.';
  }

  return 'Could not update delivery status. Please try again.';
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFD8E3EE)),
    boxShadow: const [
      BoxShadow(color: Color(0x140E0820), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
