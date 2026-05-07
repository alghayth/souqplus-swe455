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
  String _selectedStatus = 'pending';
  String? _updatingOrderId;

  Future<void> _assignDriver({
    required String orderId,
    required _DriverAssignmentOption driver,
  }) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await _adminOrderService.assignDriverToOrder(
        orderId: orderId,
        driverId: driver.id,
        driverName: driver.name,
        driverEmail: driver.email,
        driverPhoneNumber: driver.phoneNumber,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned ${driver.name} to this order.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyUpdateErrorMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 246, 210),
      appBar: AppBar(title: const PageHeaderTitle('Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminOrderService.driversStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load drivers: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDrivers =
              snapshot.data?.docs
                  .map((doc) => _DriverAssignmentOption.fromDoc(doc))
                  .toList() ??
              const <_DriverAssignmentOption>[];
          final activeDrivers = allDrivers
              .where((driver) => !driver.isBlocked)
              .toList();
          final driversById = {
            for (final driver in allDrivers) driver.id: driver,
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _adminOrderService.ordersStream(),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.hasError) {
                return Center(
                  child: Text('Could not load orders: ${orderSnapshot.error}'),
                );
              }
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = [...?orderSnapshot.data?.docs];
              docs.sort((a, b) {
                final aWorkflow = _adminWorkflowStatus(
                  a.data(),
                  driversById: driversById,
                );
                final bWorkflow = _adminWorkflowStatus(
                  b.data(),
                  driversById: driversById,
                );
                final statusCompare = _workflowSortIndex(
                  aWorkflow,
                ).compareTo(_workflowSortIndex(bWorkflow));
                if (statusCompare != 0) return statusCompare;

                final aMillis = _createdAtMillis(a.data());
                final bMillis = _createdAtMillis(b.data());
                return bMillis.compareTo(aMillis);
              });
              final filteredDocs = docs.where((doc) {
                return _adminWorkflowStatus(
                      doc.data(),
                      driversById: driversById,
                    ) ==
                    _selectedStatus;
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
                    'Track live order progress and assign a driver for delivery.',
                    style: TextStyle(color: Color(0xFF6B7C93)),
                  ),
                  const SizedBox(height: 16),
                  _WorkflowStatusSelector(
                    selectedStatus: _selectedStatus,
                    onChanged: (status) =>
                        setState(() => _selectedStatus = status),
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
                      final buyerName = (data['buyerName'] as String? ?? '')
                          .trim();
                      final buyerEmail = (data['buyerEmail'] as String? ?? '')
                          .trim();
                      final buyerPhone =
                          (data['buyerPhoneNumber'] as String? ?? '').trim();
                      final deliveryAddress =
                          (data['deliveryAddress'] as String? ?? '').trim();
                      final assignedDriverId =
                          (data['driverId'] as String? ?? '').trim();
                      final assignedDriverName =
                          (data['driverName'] as String? ?? '').trim();
                      final assignedDriver = driversById[assignedDriverId];
                      final total =
                          (data['totalPriceSar'] as num?)?.toDouble() ??
                          (data['total'] as num?)?.toDouble() ??
                          0;
                      final rawOrderStatus =
                          AdminOrderService.normalizeOrderStatus(
                            (data['status'] as String?) ?? '',
                          );
                      final driverIssue = _driverAccessIssue(
                        data,
                        driver: assignedDriver,
                        orderStatus: rawOrderStatus,
                      );
                      final normalizedOrderStatus = _adminWorkflowStatus(
                        data,
                        driversById: driversById,
                      );
                      final isDelivered = rawOrderStatus == 'delivered';

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
                              buyerEmail.isEmpty
                                  ? 'No email available'
                                  : buyerEmail,
                              style: const TextStyle(color: Color(0xFF6B7C93)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order ID: ${doc.id}',
                              style: const TextStyle(color: Color(0xFF6B7C93)),
                            ),
                            if (buyerPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Phone: $buyerPhone',
                                style: const TextStyle(
                                  color: Color(0xFF6B7C93),
                                ),
                              ),
                            ],
                            if (deliveryAddress.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Delivery: $deliveryAddress',
                                style: const TextStyle(
                                  color: Color(0xFF6B7C93),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Total: SAR ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kSecondaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ProductsSummary(data: data),
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
                            if (isDelivered)
                              _AssignedDriverNameSection(
                                driverName: assignedDriverName,
                              )
                            else
                              _DriverAssignmentSection(
                                selectedDriverId: assignedDriverId,
                                assignedDriverName: driverIssue == null
                                    ? assignedDriverName
                                    : '',
                                drivers: activeDrivers,
                                busy: _updatingOrderId == doc.id,
                                onChanged: (driver) => _assignDriver(
                                  orderId: doc.id,
                                  driver: driver,
                                ),
                              ),
                            if (driverIssue != null &&
                                (rawOrderStatus == 'in transit' ||
                                    rawOrderStatus == 'delivered')) ...[
                              const SizedBox(height: 10),
                              _DriverAccessWarning(issue: driverIssue),
                            ],
                            const SizedBox(height: 14),
                            _ReadOnlyStatusSection(
                              value: normalizedOrderStatus,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
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

class _ReadOnlyStatusSection extends StatelessWidget {
  const _ReadOnlyStatusSection({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'pending' => Colors.orange,
      'ordered' => Colors.orange,
      'assigned' => kSecondaryColor,
      'in transit' => Colors.blue,
      'delivered' => Colors.green,
      _ => const Color(0xFF6B7C93),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Status',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                _prettyLabel(value),
                style: const TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkflowStatusSelector extends StatelessWidget {
  const _WorkflowStatusSelector({
    required this.selectedStatus,
    required this.onChanged,
  });

  final String selectedStatus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _adminWorkflowStatuses.map((status) {
        final selected = status == selectedStatus;
        final isLast = status == _adminWorkflowStatuses.last;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 46,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? kSecondaryColor : const Color(0xFFFFFBFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? kSecondaryColor : const Color(0xFFD6C7DE),
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x1F0E3A6D),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _prettyLabel(status),
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : kTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DriverAssignmentSection extends StatelessWidget {
  const _DriverAssignmentSection({
    required this.selectedDriverId,
    required this.assignedDriverName,
    required this.drivers,
    required this.busy,
    required this.onChanged,
  });

  final String selectedDriverId;
  final String assignedDriverName;
  final List<_DriverAssignmentOption> drivers;
  final bool busy;
  final ValueChanged<_DriverAssignmentOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelectedDriver = drivers.any(
      (driver) => driver.id == selectedDriverId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Driver',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (drivers.isEmpty)
          const Text(
            'No active drivers available for assignment.',
            style: TextStyle(color: Color(0xFF6B7C93)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: hasSelectedDriver ? selectedDriverId : null,
                hint: Text(
                  assignedDriverName.isEmpty
                      ? 'Select a driver'
                      : assignedDriverName,
                ),
                onChanged: busy
                    ? null
                    : (selectedId) {
                        _DriverAssignmentOption? driver;
                        for (final item in drivers) {
                          if (item.id == selectedId) {
                            driver = item;
                            break;
                          }
                        }
                        if (driver != null) {
                          onChanged(driver);
                        }
                      },
                items: drivers
                    .map(
                      (driver) => DropdownMenuItem<String>(
                        value: driver.id,
                        child: Text(driver.label),
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

class _AssignedDriverNameSection extends StatelessWidget {
  const _AssignedDriverNameSection({required this.driverName});

  final String driverName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivered By',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            driverName.isEmpty ? 'Driver not available' : driverName,
            style: const TextStyle(
              color: kTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverAccessWarning extends StatelessWidget {
  const _DriverAccessWarning({required this.issue});

  final _DriverAccessIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB45309),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              issue.message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsSummary extends StatelessWidget {
  const _ProductsSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rawProducts = data['products'] ?? data['items'];
    if (rawProducts is! List || rawProducts.isEmpty) {
      return const Text(
        'Products: Not available',
        style: TextStyle(color: Color(0xFF6B7C93)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Products',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...rawProducts.take(4).map((item) {
          if (item is! Map) {
            return const SizedBox.shrink();
          }
          final title = (item['title'] as String? ?? 'Product').trim();
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final lineTotal =
              (item['lineTotalSar'] as num?)?.toDouble() ??
              (item['priceSar'] as num?)?.toDouble() ??
              0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$title x$quantity - SAR ${lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF6B7C93)),
            ),
          );
        }),
        if (rawProducts.length > 4)
          Text(
            '+ ${rawProducts.length - 4} more item(s)',
            style: const TextStyle(color: Color(0xFF6B7C93)),
          ),
      ],
    );
  }
}

class _DriverAssignmentOption {
  const _DriverAssignmentOption({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.isBlocked,
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final bool isBlocked;

  String get label => email.isEmpty ? name : '$name - $email';

  factory _DriverAssignmentOption.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final status = (data['status'] as String? ?? '').trim().toLowerCase();
    final isBlocked =
        data['isBlocked'] == true ||
        data['blocked'] == true ||
        status == 'blocked' ||
        status == 'disabled';

    final name = (data['fullName'] as String? ?? '').trim();
    final email = (data['email'] as String? ?? '').trim();
    final profilePhone = (data['phoneNumber'] as String? ?? '').trim();
    final registrationPhone = (data['phone'] as String? ?? '').trim();
    final phoneNumber = profilePhone.isNotEmpty
        ? profilePhone
        : registrationPhone;

    return _DriverAssignmentOption(
      id: doc.id,
      name: name.isEmpty ? 'Registered Driver' : name,
      email: email,
      phoneNumber: phoneNumber,
      isBlocked: isBlocked,
    );
  }
}

String _prettyLabel(String value) {
  if (value.isEmpty) return 'Unknown';
  if (value == 'in transit') return 'In Transit';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

const List<String> _adminWorkflowStatuses = [
  'pending',
  'assigned',
  'in transit',
  'delivered',
];

String _adminWorkflowStatus(
  Map<String, dynamic> data, {
  required Map<String, _DriverAssignmentOption> driversById,
}) {
  final normalizedStatus = AdminOrderService.normalizeOrderStatus(
    (data['status'] as String?) ?? '',
  );
  if (normalizedStatus == 'delivered' || normalizedStatus == 'in transit') {
    return normalizedStatus;
  }

  final driverId = (data['driverId'] as String? ?? '').trim();
  final driverName = (data['driverName'] as String? ?? '').trim();
  final driver = driversById[driverId];
  final hasActiveDriver = driver != null && !driver.isBlocked;
  if (hasActiveDriver || (driverId.isEmpty && driverName.isNotEmpty)) {
    return 'assigned';
  }

  return 'pending';
}

_DriverAccessIssue? _driverAccessIssue(
  Map<String, dynamic> data, {
  required _DriverAssignmentOption? driver,
  required String orderStatus,
}) {
  final driverId = (data['driverId'] as String? ?? '').trim();
  final driverName = (data['driverName'] as String? ?? '').trim();
  if (driverId.isEmpty && driverName.isEmpty) {
    if (orderStatus == 'in transit') {
      return const _DriverAccessIssue(
        'This in-transit order has no assigned driver. Contact the driver and reassign the order.',
      );
    }
    return null;
  }

  final name = driverName.isNotEmpty
      ? driverName
      : (driver?.name ?? 'This driver');
  final actionMessage = orderStatus == 'in transit'
      ? ' Contact the driver and reassign the order.'
      : '';

  if (driver == null && driverId.isNotEmpty) {
    return _DriverAccessIssue(
      '$name was removed and is no longer available as a driver.$actionMessage',
    );
  }
  if (driver?.isBlocked == true) {
    return _DriverAccessIssue(
      '$name is blocked and no longer has driver access.$actionMessage',
    );
  }

  return null;
}

class _DriverAccessIssue {
  const _DriverAccessIssue(this.message);

  final String message;
}

int _workflowSortIndex(String status) {
  final index = _adminWorkflowStatuses.indexOf(status);
  return index == -1 ? _adminWorkflowStatuses.length : index;
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

int _createdAtMillis(Map<String, dynamic> data) {
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) {
    return createdAt.millisecondsSinceEpoch;
  }
  return 0;
}
