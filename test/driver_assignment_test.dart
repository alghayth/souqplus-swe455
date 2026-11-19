import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/services/driver_assignment_service.dart';

DriverCandidate _driver(String id, double distanceMeters, int activeOrders) {
  return DriverCandidate(
    id: id,
    data: {'name': id},
    distanceMeters: distanceMeters,
    activeOrders: activeOrders,
  );
}

void main() {
  group('MR005 driver assignment', () {
    // Run used for the dynamic backward slice:
    //   D1 is the nearest driver but already has 4 active orders.
    //   D2 is free but the farthest.
    //   D3 is in between with 1 active order.
    test('selects the driver with the lowest weighted score', () {
      final candidates = [
        _driver('D1', 800, 4),
        _driver('D2', 2000, 0),
        _driver('D3', 1200, 1),
      ];

      final (selected, score) = DriverAssignmentService.selectBestCandidate(
        candidates,
      );

      expect(selected.id, 'D3');
      expect(score, closeTo(0.48, 0.0001));
    });

    test('computes the expected score for each driver', () {
      const maxDistance = 2000.0;
      expect(
        DriverAssignmentService.scoreCandidate(
          _driver('D1', 800, 4),
          maxDistance,
        ),
        closeTo(0.52, 0.0001),
      );
      expect(
        DriverAssignmentService.scoreCandidate(
          _driver('D2', 2000, 0),
          maxDistance,
        ),
        closeTo(0.70, 0.0001),
      );
      expect(
        DriverAssignmentService.scoreCandidate(
          _driver('D3', 1200, 1),
          maxDistance,
        ),
        closeTo(0.48, 0.0001),
      );
    });

    test('uses workload only when all drivers are at the pickup point', () {
      final (selected, _) = DriverAssignmentService.selectBestCandidate([
        _driver('busy', 0, 3),
        _driver('free', 0, 0),
      ]);
      expect(selected.id, 'free');
    });

    test('reads coordinates from every supported format', () {
      final fromGeoPoint = DriverAssignmentService.readCoordinate(
        const GeoPoint(24.7, 46.6),
      );
      final fromNestedGeoPoint = DriverAssignmentService.readCoordinate({
        'geoPoint': const GeoPoint(24.7, 46.6),
      });
      final fromLatLng = DriverAssignmentService.readCoordinate({
        'latitude': 24.7,
        'longitude': 46.6,
      });

      for (final point in [fromGeoPoint, fromNestedGeoPoint, fromLatLng]) {
        expect(point, isNotNull);
        expect(point!.latitude, 24.7);
        expect(point.longitude, 46.6);
      }
      expect(DriverAssignmentService.readCoordinate(null), isNull);
      expect(
        DriverAssignmentService.readCoordinate({'latitude': 24.7}),
        isNull,
      );
    });
  });
}