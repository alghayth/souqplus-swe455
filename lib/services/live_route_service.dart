import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart' as latlng;

class LiveRouteSnapshot {
  const LiveRouteSnapshot({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.provider,
  });

  final List<latlng.LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final String provider;
}

class LiveRouteService {
  const LiveRouteService();

  static const String _routingBaseUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  Future<LiveRouteSnapshot> fetchDrivingRoute({
    required latlng.LatLng origin,
    required latlng.LatLng destination,
  }) async {
    final uri = Uri.parse(
      '$_routingBaseUrl/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?alternatives=false&overview=full&geometries=geojson&steps=false',
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Route lookup failed with status ${response.statusCode}.',
          uri: uri,
        );
      }

      final payload = jsonDecode(body);
      final routes = payload['routes'];
      if (routes is! List || routes.isEmpty) {
        throw const FormatException('Route service returned no routes.');
      }

      final route = Map<String, dynamic>.from(routes.first as Map);
      final geometry = Map<String, dynamic>.from(route['geometry'] as Map);
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) {
        throw const FormatException('Route geometry is missing coordinates.');
      }

      final polylinePoints = <latlng.LatLng>[];
      for (final point in coordinates) {
        if (point is! List || point.length < 2) continue;
        final longitude = (point[0] as num?)?.toDouble();
        final latitude = (point[1] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;
        polylinePoints.add(latlng.LatLng(latitude, longitude));
      }

      if (polylinePoints.length < 2) {
        throw const FormatException('Route geometry did not contain a path.');
      }

      return LiveRouteSnapshot(
        polylinePoints: polylinePoints,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
        provider: 'OSRM',
      );
    } finally {
      client.close(force: true);
    }
  }
}
