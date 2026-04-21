import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminDriversScreen extends StatefulWidget {
  static const String routeName = '/admin_drivers';

  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  final AdminOrderService _service = const AdminOrderService();
  String? _removingDriverId;

  Future<void> _confirmRemoveDriver(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final driverName = _driverName(data);
    final email = _text(data, 'email', fallback: 'No email');
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Driver'),
        content: Text(
          'Remove "$driverName" from the drivers list?\n\n$email will lose driver access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;
    await _removeDriver(doc: doc, driverName: driverName);
  }

  Future<void> _removeDriver({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String driverName,
  }) async {
    setState(() => _removingDriverId = doc.id);
    try {
      await _service.removeDriver(driverId: doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$driverName was removed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove driver: $error')),
      );
    } finally {
      if (mounted) setState(() => _removingDriverId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Registered Drivers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.driversStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FirebaseMessage(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load drivers: ${snapshot.error}',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aName = _driverName(a.data()).toLowerCase();
            final bName = _driverName(b.data()).toLowerCase();
            return aName.compareTo(bName);
          });

          if (docs.isEmpty) {
            return const _FirebaseMessage(
              icon: Icons.local_shipping_outlined,
              text: 'No registered drivers found in the database.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _DriverCard(
                isRemoving: _removingDriverId == doc.id,
                name: _driverName(data),
                email: _text(data, 'email', fallback: 'No email'),
                phone: _text(data, 'phone', fallback: 'Not set'),
                plate: _text(data, 'carPlate', fallback: 'Not set'),
                carBrand: _text(data, 'carBrand', fallback: 'Not set'),
                carModel: _text(data, 'carModel', fallback: 'Not set'),
                uid: doc.id,
                onRemove: () => _confirmRemoveDriver(doc),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.isRemoving,
    required this.name,
    required this.email,
    required this.phone,
    required this.plate,
    required this.carBrand,
    required this.carModel,
    required this.uid,
    required this.onRemove,
  });

  final bool isRemoving;
  final String name;
  final String email;
  final String phone;
  final String plate;
  final String carBrand;
  final String carModel;
  final String uid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Driver',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DriverLine(label: 'Email', value: email),
          _DriverLine(label: 'Phone', value: phone),
          _DriverLine(label: 'Car Plate', value: plate),
          _DriverLine(label: 'Car Brand', value: carBrand),
          _DriverLine(label: 'Car Model', value: carModel),
          _DriverLine(label: 'UID', value: uid),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRemoving ? null : onRemove,
              icon: isRemoving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(isRemoving ? 'Removing...' : 'Remove Driver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE8EEF5),
                disabledForegroundColor: const Color(0xFF6B7C93),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverLine extends StatelessWidget {
  const _DriverLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF6B7C93), fontSize: 12),
      ),
    );
  }
}

class _FirebaseMessage extends StatelessWidget {
  const _FirebaseMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kSecondaryColor, size: 38),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _driverName(Map<String, dynamic> data) {
  final fullName = _text(data, 'fullName', fallback: '');
  return fullName.isEmpty ? 'Registered Driver' : fullName;
}

String _text(
  Map<String, dynamic> data,
  String field, {
  required String fallback,
}) {
  final value = (data[field] as String? ?? '').trim();
  return value.isEmpty ? fallback : value;
}

BoxDecoration _adminCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFD8E3EE)),
    boxShadow: const [
      BoxShadow(color: Color(0x140E0820), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
