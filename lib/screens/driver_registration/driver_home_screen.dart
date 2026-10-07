// ignore_for_file: file_names, unused_element

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/components/shared_tracking_session_map.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';
import 'package:souqplus/services/admin_order_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHomeScreen extends StatefulWidget {
  static String routeName = "/driver_home";

  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  static const double _maxReliableGpsAccuracyMeters = 80;

  final AdminOrderService _orderService = const AdminOrderService();
  bool _isLoggingOut = false;
  final Set<String> _startedOrderIds = <String>{};
  StreamSubscription<Position>? _positionSubscription;
  Set<String> _trackedOrderIds = <String>{};
  final Map<String, List<LatLngPoint>> _trackingTrailByOrderId =
      <String, List<LatLngPoint>>{};
  Position? _lastSyncedPosition;
  Position? _liveDriverPosition;
  DateTime? _lastLocationSyncAt;
  Position? _lastTrailSamplePosition;
  DateTime? _lastTrailSampleAt;
  bool _isTrackingLocation = false;
  bool _locationPermissionDenied = false;
  String _selectedDeliveryFilter = 'ordered';

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully.')));
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(SignInScreen.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _scheduleTrackingSync(Set<String> activeOrderIds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTrackingForOrders(activeOrderIds);
    });
  }

  Future<void> _syncTrackingForOrders(Set<String> activeOrderIds) async {
    if (_setsEqual(activeOrderIds, _trackedOrderIds)) {
      return;
    }

    _trackedOrderIds = activeOrderIds;

    if (_trackedOrderIds.isEmpty) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      if (mounted) {
        setState(() {
          _isTrackingLocation = false;
          _trackingTrailByOrderId.clear();
        });
      }
      return;
    }

    _trackingTrailByOrderId.removeWhere(
      (orderId, _) => !_trackedOrderIds.contains(orderId),
    );

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _isTrackingLocation = false;
          _locationPermissionDenied = true;
        });
      }
      return;
    }

    _locationPermissionDenied = false;
    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          ),
        ).listen((position) {
          _publishDriverLocation(position);
        });

    if (mounted) {
      setState(() => _isTrackingLocation = true);
    }

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _publishDriverLocation(currentPosition, force: true);
    } catch (_) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        await _publishDriverLocation(lastKnownPosition, force: true);
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _publishDriverLocation(
    Position position, {
    bool force = false,
  }) async {
    if (_trackedOrderIds.isEmpty) return;

    if (!force &&
        position.accuracy.isFinite &&
        position.accuracy > _maxReliableGpsAccuracyMeters) {
      debugPrint(
        'Backend: Skipped unreliable GPS point accuracy=${position.accuracy}m',
      );
      return;
    }

    if (mounted) {
      setState(() => _liveDriverPosition = position);
    } else {
      _liveDriverPosition = position;
    }

    final now = DateTime.now();
    if (!force && _lastSyncedPosition != null && _lastLocationSyncAt != null) {
      final distance = Geolocator.distanceBetween(
        _lastSyncedPosition!.latitude,
        _lastSyncedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final secondsSinceLastSync = now
          .difference(_lastLocationSyncAt!)
          .inSeconds;
      if (distance < 3 && secondsSinceLastSync < 3) {
        return;
      }
    }

    _appendLiveTrailPoint(position);

    try {
      await _orderService.updateDriverLiveLocation(
        orderIds: _trackedOrderIds.toList(),
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _appendRemoteTrailPoint(position, now, force: force);
      _lastSyncedPosition = position;
      _lastLocationSyncAt = now;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyUpdateErrorMessage(error))),
      );
    }
  }

  void _appendLiveTrailPoint(Position position) {
    final nextPoint = _positionToLatLng(position);
    if (nextPoint == null) return;

    final updatedTrailByOrderId = <String, List<LatLngPoint>>{};
    for (final orderId in _trackedOrderIds) {
      final existingTrail = List<LatLngPoint>.from(
        _trackingTrailByOrderId[orderId] ?? const <LatLngPoint>[],
      );
      if (existingTrail.isEmpty ||
          _distanceBetweenPoints(existingTrail.last, nextPoint) >= 1.5) {
        existingTrail.add(nextPoint);
      } else {
        existingTrail[existingTrail.length - 1] = nextPoint;
      }

      if (existingTrail.length > 250) {
        existingTrail.removeRange(0, existingTrail.length - 250);
      }
      updatedTrailByOrderId[orderId] = existingTrail;
    }

    if (mounted) {
      setState(() {
        _trackingTrailByOrderId
          ..clear()
          ..addAll(updatedTrailByOrderId);
      });
    } else {
      _trackingTrailByOrderId
        ..clear()
        ..addAll(updatedTrailByOrderId);
    }
  }

  Future<void> _appendRemoteTrailPoint(
    Position position,
    DateTime now, {
    required bool force,
  }) async {
    if (!force &&
        _lastTrailSamplePosition != null &&
        _lastTrailSampleAt != null) {
      final distance = Geolocator.distanceBetween(
        _lastTrailSamplePosition!.latitude,
        _lastTrailSamplePosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsedSeconds = now.difference(_lastTrailSampleAt!).inSeconds;
      if (distance < 5 && elapsedSeconds < 4) {
        return;
      }
    }

    await _orderService.appendDriverTrackingPoints(
      orderIds: _trackedOrderIds.toList(),
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAtMs: now.millisecondsSinceEpoch,
      heading: position.heading.isFinite ? position.heading : null,
      speed: position.speed.isFinite ? position.speed : null,
      accuracy: position.accuracy.isFinite ? position.accuracy : null,
    );
    _lastTrailSamplePosition = position;
    _lastTrailSampleAt = now;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final driverUid = currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6D2),
      appBar: AppBar(
        title: const PageHeaderTitle('Driver Dashboard'),
        actions: [
          IconButton(
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _isLoggingOut ? null : _confirmLogout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: driverUid.isEmpty
            ? null
            : _orderService.driverOrdersStream(driverId: driverUid),
        builder: (context, snapshot) {
          if (driverUid.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Driver session is not available. Please sign in again.',
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load deliveries: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignedDocs = snapshot.data?.docs ?? const [];
          final orderedDocs =
              assignedDocs.where((doc) {
                final status = AdminOrderService.normalizeOrderStatus(
                  (doc.data()['status'] as String? ?? ''),
                );
                return status == 'ordered';
              }).toList()..sort(
                (a, b) => _compareByCreatedAtDescending(a.data(), b.data()),
              );
          final inTransitDocs =
              assignedDocs.where((doc) {
                final status = AdminOrderService.normalizeOrderStatus(
                  (doc.data()['status'] as String? ?? ''),
                );
                return status == 'in transit';
              }).toList()..sort(
                (a, b) => _compareByCreatedAtDescending(a.data(), b.data()),
              );
          final activeDocs = [...orderedDocs, ...inTransitDocs];
          final completedDocs =
              assignedDocs.where((doc) {
                final status = AdminOrderService.normalizeOrderStatus(
                  (doc.data()['status'] as String? ?? ''),
                );
                return status == 'delivered';
              }).toList()..sort(
                (a, b) => _compareByCreatedAtDescending(a.data(), b.data()),
              );
          final selectedDocs = switch (_selectedDeliveryFilter) {
            'in transit' => inTransitDocs,
            'completed' => completedDocs,
            _ => orderedDocs,
          };
          _scheduleTrackingSync(activeDocs.map((doc) => doc.id).toSet());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDashboardCard(
                activeCount: activeDocs.length,
                deliveredCount: completedDocs.length,
              ),
              if (_locationPermissionDenied) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: const Text(
                    'Enable device location permission so buyers can track their deliveries on the map in real time.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (_isTrackingLocation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: const Row(
                    children: [
                      Icon(Icons.my_location, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Live location sharing is active for your assigned deliveries.',
                          style: TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'My Deliveries',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Showing deliveries assigned to your driver account.',
                style: TextStyle(color: Color(0xFF6B7C93)),
              ),
              const SizedBox(height: 12),
              _DriverDeliveryFilter(
                selectedFilter: _selectedDeliveryFilter,
                orderedCount: orderedDocs.length,
                inTransitCount: inTransitDocs.length,
                completedCount: completedDocs.length,
                onChanged: (filter) =>
                    setState(() => _selectedDeliveryFilter = filter),
              ),
              const SizedBox(height: 12),
              if (selectedDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Text(
                    _emptyDeliveriesMessage(_selectedDeliveryFilter),
                    style: const TextStyle(color: Color(0xFF6B7C93)),
                  ),
                )
              else
                ...selectedDocs.map((doc) {
                  final data = doc.data();
                  final status = AdminOrderService.normalizeOrderStatus(
                    (data['status'] as String? ?? ''),
                  );
                  final buyerName = _readText(data, 'buyerName');
                  final isCompleted = status == 'delivered';
                  final isStarted =
                      status != 'ordered' || _startedOrderIds.contains(doc.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                    buyerName.isEmpty
                                        ? 'Unknown buyer'
                                        : buyerName,
                                    style: const TextStyle(
                                      color: kTextColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order #${doc.id.substring(0, 6).toUpperCase()}',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7C93),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Open order info for delivery details.',
                                    style: TextStyle(color: Color(0xFF6B7C93)),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.info_outline),
                                label: const Text('View Info'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimaryColor,
                                  side: const BorderSide(color: kPrimaryColor),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _DriverOrderInfoScreen(
                                        orderId: doc.id,
                                        initialOrderData: data,
                                        orderService: _orderService,
                                        fallbackDriverPoint:
                                            _positionToLatLng(
                                              _liveDriverPosition,
                                            ) ??
                                            _positionToLatLng(
                                              _lastSyncedPosition,
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (!isCompleted) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(isStarted ? 'Started' : 'Start'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isStarted
                                        ? const Color(0xFF9CA3AF)
                                        : Colors.orange,
                                    disabledBackgroundColor: const Color(
                                      0xFF9CA3AF,
                                    ),
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: isStarted
                                      ? null
                                      : () {
                                          setState(
                                            () => _startedOrderIds.add(doc.id),
                                          );
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _DriverOrderInfoScreen(
                                                    orderId: doc.id,
                                                    initialOrderData: data,
                                                    orderService: _orderService,
                                                    fallbackDriverPoint:
                                                        _positionToLatLng(
                                                          _liveDriverPosition,
                                                        ) ??
                                                        _positionToLatLng(
                                                          _lastSyncedPosition,
                                                        ),
                                                  ),
                                            ),
                                          );
                                        },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard({
    required int activeCount,
    required int deliveredCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor.withAlpha(200)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DashboardStat(title: 'Active', value: '$activeCount'),
              _DashboardStat(title: 'Delivered', value: '$deliveredCount'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Use View Info for pickup, drop-off, contact, map, and delivery actions.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ordered' => Colors.orange,
      'in transit' => Colors.blue,
      'delivered' => Colors.green,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _prettyLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
        Icon(icon, color: kSecondaryColor),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverDeliveryFilter extends StatelessWidget {
  const _DriverDeliveryFilter({
    required this.selectedFilter,
    required this.orderedCount,
    required this.inTransitCount,
    required this.completedCount,
    required this.onChanged,
  });

  final String selectedFilter;
  final int orderedCount;
  final int inTransitCount;
  final int completedCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterButton(
          label: 'Ordered',
          count: orderedCount,
          selected: selectedFilter == 'ordered',
          onTap: () => onChanged('ordered'),
        ),
        const SizedBox(width: 8),
        _FilterButton(
          label: 'In Transit',
          count: inTransitCount,
          selected: selectedFilter == 'in transit',
          onTap: () => onChanged('in transit'),
        ),
        const SizedBox(width: 8),
        _FilterButton(
          label: 'Completed',
          count: completedCount,
          selected: selectedFilter == 'completed',
          onTap: () => onChanged('completed'),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? kSecondaryColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kSecondaryColor : const Color(0xFFD8E3EE),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$label ($count)',
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : kTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _DriverOrderInfoScreen extends StatefulWidget {
  const _DriverOrderInfoScreen({
    required this.orderId,
    required this.initialOrderData,
    required this.orderService,
    required this.fallbackDriverPoint,
  });

  final String orderId;
  final Map<String, dynamic> initialOrderData;
  final AdminOrderService orderService;
  final LatLngPoint? fallbackDriverPoint;

  @override
  State<_DriverOrderInfoScreen> createState() => _DriverOrderInfoScreenState();
}

class _DriverOrderInfoScreenState extends State<_DriverOrderInfoScreen> {
  bool _isUpdatingStatus = false;
  String? _statusOverride;

  Future<void> _confirmMarkDelivered() async {
    final shouldMarkDelivered = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Delivered'),
        content: const Text(
          'Are you sure this order has been delivered to the buyer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Mark Delivered',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (shouldMarkDelivered == true) {
      await _updateOrderStatus('delivered');
    }
  }

  Future<void> _updateOrderStatus(String nextStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.orderService.updateOrderField(
        orderId: widget.orderId,
        field: 'status',
        value: nextStatus,
      );
      if (!mounted) return;
      setState(() => _statusOverride = nextStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery updated to ${_prettyLabel(nextStatus)}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyUpdateErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _openNavigation({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open navigation to the $label.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.initialOrderData;
    if (data.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDF6D2),
        appBar: AppBar(title: const PageHeaderTitle('Order Info')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This order is no longer available.'),
          ),
        ),
      );
    }

    final status =
        _statusOverride ??
        AdminOrderService.normalizeOrderStatus(
          (data['status'] as String? ?? ''),
        );
    final pickupAddress = _pickupAddress(data);
    final dropOffAddress = _dropOffAddress(data);
    final buyerPhone = _readText(data, 'buyerPhoneNumber');
    final buyerEmail = _readText(data, 'buyerEmail');
    final pickupPoint = _readLatLng(data['pickupAddress']);
    final dropOffPoint =
        _readLatLng(data['buyerDeliveryLocation']) ??
        _readLatLng(data['deliveryGeoPoint']);
    final driverPoint =
        _readLatLng(data['driverCurrentLocation']) ??
        widget.fallbackDriverPoint;
    final driverUpdatedAt = _readTimestamp(data['driverLocationUpdatedAt']);
    final routeTargetPoint = status == 'ordered' ? pickupPoint : dropOffPoint;
    final routeTargetLabel = status == 'ordered'
        ? 'Seller pickup'
        : 'Buyer drop-off';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6D2),
      appBar: AppBar(title: const PageHeaderTitle('Order Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${widget.orderId.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          color: kTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Pickup address',
                  value: pickupAddress,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Drop-off address',
                  value: dropOffAddress,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Buyer phone',
                  value: buyerPhone.isEmpty
                      ? 'Phone number not available'
                      : buyerPhone,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Buyer email',
                  value: buyerEmail.isEmpty
                      ? 'Email not available'
                      : buyerEmail,
                ),
              ],
            ),
          ),
          if (pickupPoint != null ||
              dropOffPoint != null ||
              driverPoint != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route map',
                    style: TextStyle(
                      color: kTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SharedTrackingSessionMap(
                    sessionId: widget.orderId,
                    pickupPoint: _toMapPoint(pickupPoint),
                    buyerPoint: _toMapPoint(dropOffPoint),
                    initialDriverPoint: _toMapPoint(driverPoint),
                    initialDriverUpdatedAt: driverUpdatedAt,
                    routeTargetPoint: _toMapPoint(routeTargetPoint),
                    routeTargetLabel: routeTargetLabel,
                    height: 220,
                    showPlannedRoute: false,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _buildStatusActions(
              status: status,
              pickupPoint: pickupPoint,
              dropOffPoint: dropOffPoint,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusActions({
    required String status,
    required LatLngPoint? pickupPoint,
    required LatLngPoint? dropOffPoint,
  }) {
    final actions = <Widget>[];

    if (status == 'ordered' && pickupPoint != null) {
      actions.add(
        _ActionButton(
          label: 'Navigate To Pickup',
          color: const Color(0xFFB45309),
          onPressed: () => _openNavigation(
            latitude: pickupPoint.latitude,
            longitude: pickupPoint.longitude,
            label: 'pickup location',
          ),
        ),
      );
    }

    if (status == 'ordered') {
      actions.add(
        _ActionButton(
          label: _isUpdatingStatus
              ? 'Updating...'
              : 'Received - Start Delivery To Buyer',
          color: Colors.orange,
          onPressed: _isUpdatingStatus
              ? null
              : () => _updateOrderStatus('in transit'),
        ),
      );
    }

    if (status == 'in transit') {
      if (dropOffPoint != null) {
        actions.add(
          _ActionButton(
            label: 'Navigate To Buyer',
            color: const Color(0xFF1D4ED8),
            onPressed: () => _openNavigation(
              latitude: dropOffPoint.latitude,
              longitude: dropOffPoint.longitude,
              label: 'buyer drop-off',
            ),
          ),
        );
      }
      actions.add(
        _ActionButton(
          label: _isUpdatingStatus ? 'Updating...' : 'Mark Delivered',
          color: Colors.green,
          onPressed: _isUpdatingStatus ? null : _confirmMarkDelivered,
        ),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        const _ActionButton(
          label: 'Delivered',
          color: Colors.green,
          onPressed: null,
        ),
      );
    }

    return actions;
  }
}

class _DriverRouteMap extends StatefulWidget {
  const _DriverRouteMap({
    required this.pickupPoint,
    required this.driverPoint,
    required this.dropOffPoint,
    required this.trailPoints,
  });

  final LatLngPoint? pickupPoint;
  final LatLngPoint? driverPoint;
  final LatLngPoint? dropOffPoint;
  final List<LatLngPoint> trailPoints;

  @override
  State<_DriverRouteMap> createState() => _DriverRouteMapState();
}

class _DriverRouteMapState extends State<_DriverRouteMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant _DriverRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDriverPoint = widget.driverPoint;
    if (nextDriverPoint == null) return;

    final previousDriverPoint = oldWidget.driverPoint;
    final changed = previousDriverPoint == null ||
        _distanceBetweenPoints(previousDriverPoint, nextDriverPoint) >= 1;
    if (!changed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(
        latlng.LatLng(nextDriverPoint.latitude, nextDriverPoint.longitude),
        15,
      );
      debugPrint(
        'UI: Map updated successfully driver-map='
        '${nextDriverPoint.latitude}, ${nextDriverPoint.longitude}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCenter =
        widget.driverPoint ??
        widget.pickupPoint ??
        widget.dropOffPoint ??
        _riyadhCenter;
    final center = latlng.LatLng(
      resolvedCenter.latitude,
      resolvedCenter.longitude,
    );
    final polylinePoints = _buildPolylinePoints();
    final markers = <Marker>[
      if (widget.pickupPoint != null)
        _marker(
          point: widget.pickupPoint!,
          emoji: '🏪',
          color: const Color(0xFFF59E0B),
        ),
      if (widget.driverPoint != null)
        _marker(
          point: widget.driverPoint!,
          emoji: '🏍️',
          color: const Color(0xFF16A34A),
        ),
      if (widget.dropOffPoint != null)
        _marker(
          point: widget.dropOffPoint!,
          emoji: '🏠',
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
              _DriverMapLegendChip(
                emoji: '🏍️',
                label: 'Driver',
                color: Color(0xFF16A34A),
              ),
              _DriverMapLegendChip(
                emoji: '🏪',
                label: 'Seller',
                color: Color(0xFFF59E0B),
              ),
              _DriverMapLegendChip(
                emoji: '🏠',
                label: 'Buyer',
                color: Color(0xFF1D4ED8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 14),
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
          const Text(
            'Live trail updates as the driver moves.',
            style: TextStyle(
              color: Color(0xFF166534),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<latlng.LatLng> _buildPolylinePoints() {
    final points = widget.trailPoints
        .map((point) => latlng.LatLng(point.latitude, point.longitude))
        .toList();
    if (widget.driverPoint != null) {
      final currentPoint = latlng.LatLng(
        widget.driverPoint!.latitude,
        widget.driverPoint!.longitude,
      );
      if (points.isEmpty ||
          _distanceBetweenLatLng(points.last, currentPoint) >= 1.5) {
        points.add(currentPoint);
      } else {
        points[points.length - 1] = currentPoint;
      }
    }
    return points;
  }

  static const LatLngPoint _riyadhCenter = LatLngPoint(
    latitude: 24.7136,
    longitude: 46.6753,
  );
}

Marker _marker({
  required LatLngPoint point,
  required String emoji,
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
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    ),
  );
}

class _DriverMapLegendChip extends StatelessWidget {
  const _DriverMapLegendChip({
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

class LatLngPoint {
  const LatLngPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

int _compareByCreatedAtDescending(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aTimestamp = a['createdAt'];
  final bTimestamp = b['createdAt'];
  final aMillis = aTimestamp is Timestamp
      ? aTimestamp.millisecondsSinceEpoch
      : 0;
  final bMillis = bTimestamp is Timestamp
      ? bTimestamp.millisecondsSinceEpoch
      : 0;
  return bMillis.compareTo(aMillis);
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

  return 'Pickup address not available on this order yet';
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

  final deliveryAddress = _readText(data, 'deliveryAddress');
  if (deliveryAddress.isNotEmpty) return deliveryAddress;

  return 'Drop-off address not available';
}

LatLngPoint? _positionToLatLng(Position? position) {
  if (position == null) return null;
  return LatLngPoint(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

latlng.LatLng? _toMapPoint(LatLngPoint? point) {
  if (point == null) return null;
  return latlng.LatLng(point.latitude, point.longitude);
}

LatLngPoint? _readLatLng(Object? raw) {
  if (raw is GeoPoint) {
    return LatLngPoint(latitude: raw.latitude, longitude: raw.longitude);
  }

  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final geoPoint = map['geoPoint'];
  if (geoPoint is GeoPoint) {
    return LatLngPoint(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
  }

  final latitude = (map['latitude'] as num?)?.toDouble();
  final longitude = (map['longitude'] as num?)?.toDouble();
  if (latitude == null || longitude == null) {
    return null;
  }

  return LatLngPoint(latitude: latitude, longitude: longitude);
}

DateTime? _readTimestamp(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  return null;
}

List<LatLngPoint> _readTrackingTrail(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final points = <LatLngPoint>[];
  for (final doc in docs) {
    final data = doc.data();
    final point = _readLatLng(data);
    if (point == null) continue;
    if (points.isEmpty || _distanceBetweenPoints(points.last, point) >= 1) {
      points.add(point);
    } else {
      points[points.length - 1] = point;
    }
  }
  return points;
}

double _distanceBetweenPoints(LatLngPoint a, LatLngPoint b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}

double _distanceBetweenLatLng(latlng.LatLng a, latlng.LatLng b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}

String _readText(Map<String, dynamic> data, String key) {
  return (data[key] as String? ?? '').trim();
}

String _emptyDeliveriesMessage(String filter) {
  return switch (filter) {
    'in transit' => 'No in-transit orders are available right now.',
    'completed' => 'No completed orders are available right now.',
    _ => 'No ordered deliveries are available right now.',
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

String _friendlyUpdateErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase denied this update. Deploy firestore.rules and confirm drivers can update delivery status.';
  }

  if (error is FirebaseException && error.code == 'unavailable') {
    return 'Live tracking is temporarily unavailable. Please check your connection and try again.';
  }

  return 'Could not update delivery status. Please try again.';
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

bool _setsEqual(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
