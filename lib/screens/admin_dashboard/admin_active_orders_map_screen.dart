import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

const double _riyadhMinLatitude = 24.35;
const double _riyadhMaxLatitude = 25.05;
const double _riyadhMinLongitude = 46.25;
const double _riyadhMaxLongitude = 47.05;

class AdminActiveOrdersMapScreen extends StatefulWidget {
  static const String routeName = '/admin_active_orders_map';

  const AdminActiveOrdersMapScreen({super.key});

  @override
  State<AdminActiveOrdersMapScreen> createState() =>
      _AdminActiveOrdersMapScreenState();
}

class _AdminActiveOrdersMapScreenState
    extends State<AdminActiveOrdersMapScreen> {
  final AdminOrderService _adminOrderService = const AdminOrderService();
  String _selectedFilter = 'in transit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6D2),
      appBar: AppBar(title: const PageHeaderTitle('Active Orders Map')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminOrderService.ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load active orders: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = (snapshot.data?.docs ?? const [])
              .map(_TrackedOrder.fromDoc)
              .where((order) => order.isActive)
              .toList()
            ..sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
          final inTransitOrders = orders
              .where((order) => order.status == 'in transit')
              .toList();
          final orderedOrders = orders
              .where((order) => order.status == 'ordered')
              .toList();
          final selectedOrders = switch (_selectedFilter) {
            'ordered' => orderedOrders,
            'all' => orders,
            _ => inTransitOrders,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OperationsSummary(
                activeCount: orders.length,
                inTransitCount: inTransitOrders.length,
                orderedCount: orderedOrders.length,
              ),
              const SizedBox(height: 14),
              _OrdersMapFilter(
                selectedFilter: _selectedFilter,
                allCount: orders.length,
                orderedCount: orderedOrders.length,
                inTransitCount: inTransitOrders.length,
                onChanged: (filter) => setState(() => _selectedFilter = filter),
              ),
              const SizedBox(height: 14),
              if (selectedOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Text(
                    _emptyMessage(_selectedFilter),
                    style: const TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...selectedOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AdminTrackedOrderCard(order: order),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({
    required this.activeCount,
    required this.inTransitCount,
    required this.orderedCount,
  });

  final int activeCount;
  final int inTransitCount;
  final int orderedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3B66),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations Tracking',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Monitor real-time Riyadh driver, seller, and buyer locations for active orders.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(label: '$activeCount Active'),
              _SummaryPill(label: '$inTransitCount In Transit'),
              _SummaryPill(label: '$orderedCount Ordered'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrdersMapFilter extends StatelessWidget {
  const _OrdersMapFilter({
    required this.selectedFilter,
    required this.allCount,
    required this.orderedCount,
    required this.inTransitCount,
    required this.onChanged,
  });

  final String selectedFilter;
  final int allCount;
  final int orderedCount;
  final int inTransitCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <({String value, String label, int count})>[
      (value: 'in transit', label: 'In Transit', count: inTransitCount),
      (value: 'ordered', label: 'Ordered', count: orderedCount),
      (value: 'all', label: 'All Active', count: allCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = filter.value == selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${filter.label} (${filter.count})'),
              selected: selected,
              selectedColor: kSecondaryColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : kTextColor,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(filter.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AdminTrackedOrderCard extends StatelessWidget {
  const _AdminTrackedOrderCard({required this.order});

  final _TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      'Order #${order.shortId}',
                      style: const TextStyle(
                        color: kTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.buyerName.isEmpty
                          ? 'Unknown buyer'
                          : order.buyerName,
                      style: const TextStyle(color: Color(0xFF6B7C93)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.driverName.isEmpty
                          ? 'Driver not assigned'
                          : 'Driver: ${order.driverName}',
                      style: const TextStyle(color: Color(0xFF6B7C93)),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 14),
          _AdminRouteMap(order: order),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.store_mall_directory_outlined,
            label: 'Pickup',
            value: order.pickupAddress.isEmpty
                ? 'Pickup address not available'
                : order.pickupAddress,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Drop-off',
            value: order.dropOffAddress.isEmpty
                ? 'Drop-off address not available'
                : order.dropOffAddress,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.my_location_outlined,
            label: 'Driver',
            value: order.driverPoint == null
                ? 'Waiting for live Riyadh driver location'
                : 'Live location updated ${_formatTimestamp(order.driverLocationUpdatedAt)}',
          ),
        ],
      ),
    );
  }
}

class _AdminRouteMap extends StatelessWidget {
  const _AdminRouteMap({required this.order});

  final _TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final resolvedCenter =
        order.driverPoint ??
        order.pickupPoint ??
        order.dropOffPoint ??
        _riyadhCenter;
    final polylinePoints = _buildPolylinePoints(order);
    final markers = <Marker>[
      if (order.pickupPoint != null)
        _marker(
          point: order.pickupPoint!,
          icon: Icons.store_mall_directory_rounded,
          color: const Color(0xFFF59E0B),
        ),
      if (order.driverPoint != null)
        _marker(
          point: order.driverPoint!,
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFF16A34A),
        ),
      if (order.dropOffPoint != null)
        _marker(
          point: order.dropOffPoint!,
          icon: Icons.home_rounded,
          color: const Color(0xFF1D4ED8),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MapLegendChip(
                icon: Icons.delivery_dining_rounded,
                label: 'Driver',
                color: Color(0xFF16A34A),
              ),
              _MapLegendChip(
                icon: Icons.store_mall_directory_rounded,
                label: 'Seller',
                color: Color(0xFFF59E0B),
              ),
              _MapLegendChip(
                icon: Icons.home_rounded,
                label: 'Buyer',
                color: Color(0xFF1D4ED8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                key: ValueKey(
                  '${order.id}-${order.driverPoint?.latitude ?? 0}-${order.driverPoint?.longitude ?? 0}-${order.status}',
                ),
                options: MapOptions(
                  initialCenter: latlng.LatLng(
                    resolvedCenter.latitude,
                    resolvedCenter.longitude,
                  ),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.souqplus',
                  ),
                  if (polylinePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polylinePoints,
                          color: const Color(0xAA16A34A),
                          strokeWidth: 10,
                        ),
                        Polyline(
                          points: polylinePoints,
                          color: const Color(0xFF16A34A),
                          strokeWidth: 6,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _routeLabel(order),
            style: const TextStyle(
              color: Color(0xFF166534),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static const LatLngPoint _riyadhCenter = LatLngPoint(
    latitude: 24.7136,
    longitude: 46.6753,
  );
}

class _MapLegendChip extends StatelessWidget {
  const _MapLegendChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isInTransit = status == 'in transit';
    final color = isInTransit ? const Color(0xFFF59E0B) : kSecondaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _prettyLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
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
        Icon(icon, color: kSecondaryColor, size: 20),
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
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: kTextColor)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackedOrder {
  const _TrackedOrder({
    required this.id,
    required this.status,
    required this.buyerName,
    required this.driverName,
    required this.pickupAddress,
    required this.dropOffAddress,
    required this.pickupPoint,
    required this.driverPoint,
    required this.dropOffPoint,
    required this.driverLocationUpdatedAt,
    required this.createdAtMillis,
  });

  final String id;
  final String status;
  final String buyerName;
  final String driverName;
  final String pickupAddress;
  final String dropOffAddress;
  final LatLngPoint? pickupPoint;
  final LatLngPoint? driverPoint;
  final LatLngPoint? dropOffPoint;
  final DateTime? driverLocationUpdatedAt;
  final int createdAtMillis;

  bool get isActive => status == 'ordered' || status == 'in transit';

  String get shortId {
    final compactId = id.trim();
    if (compactId.length <= 6) return compactId.toUpperCase();
    return compactId.substring(0, 6).toUpperCase();
  }

  static _TrackedOrder fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawStatus = (data['status'] as String? ?? '').trim();
    final status = AdminOrderService.normalizeOrderStatus(rawStatus);
    final createdAt = data['createdAt'];
    final driverLocationUpdatedAt = data['driverLocationUpdatedAt'];

    return _TrackedOrder(
      id: doc.id,
      status: status.isEmpty ? 'ordered' : status,
      buyerName: _readText(data, 'buyerName'),
      driverName: _readText(data, 'driverName'),
      pickupAddress: _pickupAddress(data),
      dropOffAddress: _dropOffAddress(data),
      pickupPoint: _readLatLng(data['pickupAddress']),
      driverPoint: _readLatLng(data['driverCurrentLocation']),
      dropOffPoint:
          _readLatLng(data['buyerDeliveryLocation']) ??
          _readLatLng(data['deliveryGeoPoint']),
      driverLocationUpdatedAt: driverLocationUpdatedAt is Timestamp
          ? driverLocationUpdatedAt.toDate()
          : null,
      createdAtMillis: createdAt is Timestamp
          ? createdAt.millisecondsSinceEpoch
          : 0,
    );
  }
}

class LatLngPoint {
  const LatLngPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

Marker _marker({
  required LatLngPoint point,
  required IconData icon,
  required Color color,
}) {
  return Marker(
    point: latlng.LatLng(point.latitude, point.longitude),
    width: 36,
    height: 36,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

List<latlng.LatLng> _buildPolylinePoints(_TrackedOrder order) {
  final points = <latlng.LatLng>[];

  if (order.status == 'ordered') {
    if (order.driverPoint != null) {
      points.add(
        latlng.LatLng(
          order.driverPoint!.latitude,
          order.driverPoint!.longitude,
        ),
      );
    }
    if (order.pickupPoint != null) {
      points.add(
        latlng.LatLng(
          order.pickupPoint!.latitude,
          order.pickupPoint!.longitude,
        ),
      );
    }
    return points;
  }

  if (order.driverPoint != null) {
    points.add(
      latlng.LatLng(order.driverPoint!.latitude, order.driverPoint!.longitude),
    );
  }
  if (order.dropOffPoint != null) {
    points.add(
      latlng.LatLng(order.dropOffPoint!.latitude, order.dropOffPoint!.longitude),
    );
  }
  return points;
}

String _routeLabel(_TrackedOrder order) {
  if (order.driverPoint == null) {
    return 'Driver location appears here after the driver starts live tracking.';
  }
  if (order.status == 'ordered') {
    return 'Bold green path from driver to seller pickup location.';
  }
  return 'Bold green path from driver to buyer drop-off location.';
}

LatLngPoint? _readLatLng(Object? raw) {
  if (raw is GeoPoint) {
    final point = LatLngPoint(latitude: raw.latitude, longitude: raw.longitude);
    return _isInRiyadh(point) ? point : null;
  }

  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final geoPoint = map['geoPoint'];
  if (geoPoint is GeoPoint) {
    final point = LatLngPoint(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
    return _isInRiyadh(point) ? point : null;
  }

  final latitude = (map['latitude'] as num?)?.toDouble();
  final longitude = (map['longitude'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;

  final point = LatLngPoint(latitude: latitude, longitude: longitude);
  return _isInRiyadh(point) ? point : null;
}

bool _isInRiyadh(LatLngPoint point) {
  return point.latitude >= _riyadhMinLatitude &&
      point.latitude <= _riyadhMaxLatitude &&
      point.longitude >= _riyadhMinLongitude &&
      point.longitude <= _riyadhMaxLongitude;
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

  return '';
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

  return _readText(data, 'deliveryAddress');
}

String _readText(Map<String, dynamic> data, String key) {
  return (data[key] as String? ?? '').trim();
}

String _emptyMessage(String filter) {
  return switch (filter) {
    'ordered' => 'No ordered deliveries are available right now.',
    'all' => 'No active deliveries are available right now.',
    _ => 'No in-transit deliveries are available right now.',
  };
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

String _formatTimestamp(DateTime? timestamp) {
  if (timestamp == null) return 'just now';

  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.inSeconds < 60) {
    return '${difference.inSeconds.clamp(1, 59)} sec ago';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
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
