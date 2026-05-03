import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:souqplus/services/admin_order_service.dart';
import 'package:souqplus/services/live_route_service.dart';

class SharedTrackingSessionMap extends StatefulWidget {
  const SharedTrackingSessionMap({
    super.key,
    required this.sessionId,
    required this.pickupPoint,
    required this.buyerPoint,
    required this.initialDriverPoint,
    required this.initialDriverUpdatedAt,
    required this.routeTargetPoint,
    required this.routeTargetLabel,
    this.height = 320,
  });

  final String sessionId;
  final latlng.LatLng? pickupPoint;
  final latlng.LatLng? buyerPoint;
  final latlng.LatLng? initialDriverPoint;
  final DateTime? initialDriverUpdatedAt;
  final latlng.LatLng? routeTargetPoint;
  final String routeTargetLabel;
  final double height;

  @override
  State<SharedTrackingSessionMap> createState() =>
      _SharedTrackingSessionMapState();
}

class _SharedTrackingSessionMapState extends State<SharedTrackingSessionMap>
    with SingleTickerProviderStateMixin {
  static const latlng.LatLng _defaultCenter = latlng.LatLng(24.7136, 46.6753);
  static const double _staleAfterSeconds = 20;
  static const double _weakGpsAccuracyMeters = 45;
  static const double _unavailableGpsAccuracyMeters = 80;

  final AdminOrderService _orderService = const AdminOrderService();
  final LiveRouteService _routeService = const LiveRouteService();
  final latlng.Distance _distance = const latlng.Distance();
  late final MapController _mapController;
  late final AnimationController _markerAnimationController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _trackingSubscription;

  List<_TrackingPointData> _trackingPoints = const <_TrackingPointData>[];
  LiveRouteSnapshot? _routeSnapshot;
  latlng.LatLng? _driverPoint;
  latlng.LatLng? _displayDriverPoint;
  double? _latestAccuracyMeters;
  double? _latestSpeedMetersPerSecond;
  int? _latestRecordedAtMs;
  String? _routeErrorMessage;
  bool _isRouteLoading = false;
  int _routeRequestId = 0;
  latlng.LatLng? _lastRouteOrigin;
  latlng.LatLng? _lastRouteDestination;
  DateTime? _lastRouteFetchedAt;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_handleMarkerAnimationTick);
    _driverPoint = widget.initialDriverPoint;
    _displayDriverPoint = widget.initialDriverPoint;
    _latestRecordedAtMs = widget.initialDriverUpdatedAt?.millisecondsSinceEpoch;
    _subscribeToSharedSession();
  }

  @override
  void didUpdateWidget(covariant SharedTrackingSessionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.sessionId != widget.sessionId;
    final fallbackDriverChanged =
        oldWidget.initialDriverPoint?.latitude !=
            widget.initialDriverPoint?.latitude ||
        oldWidget.initialDriverPoint?.longitude !=
            widget.initialDriverPoint?.longitude;
    final fallbackTimestampChanged =
        oldWidget.initialDriverUpdatedAt?.millisecondsSinceEpoch !=
        widget.initialDriverUpdatedAt?.millisecondsSinceEpoch;
    final destinationChanged =
        oldWidget.routeTargetPoint?.latitude !=
            widget.routeTargetPoint?.latitude ||
        oldWidget.routeTargetPoint?.longitude !=
            widget.routeTargetPoint?.longitude;

    if (fallbackDriverChanged || fallbackTimestampChanged) {
      final nextFallbackPoint = widget.initialDriverPoint;
      final nextFallbackRecordedAtMs =
          widget.initialDriverUpdatedAt?.millisecondsSinceEpoch;
      final previousLatestRecordedAtMs = _latestRecordedAtMs;
      _latestRecordedAtMs = nextFallbackRecordedAtMs ?? _latestRecordedAtMs;

      final fallbackIsNewer =
          nextFallbackRecordedAtMs != null &&
          (previousLatestRecordedAtMs == null ||
              nextFallbackRecordedAtMs >= previousLatestRecordedAtMs);

      if (nextFallbackPoint != null &&
          (_trackingPoints.isEmpty || fallbackIsNewer)) {
        _driverPoint = nextFallbackPoint;
        _animateDriverMarker(nextFallbackPoint);
        _moveCameraToDriver(nextFallbackPoint);
        if (mounted) {
          setState(() {
            _displayDriverPoint = _displayDriverPoint ?? nextFallbackPoint;
          });
        } else {
          _displayDriverPoint = _displayDriverPoint ?? nextFallbackPoint;
        }
        unawaited(_refreshRoadRoute());
      }
    }

    if (!sessionChanged && !destinationChanged) {
      return;
    }

    _trackingSubscription?.cancel();
    _trackingPoints = const <_TrackingPointData>[];
    _routeSnapshot = null;
    _routeErrorMessage = null;
    _driverPoint = widget.initialDriverPoint;
    _displayDriverPoint = widget.initialDriverPoint;
    _latestRecordedAtMs = widget.initialDriverUpdatedAt?.millisecondsSinceEpoch;
    _lastRouteOrigin = null;
    _lastRouteDestination = null;
    _lastRouteFetchedAt = null;
    _subscribeToSharedSession();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _markerAnimationController
      ..removeListener(_handleMarkerAnimationTick)
      ..dispose();
    super.dispose();
  }

  void _subscribeToSharedSession() {
    _trackingSubscription = _orderService
        .orderTrackingPointsStream(orderId: widget.sessionId)
        .listen((snapshot) {
          final nextTrackingPoints = _readTrackingPoints(snapshot.docs);
          final latestPoint = nextTrackingPoints.isNotEmpty
              ? nextTrackingPoints.last
              : null;
          final nextDriverPoint = latestPoint?.point ?? widget.initialDriverPoint;
          final nextRecordedAtMs =
              latestPoint?.recordedAtMs ??
              widget.initialDriverUpdatedAt?.millisecondsSinceEpoch;

          if (!mounted) {
            _trackingPoints = nextTrackingPoints;
            _driverPoint = nextDriverPoint;
            _displayDriverPoint = nextDriverPoint ?? _displayDriverPoint;
            _latestAccuracyMeters = latestPoint?.accuracyMeters;
            _latestSpeedMetersPerSecond = latestPoint?.speedMetersPerSecond;
            _latestRecordedAtMs = nextRecordedAtMs;
            return;
          }

          setState(() {
            _trackingPoints = nextTrackingPoints;
            _driverPoint = nextDriverPoint;
            _latestAccuracyMeters = latestPoint?.accuracyMeters;
            _latestSpeedMetersPerSecond = latestPoint?.speedMetersPerSecond;
            _latestRecordedAtMs = nextRecordedAtMs;
            if (_displayDriverPoint == null && nextDriverPoint != null) {
              _displayDriverPoint = nextDriverPoint;
            }
          });

          if (nextDriverPoint != null) {
            debugPrint(
              'Frontend: Received location session=${widget.sessionId} '
              'lat=${nextDriverPoint.latitude}, lng=${nextDriverPoint.longitude} '
              'trailPoints=${nextTrackingPoints.length}',
            );
            _animateDriverMarker(nextDriverPoint);
            _moveCameraToDriver(nextDriverPoint);
          }

          unawaited(_refreshRoadRoute());
        });
  }

  void _handleMarkerAnimationTick() {
    final targetPoint = _driverPoint;
    if (targetPoint == null || _displayDriverPoint == null) {
      return;
    }

    final startPoint = _animationStartPoint ?? _displayDriverPoint!;
    final progress = Curves.linear.transform(_markerAnimationController.value);
    final animatedPoint = _interpolateLatLng(startPoint, targetPoint, progress);
    if (!mounted) {
      _displayDriverPoint = animatedPoint;
      return;
    }

    setState(() {
      _displayDriverPoint = animatedPoint;
    });
  }

  latlng.LatLng? _animationStartPoint;

  void _animateDriverMarker(latlng.LatLng nextDriverPoint) {
    final currentPoint = _displayDriverPoint;
    if (currentPoint == null) {
      setState(() => _displayDriverPoint = nextDriverPoint);
      return;
    }

    final meters = _distanceBetween(currentPoint, nextDriverPoint);
    if (meters < 1) {
      setState(() => _displayDriverPoint = nextDriverPoint);
      return;
    }

    _animationStartPoint = currentPoint;
    final durationMs = math.max(700, math.min(2200, (meters * 45).round()));
    _markerAnimationController.duration = Duration(milliseconds: durationMs);
    _markerAnimationController.forward(from: 0);
  }

  void _moveCameraToDriver(latlng.LatLng nextDriverPoint) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(nextDriverPoint, 15);
      debugPrint(
        'UI: Map updated successfully session=${widget.sessionId} '
        'lat=${nextDriverPoint.latitude}, lng=${nextDriverPoint.longitude}',
      );
    });
  }

  Future<void> _refreshRoadRoute() async {
    final origin = _driverPoint;
    final destination = widget.routeTargetPoint;
    if (origin == null || destination == null || _isLocationUnavailable) {
      if (mounted && (_routeSnapshot != null || _routeErrorMessage != null)) {
        setState(() {
          _routeSnapshot = null;
          _routeErrorMessage = null;
          _isRouteLoading = false;
        });
      } else {
        _routeSnapshot = null;
        _routeErrorMessage = null;
        _isRouteLoading = false;
      }
      return;
    }

    final enoughTimePassed =
        _lastRouteFetchedAt == null ||
        DateTime.now().difference(_lastRouteFetchedAt!).inSeconds >= 5;
    final originMovedEnough =
        _lastRouteOrigin == null ||
        _distanceBetween(_lastRouteOrigin!, origin) >= 12;
    final destinationChanged =
        _lastRouteDestination == null ||
        _distanceBetween(_lastRouteDestination!, destination) >= 3;

    if (!enoughTimePassed && !originMovedEnough && !destinationChanged) {
      return;
    }

    final requestId = ++_routeRequestId;
    if (mounted) {
      setState(() => _isRouteLoading = true);
    } else {
      _isRouteLoading = true;
    }

    try {
      final route = await _routeService.fetchDrivingRoute(
        origin: origin,
        destination: destination,
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeSnapshot = route;
        _routeErrorMessage = null;
        _isRouteLoading = false;
        _lastRouteFetchedAt = DateTime.now();
        _lastRouteOrigin = origin;
        _lastRouteDestination = destination;
      });
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeErrorMessage = 'Live road route is temporarily unavailable.';
        _routeSnapshot = null;
        _isRouteLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center =
        _displayDriverPoint ??
        _driverPoint ??
        widget.buyerPoint ??
        widget.pickupPoint ??
        _defaultCenter;

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
              _TrackingLegendChip(
                emoji: '🏍️',
                label: 'Driver Live',
                color: Color(0xFF16A34A),
              ),
              _TrackingLegendChip(
                emoji: '🏪',
                label: 'Seller Pickup',
                color: Color(0xFFF59E0B),
              ),
              _TrackingLegendChip(
                emoji: '🏠',
                label: 'Buyer Drop-off',
                color: Color(0xFF1D4ED8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: widget.height,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.souqplus',
                  ),
                  PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TrackingStatusBanner(
            label: _trackingStatusLabel,
            message: _trackingStatusMessage,
            color: _trackingStatusColor,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Route',
                value: widget.routeTargetLabel,
                color: const Color(0xFF0F3B66),
              ),
              _MetricChip(
                label: 'Distance',
                value: _routeSnapshot == null
                    ? '--'
                    : _formatDistance(_routeSnapshot!.distanceMeters),
                color: const Color(0xFF1D4ED8),
              ),
              _MetricChip(
                label: 'ETA',
                value: _routeSnapshot == null
                    ? '--'
                    : _formatEta(_routeSnapshot!.durationSeconds),
                color: const Color(0xFF16A34A),
              ),
              _MetricChip(
                label: 'Speed',
                value: _latestSpeedMetersPerSecond == null
                    ? '--'
                    : _formatSpeed(_latestSpeedMetersPerSecond!),
                color: const Color(0xFFB45309),
              ),
            ],
          ),
          if (_isRouteLoading) ...[
            const SizedBox(height: 10),
            const Text(
              'Refreshing the live road route...',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (_routeErrorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _routeErrorMessage!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return <Marker>[
      if (widget.pickupPoint != null)
        _buildMarker(
          point: widget.pickupPoint!,
          emoji: '🏪',
          color: const Color(0xFFF59E0B),
        ),
      if (widget.buyerPoint != null)
        _buildMarker(
          point: widget.buyerPoint!,
          emoji: '🏠',
          color: const Color(0xFF1D4ED8),
        ),
      if ((_displayDriverPoint ?? _driverPoint) != null)
        _buildMarker(
          point: _displayDriverPoint ?? _driverPoint!,
          emoji: '🏍️',
          color: const Color(0xFF16A34A),
        ),
    ];
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];
    final traveledPoints = _trackingPoints.map((point) => point.point).toList();
    if (traveledPoints.length >= 2) {
      polylines.add(
        Polyline(
          points: traveledPoints,
          color: const Color(0x6616A34A),
          strokeWidth: 4,
        ),
      );
    }

    if (_routeSnapshot != null && _routeSnapshot!.polylinePoints.length >= 2) {
      polylines.add(
        Polyline(
          points: _routeSnapshot!.polylinePoints,
          color: const Color(0xAA16A34A),
          strokeWidth: 10,
        ),
      );
      polylines.add(
        Polyline(
          points: _routeSnapshot!.polylinePoints,
          color: const Color(0xFF16A34A),
          strokeWidth: 6,
        ),
      );
    }

    return polylines;
  }

  List<_TrackingPointData> _readTrackingPoints(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final points = <_TrackingPointData>[];
    for (final doc in docs) {
      final point = _readTrackingPoint(doc.data());
      if (point == null) continue;
      if (points.isEmpty || _distanceBetween(points.last.point, point.point) >= 1) {
        points.add(point);
      } else {
        points[points.length - 1] = point;
      }
    }
    return points;
  }

  _TrackingPointData? _readTrackingPoint(Map<String, dynamic> data) {
    final geoPoint = data['geoPoint'];
    latlng.LatLng? point;
    if (geoPoint is GeoPoint) {
      point = latlng.LatLng(geoPoint.latitude, geoPoint.longitude);
    } else {
      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }
      point = latlng.LatLng(latitude, longitude);
    }

    return _TrackingPointData(
      point: point,
      recordedAtMs: (data['recordedAtMs'] as num?)?.toInt(),
      accuracyMeters: (data['accuracy'] as num?)?.toDouble(),
      speedMetersPerSecond: (data['speed'] as num?)?.toDouble(),
    );
  }

  bool get _isLocationUnavailable {
    if (_driverPoint == null || _latestRecordedAtMs == null) return true;
    final ageSeconds =
        (DateTime.now().millisecondsSinceEpoch - _latestRecordedAtMs!) / 1000;
    if (ageSeconds > _staleAfterSeconds) return true;
    if (_latestAccuracyMeters != null &&
        _latestAccuracyMeters! > _unavailableGpsAccuracyMeters) {
      return true;
    }
    return false;
  }

  bool get _isWeakGpsSignal {
    if (_isLocationUnavailable) return false;
    return _latestAccuracyMeters != null &&
        _latestAccuracyMeters! > _weakGpsAccuracyMeters;
  }

  String get _trackingStatusLabel {
    if (_isLocationUnavailable) return 'Location unavailable';
    if (_isWeakGpsSignal) return 'Weak GPS signal';
    return 'Live GPS tracking';
  }

  String get _trackingStatusMessage {
    if (_driverPoint == null) {
      return 'Waiting for the driver device to send real GPS coordinates.';
    }
    if (_latestRecordedAtMs == null) {
      return 'Live GPS updates have not started yet.';
    }
    final ageSeconds =
        (DateTime.now().millisecondsSinceEpoch - _latestRecordedAtMs!) / 1000;
    if (ageSeconds > _staleAfterSeconds) {
      return 'No fresh GPS signal was received recently. Showing the last known position.';
    }
    if (_latestAccuracyMeters != null &&
        _latestAccuracyMeters! > _unavailableGpsAccuracyMeters) {
      return 'GPS accuracy is too weak right now, so movement is paused until a reliable signal returns.';
    }
    if (_isWeakGpsSignal) {
      return 'GPS signal is weak, so location precision may be reduced for a moment.';
    }
    return 'This map is updating from the delivery person phone in real time.';
  }

  Color get _trackingStatusColor {
    if (_isLocationUnavailable) return const Color(0xFFB91C1C);
    if (_isWeakGpsSignal) return const Color(0xFFB45309);
    return const Color(0xFF166534);
  }

  double _distanceBetween(latlng.LatLng a, latlng.LatLng b) {
    return _distance.as(latlng.LengthUnit.Meter, a, b);
  }

  latlng.LatLng _interpolateLatLng(
    latlng.LatLng start,
    latlng.LatLng end,
    double t,
  ) {
    return latlng.LatLng(
      start.latitude + ((end.latitude - start.latitude) * t),
      start.longitude + ((end.longitude - start.longitude) * t),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatEta(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '$hours hr'
        : '$hours hr $remainingMinutes min';
  }

  String _formatSpeed(double speedMetersPerSecond) {
    final speedKmh = speedMetersPerSecond * 3.6;
    if (speedKmh <= 0.5) return 'Stopped';
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }

  Marker _buildMarker({
    required latlng.LatLng point,
    required String emoji,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 38,
      height: 38,
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
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _TrackingPointData {
  const _TrackingPointData({
    required this.point,
    required this.recordedAtMs,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
  });

  final latlng.LatLng point;
  final int? recordedAtMs;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
}

class _TrackingLegendChip extends StatelessWidget {
  const _TrackingLegendChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
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
          Text(emoji, style: const TextStyle(fontSize: 15)),
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

class _TrackingStatusBanner extends StatelessWidget {
  const _TrackingStatusBanner({
    required this.label,
    required this.message,
    required this.color,
  });

  final String label;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
