import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/admin_order_service.dart';

typedef GeoCoordinate = ({double latitude, double longitude});

// A driver who passed the eligibility checks for one order.
class DriverCandidate {
  const DriverCandidate({
    required this.id,
    required this.data,
    required this.distanceMeters,
    required this.activeOrders,
  });

  final String id;
  final Map<String, dynamic> data;
  final double distanceMeters;
  final int activeOrders;
}

// Holds the automatic driver-assignment logic (MR005) that was previously
// one long method inside AdminOrderService.
class DriverAssignmentService {
  const DriverAssignmentService(this._orderService);

  final AdminOrderService _orderService;

  static const double distanceWeight = 0.7;
  static const double workloadWeight = 0.3;
  static const int maxActiveOrdersPerDriver = 5;

  Future<String?> assignBestDriver({required String orderId}) async {
    final pickupPoint = await _loadPickupPoint(orderId);
    if (pickupPoint == null) return null;

    final candidates = await _loadEligibleCandidates(pickupPoint);
    if (candidates.isEmpty) {
      debugPrint('Assignment: no eligible driver for order $orderId');
      return null;
    }

    final (selected, score) = selectBestCandidate(candidates);
    await _saveAssignment(orderId: orderId, driver: selected, score: score);
    debugPrint(
      'Assignment: order $orderId -> ${selected.id} '
      'score=${score.toStringAsFixed(3)}',
    );
    return selected.id;
  }

  Future<GeoCoordinate?> _loadPickupPoint(String orderId) async {
    final orderSnapshot = await db.collection('orders').doc(orderId).get();
    final orderData = orderSnapshot.data();
    if (orderData == null) {
      debugPrint('Assignment: order $orderId not found');
      return null;
    }

    final pickupPoint = readCoordinate(orderData['pickupAddress']);
    if (pickupPoint == null) {
      debugPrint('Assignment: order $orderId has no pickup coordinates');
    }
    return pickupPoint;
  }

  Future<List<DriverCandidate>> _loadEligibleCandidates(
    GeoCoordinate pickupPoint,
  ) async {
    final driversSnapshot = await db.collection('drivers').get();
    final candidates = <DriverCandidate>[];

    for (final driverDoc in driversSnapshot.docs) {
      final candidate = await _toCandidate(driverDoc, pickupPoint);
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  Future<DriverCandidate?> _toCandidate(
    QueryDocumentSnapshot<Map<String, dynamic>> driverDoc,
    GeoCoordinate pickupPoint,
  ) async {
    final driverData = driverDoc.data();
    if (isBlocked(driverData)) {
      debugPrint('Assignment: skip ${driverDoc.id} (blocked)');
      return null;
    }

    final driverPoint = readCoordinate(driverData['lastKnownLocation']);
    if (driverPoint == null) {
      debugPrint('Assignment: skip ${driverDoc.id} (no location)');
      return null;
    }

    final activeOrders = await _orderService.activeAssignedOrderCountForDriver(
      driverId: driverDoc.id,
    );
    if (activeOrders >= maxActiveOrdersPerDriver) {
      debugPrint('Assignment: skip ${driverDoc.id} (full, $activeOrders)');
      return null;
    }

    return DriverCandidate(
      id: driverDoc.id,
      data: driverData,
      distanceMeters: Geolocator.distanceBetween(
        driverPoint.latitude,
        driverPoint.longitude,
        pickupPoint.latitude,
        pickupPoint.longitude,
      ),
      activeOrders: activeOrders,
    );
  }

  static (DriverCandidate, double) selectBestCandidate(
    List<DriverCandidate> candidates,
  ) {
    final maxDistance = candidates
        .map((candidate) => candidate.distanceMeters)
        .reduce((a, b) => a > b ? a : b);

    DriverCandidate? best;
    double bestScore = double.infinity;
    for (final candidate in candidates) {
      final score = scoreCandidate(candidate, maxDistance);
      debugPrint(
        'Assignment: candidate ${candidate.id} '
        'distance=${candidate.distanceMeters.toStringAsFixed(0)}m '
        'active=${candidate.activeOrders} '
        'score=${score.toStringAsFixed(3)}',
      );
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return (best!, bestScore);
  }

  static double scoreCandidate(DriverCandidate candidate, double maxDistance) {
    final normalizedDistance = maxDistance > 0
        ? candidate.distanceMeters / maxDistance
        : 0.0;
    final normalizedLoad = candidate.activeOrders / maxActiveOrdersPerDriver;
    return distanceWeight * normalizedDistance +
        workloadWeight * normalizedLoad;
  }

  Future<void> _saveAssignment({
    required String orderId,
    required DriverCandidate driver,
    required double score,
  }) async {
    await _orderService.assignDriverToOrder(
      orderId: orderId,
      driverId: driver.id,
      driverName: (driver.data['fullName'] as String? ?? '').trim(),
      driverEmail: (driver.data['email'] as String? ?? '').trim(),
      driverPhoneNumber:
          (driver.data['phoneNumber'] as String? ??
                  driver.data['phone'] as String? ??
                  '')
              .trim(),
    );
    await db.collection('orders').doc(orderId).update({
      'assignmentMethod': 'auto',
      'assignmentScore': score,
    });
  }

  // Same blocked rule as the admin orders screen.
  static bool isBlocked(Map<String, dynamic> driverData) {
    final status = (driverData['status'] as String? ?? '').trim().toLowerCase();
    return driverData['isBlocked'] == true ||
        driverData['blocked'] == true ||
        status == 'blocked' ||
        status == 'disabled';
  }

  // Reads a GeoPoint, or a map holding either 'geoPoint' or
  // 'latitude'/'longitude'. Replaces the two duplicated parsing blocks.
  static GeoCoordinate? readCoordinate(Object? raw) {
    if (raw is GeoPoint) {
      return (latitude: raw.latitude, longitude: raw.longitude);
    }
    if (raw is! Map) return null;

    final geoPoint = raw['geoPoint'];
    if (geoPoint is GeoPoint) {
      return (latitude: geoPoint.latitude, longitude: geoPoint.longitude);
    }

    final latitude = (raw['latitude'] as num?)?.toDouble();
    final longitude = (raw['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return (latitude: latitude, longitude: longitude);
  }
}
