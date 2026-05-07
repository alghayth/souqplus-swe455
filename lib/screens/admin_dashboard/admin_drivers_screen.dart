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
  String? _updatingDriverId;

  Future<void> _confirmSetDriverBlocked({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool blocked,
    required int inTransitOrderCount,
  }) async {
    final data = doc.data();
    final driverName = _driverName(data);
    final email = _text(data, 'email', fallback: 'this driver');

    if (blocked && inTransitOrderCount > 0) {
      await _showDriverInTransitBlockWarning(
        driverName: driverName,
        inTransitOrderCount: inTransitOrderCount,
      );
      return;
    }

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Block Driver' : 'Unblock Driver'),
        content: Text(
          blocked
              ? 'Are you sure you want to block $driverName?\n\n$email will not be able to sign in as a driver.'
              : 'Are you sure you want to unblock $driverName?\n\n$email will be able to sign in as a driver again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              blocked ? 'Block' : 'Unblock',
              style: TextStyle(color: blocked ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) return;
    await _setDriverBlocked(
      doc: doc,
      blocked: blocked,
      driverName: driverName,
    );
  }

  Future<void> _showDriverInTransitBlockWarning({
    required String driverName,
    required int inTransitOrderCount,
  }) {
    final orderText = inTransitOrderCount == 1
        ? 'an in-transit order'
        : '$inTransitOrderCount in-transit orders';

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Driver In Transit'),
        content: Text(
          'You cannot block $driverName while the driver has $orderText. Please wait until the delivery is completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDriverBlocked({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool blocked,
    required String driverName,
  }) async {
    setState(() => _updatingDriverId = doc.id);
    try {
      if (blocked) {
        final inTransitOrderCount = await _service
            .inTransitOrderCountForDriver(driverId: doc.id);
        if (inTransitOrderCount > 0) {
          if (!mounted) return;
          await _showDriverInTransitBlockWarning(
            driverName: driverName,
            inTransitOrderCount: inTransitOrderCount,
          );
          return;
        }
      }

      await _service.updateDriverBlocked(driverId: doc.id, blocked: blocked);
      if (!mounted) return;
      await _showDriverAccessUpdatedMessage(
        driverName: driverName,
        blocked: blocked,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update driver access: $error')),
      );
    } finally {
      if (mounted) setState(() => _updatingDriverId = null);
    }
  }

  Future<void> _showDriverAccessUpdatedMessage({
    required String driverName,
    required bool blocked,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Driver Blocked' : 'Driver Unblocked'),
        content: Text(
          blocked
              ? '$driverName has been blocked successfully.'
              : '$driverName has been unblocked successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.ordersStream(),
            builder: (context, ordersSnapshot) {
              final inTransitOrdersByDriverId = ordersSnapshot.hasData
                  ? _inTransitOrdersByDriverId(ordersSnapshot.data!.docs)
                  : const <String, int>{};

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final isBlocked = _isBlocked(data);
                  final inTransitOrderCount =
                      inTransitOrdersByDriverId[doc.id] ?? 0;
                  return _DriverCard(
                    isRemoving: _removingDriverId == doc.id,
                    isUpdating: _updatingDriverId == doc.id,
                    isBlocked: isBlocked,
                    inTransitOrderCount: inTransitOrderCount,
                    name: _driverName(data),
                    email: _text(data, 'email', fallback: 'No email'),
                    phone: _text(data, 'phone', fallback: 'Not set'),
                    plate: _text(data, 'carPlate', fallback: 'Not set'),
                    carBrand: _text(data, 'carBrand', fallback: 'Not set'),
                    carModel: _text(data, 'carModel', fallback: 'Not set'),
                    uid: doc.id,
                    onSetBlocked: () => _confirmSetDriverBlocked(
                      doc: doc,
                      blocked: !isBlocked,
                      inTransitOrderCount: inTransitOrderCount,
                    ),
                    onRemove: () => _confirmRemoveDriver(doc),
                  );
                },
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
    required this.isUpdating,
    required this.isBlocked,
    required this.inTransitOrderCount,
    required this.name,
    required this.email,
    required this.phone,
    required this.plate,
    required this.carBrand,
    required this.carModel,
    required this.uid,
    required this.onSetBlocked,
    required this.onRemove,
  });

  final bool isRemoving;
  final bool isUpdating;
  final bool isBlocked;
  final int inTransitOrderCount;
  final String name;
  final String email;
  final String phone;
  final String plate;
  final String carBrand;
  final String carModel;
  final String uid;
  final VoidCallback onSetBlocked;
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (inTransitOrderCount > 0)
                    const _DriverBadge(
                      text: 'In Transit',
                      color: Color(0xFFF59E0B),
                    ),
                  _DriverBadge(
                    text: isBlocked ? 'Blocked' : 'Driver',
                    color: isBlocked ? Colors.red : Colors.green,
                  ),
                ],
              ),
              const SizedBox(width: 4),
              _DriverActionsMenu(
                isBlocked: isBlocked,
                isBusy: isUpdating || isRemoving,
                onSetBlocked: onSetBlocked,
                onRemove: onRemove,
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
        ],
      ),
    );
  }
}

class _DriverBadge extends StatelessWidget {
  const _DriverBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

enum _DriverRecordAction { setBlocked, remove }

class _DriverActionsMenu extends StatelessWidget {
  const _DriverActionsMenu({
    required this.isBlocked,
    required this.isBusy,
    required this.onSetBlocked,
    required this.onRemove,
  });

  final bool isBlocked;
  final bool isBusy;
  final VoidCallback onSetBlocked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DriverRecordAction>(
      enabled: !isBusy,
      tooltip: 'Driver actions',
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _DriverRecordAction.setBlocked:
            onSetBlocked();
            break;
          case _DriverRecordAction.remove:
            onRemove();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DriverRecordAction.setBlocked,
          child: _MenuActionLabel(
            icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
            text: isBlocked ? 'Unblock Driver' : 'Block Driver',
            color: isBlocked ? Colors.green : Colors.red,
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: _DriverRecordAction.remove,
          child: _MenuActionLabel(
            icon: Icons.delete_outline_rounded,
            text: 'Remove Driver',
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}

class _MenuActionLabel extends StatelessWidget {
  const _MenuActionLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
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

bool _isBlocked(Map<String, dynamic> data) {
  final status = (data['status'] as String? ?? '').trim().toLowerCase();
  return data['isBlocked'] == true ||
      data['blocked'] == true ||
      status == 'blocked' ||
      status == 'disabled';
}

Map<String, int> _inTransitOrdersByDriverId(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final counts = <String, int>{};
  for (final doc in docs) {
    final data = doc.data();
    final driverId = _text(data, 'driverId', fallback: '');
    if (driverId.isEmpty) continue;

    final status = AdminOrderService.normalizeOrderStatus(
      (data['status'] as String?) ?? '',
    );
    if (status != 'in transit') continue;

    counts[driverId] = (counts[driverId] ?? 0) + 1;
  }
  return counts;
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
