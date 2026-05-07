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
  static const String _googleDirectionsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_DIRECTIONS_API_KEY',
  );

  Future<LiveRouteSnapshot> fetchDrivingRoute({
    required latlng.LatLng origin,
    required latlng.LatLng destination,
  }) async {
    return fetchDrivingRouteThrough(points: [origin, destination]);
  }

  Future<LiveRouteSnapshot> fetchDrivingRouteThrough({
    required List<latlng.LatLng> points,
  }) async {
    if (points.length < 2) {
      throw const FormatException('At least two route points are required.');
    }

    if (_googleDirectionsApiKey.trim().isNotEmpty) {
      try {
        return await _fetchGoogleDrivingRouteThrough(points);
      } catch (_) {
        // Keep live tracking usable when Google Directions is temporarily unavailable.
      }
    }

    return _fetchOsrmDrivingRouteThrough(points);
  }

  Future<LiveRouteSnapshot> _fetchOsrmDrivingRouteThrough(
    List<latlng.LatLng> points,
  ) async {
    final coordinates = points
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.parse(
      '$_routingBaseUrl/route/v1/driving/$coordinates'
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

  Future<LiveRouteSnapshot> _fetchGoogleDrivingRouteThrough(
    List<latlng.LatLng> points,
  ) async {
    final waypointPoints = points.length <= 2
        ? const <latlng.LatLng>[]
        : points.sublist(1, points.length - 1);
    final queryParameters = <String, String>{
      'origin': _googlePoint(points.first),
      'destination': _googlePoint(points.last),
      'mode': 'driving',
      'key': _googleDirectionsApiKey,
      if (waypointPoints.isNotEmpty)
        'waypoints': waypointPoints.map(_googlePoint).join('|'),
    };
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      queryParameters,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Google Directions failed with status ${response.statusCode}.',
          uri: uri,
        );
      }

      final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final status = (payload['status'] as String? ?? '').trim();
      if (status != 'OK') {
        throw FormatException(
          'Google Directions returned ${status.isEmpty ? 'no status' : status}.',
        );
      }

      final routes = payload['routes'];
      if (routes is! List || routes.isEmpty) {
        throw const FormatException('Google Directions returned no routes.');
      }

      final route = Map<String, dynamic>.from(routes.first as Map);
      final overviewPolyline = Map<String, dynamic>.from(
        route['overview_polyline'] as Map,
      );
      final encodedPolyline =
          (overviewPolyline['points'] as String? ?? '').trim();
      final polylinePoints = _decodeGooglePolyline(encodedPolyline);
      if (polylinePoints.length < 2) {
        throw const FormatException(
          'Google Directions route did not contain a path.',
        );
      }

      return LiveRouteSnapshot(
        polylinePoints: polylinePoints,
        distanceMeters: _sumGoogleLegValue(route['legs'], 'distance'),
        durationSeconds: _sumGoogleLegValue(route['legs'], 'duration'),
        provider: 'Google Directions',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _googlePoint(latlng.LatLng point) {
    return '${point.latitude},${point.longitude}';
  }

  static double _sumGoogleLegValue(Object? legs, String field) {
    if (legs is! List) return 0;
    var total = 0.0;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final fieldValue = leg[field];
      if (fieldValue is! Map) continue;
      final value = (fieldValue['value'] as num?)?.toDouble();
      if (value != null) total += value;
    }
    return total;
  }

  static List<latlng.LatLng> _decodeGooglePolyline(String encoded) {
    if (encoded.isEmpty) return const <latlng.LatLng>[];

    final points = <latlng.LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      final latitudeResult = _decodePolylineValue(encoded, index);
      index = latitudeResult.nextIndex;
      latitude += latitudeResult.value;

      if (index >= encoded.length) break;

      final longitudeResult = _decodePolylineValue(encoded, index);
      index = longitudeResult.nextIndex;
      longitude += longitudeResult.value;

      points.add(latlng.LatLng(latitude / 100000, longitude / 100000));
    }

    return points;
  }

  static _PolylineValue _decodePolylineValue(String encoded, int startIndex) {
    var index = startIndex;
    var result = 0;
    var shift = 0;
    var byte = 0;

    do {
      if (index >= encoded.length) {
        throw const FormatException('Encoded polyline ended unexpectedly.');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final value = (result & 1) == 1 ? ~(result >> 1) : result >> 1;
    return _PolylineValue(value: value, nextIndex: index);
  }
}

class _PolylineValue {
  const _PolylineValue({required this.value, required this.nextIndex});

  final int value;
  final int nextIndex;
}
