import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/components/shared_tracking_session_map.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/admin_order_service.dart';

class OrderTrackingMapScreen extends StatelessWidget {
  const OrderTrackingMapScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const PageHeaderTitle('Track Order')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load live tracking: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('This order could not be found.'));
          }

          final status = _normalizedStatus(data);
          final buyerPoint = _readBuyerPoint(data);
          final driverPoint = _readDriverPoint(data);
          final pickupPoint = _readPickupPoint(data);
          final routeTargetPoint = status == 'ordered' ? pickupPoint : buyerPoint;
          final routeTargetLabel = status == 'ordered'
              ? 'Seller pickup'
              : 'Buyer drop-off';
          final pickupAddress = _readPickupAddress(data);
          final deliveryAddress = _readDeliveryAddress(data);
          final lastUpdated = _readDriverLocationUpdatedAt(data);
          final assignedDriverId = (data['driverId'] as String? ?? '').trim();
          final assignedDriverName = (data['driverName'] as String? ?? '')
              .trim();
          final assignedDriverPhone =
              (data['driverPhoneNumber'] as String? ?? '').trim();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3B66),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${_statusLabel(status)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      driverPoint == null
                          ? 'Pickup and drop-off are shown below. Driver location appears when delivery starts.'
                          : 'You are watching the driver real GPS movement in the same shared delivery session.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SharedTrackingSessionMap(
                sessionId: orderId,
                pickupPoint: pickupPoint,
                buyerPoint: buyerPoint,
                initialDriverPoint: driverPoint,
                initialDriverUpdatedAt: lastUpdated,
                routeTargetPoint: routeTargetPoint,
                routeTargetLabel: routeTargetLabel,
                height: 360,
              ),
              const SizedBox(height: 16),
              _TrackingInfoCard(
                title: 'Shared session',
                value:
                    'Both buyer and driver are connected to live session ${orderId.substring(0, 6).toUpperCase()} based on this order ID.',
                icon: Icons.link_outlined,
              ),
              const SizedBox(height: 12),
              _TrackingInfoCard(
                title: 'Seller pickup address',
                value: pickupAddress.isEmpty
                    ? 'Pickup address not available'
                    : pickupAddress,
                icon: Icons.store_mall_directory_outlined,
              ),
              const SizedBox(height: 12),
              _TrackingInfoCard(
                title: 'Buyer drop-off address',
                value: deliveryAddress.isEmpty
                    ? 'Delivery address not available'
                    : deliveryAddress,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _TrackingInfoCard(
                title: 'Driver location',
                value: driverPoint == null
                    ? 'Waiting for the driver to begin live tracking.'
                    : 'Last updated ${_formatTimestamp(lastUpdated)}',
                icon: Icons.my_location_outlined,
              ),
              const SizedBox(height: 12),
              _AssignedDriverSection(
                driverAssigned: assignedDriverId.isNotEmpty,
                driverName: assignedDriverName,
                driverPhone: assignedDriverPhone,
              ),
              const SizedBox(height: 12),
              _TrackingInfoCard(
                title: 'Current status',
                value: _statusDescription(status),
                icon: Icons.route_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _normalizedStatus(Map<String, dynamic> data) {
    final raw = (data['status'] as String? ?? '').trim();
    if (raw.isEmpty) return 'ordered';
    final normalized = AdminOrderService.normalizeOrderStatus(raw);
    return normalized.isEmpty ? 'ordered' : normalized;
  }

  static latlng.LatLng? _readBuyerPoint(Map<String, dynamic> data) {
    return _readPointFromMap(data['buyerDeliveryLocation']) ??
        _readPointFromGeoPoint(data['deliveryGeoPoint']);
  }

  static latlng.LatLng? _readPickupPoint(Map<String, dynamic> data) {
    return _readPointFromMap(data['pickupAddress']) ??
        _readPointFromGeoPoint(data['pickupAddress']);
  }

  static latlng.LatLng? _readDriverPoint(Map<String, dynamic> data) {
    return _readPointFromMap(data['driverCurrentLocation']);
  }

  static latlng.LatLng? _readPointFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final geoPoint = map['geoPoint'];
    if (geoPoint is GeoPoint) {
      return latlng.LatLng(geoPoint.latitude, geoPoint.longitude);
    }

    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return latlng.LatLng(latitude, longitude);
  }

  static latlng.LatLng? _readPointFromGeoPoint(Object? raw) {
    if (raw is! GeoPoint) return null;
    return latlng.LatLng(raw.latitude, raw.longitude);
  }

  static String _readDeliveryAddress(Map<String, dynamic> data) {
    final deliveryLocation = data['buyerDeliveryLocation'];
    if (deliveryLocation is Map) {
      final deliveryMap = Map<String, dynamic>.from(deliveryLocation);
      final details = (deliveryMap['details'] as String? ?? '').trim();
      if (details.isNotEmpty) return details;
      final address = (deliveryMap['address'] as String? ?? '').trim();
      if (address.isNotEmpty) return address;
    }

    return (data['deliveryAddress'] as String? ?? '').trim();
  }

  static String _readPickupAddress(Map<String, dynamic> data) {
    final pickupLocationDetails =
        (data['pickupLocationDetails'] as String? ?? '').trim();
    if (pickupLocationDetails.isNotEmpty) {
      return pickupLocationDetails;
    }

    final pickupAddressText = (data['pickupAddressText'] as String? ?? '')
        .trim();
    if (pickupAddressText.isNotEmpty) {
      return pickupAddressText;
    }

    final pickupLocation = data['pickupAddress'];
    if (pickupLocation is Map) {
      final pickupMap = Map<String, dynamic>.from(pickupLocation);
      final details = (pickupMap['details'] as String? ?? '').trim();
      if (details.isNotEmpty) {
        return details;
      }
      final address = (pickupMap['address'] as String? ?? '').trim();
      if (address.isNotEmpty) {
        return address;
      }
    }

    return '';
  }

  static DateTime? _readDriverLocationUpdatedAt(Map<String, dynamic> data) {
    final timestamp = data['driverLocationUpdatedAt'];
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'ordered' => 'Ordered',
      'in transit' => 'In Transit',
      'delivered' => 'Delivered',
      _ => status,
    };
  }

  static String _statusDescription(String status) {
    return switch (status) {
      'ordered' => 'Your order is confirmed and waiting for delivery progress.',
      'in transit' =>
        'Your driver is on the way and this shared live session keeps both sides in sync.',
      'delivered' => 'This order has been delivered to the selected address.',
      _ => 'Tracking is available while this order is being delivered.',
    };
  }

  static String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return 'just now';
    }

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
}

class _TrackingInfoCard extends StatelessWidget {
  const _TrackingInfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E0EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F3B66)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedDriverSection extends StatelessWidget {
  const _AssignedDriverSection({
    required this.driverAssigned,
    required this.driverName,
    required this.driverPhone,
  });

  final bool driverAssigned;
  final String driverName;
  final String driverPhone;

  @override
  Widget build(BuildContext context) {
    if (!driverAssigned) {
      return const _TrackingInfoCard(
        title: 'Assigned driver',
        value: 'A driver has not been assigned to this order yet.',
        icon: Icons.person_outline,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E0EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5FC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF0F3B66),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned driver',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  driverName.isEmpty ? 'Assigned driver' : driverName,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      driverPhone.isEmpty
                          ? 'Phone number not available yet.'
                          : driverPhone,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
