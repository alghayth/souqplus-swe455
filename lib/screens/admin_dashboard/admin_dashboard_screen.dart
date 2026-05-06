import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/screens/admin_dashboard/admin_active_orders_map_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_alerts_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_categories_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_drivers_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_orders_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_payments_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_records_screen.dart';
import 'package:souqplus/screens/admin_dashboard/components/admin_feature_card.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';
import 'package:souqplus/services/admin_access_service.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  static const String routeName = '/admin_dashboard';

  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminAccessService _adminAccessService = const AdminAccessService();
  final AdminOrderService _adminOrderService = const AdminOrderService();

  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  Future<void> _verifyAdminAccess() async {
    final adminAccess = await _adminAccessService.checkCurrentUserAdmin();
    if (!mounted) return;

    if (!adminAccess.isAdmin) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        SignInScreen.routeName,
        (route) => false,
        arguments:
            adminAccess.message ??
            'Admin access is restricted to authorized accounts only.',
      );
      return;
    }

    setState(() {
      _hasAdminAccess = true;
      _isCheckingAccess = false;
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Do you want to end your admin session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      SignInScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasAdminAccess) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _adminOrderService.ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 253, 246, 210),
            appBar: AppBar(
              backgroundColor: kSecondaryColor,
              title: const PageHeaderTitle('Admin Dashboard'),
              actions: [
                IconButton(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Log Out',
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _FirebaseErrorPanel(error: snapshot.error.toString()),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color.fromARGB(255, 253, 246, 210),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final pendingOrders = docs.where((doc) {
          final status = AdminOrderService.normalizeOrderStatus(
            (doc.data()['status'] as String?) ?? '',
          );
          return status == 'ordered';
        }).length;
        final alertCount = pendingOrders;
        final activeTrackedOrders = docs.where((doc) {
          final data = doc.data();
          final status = AdminOrderService.normalizeOrderStatus(
            (data['status'] as String?) ?? '',
          );
          return status == 'ordered' || status == 'in transit';
        }).length;
        final totalRevenue = docs.fold<double>(0, (totalValue, doc) {
          final data = doc.data();
          final paymentStatus = ((data['paymentStatus'] as String?) ?? '')
              .trim()
              .toLowerCase();
          if (paymentStatus != 'paid') return totalValue;
          return totalValue +
              ((data['totalPriceSar'] as num?)?.toDouble() ??
                  (data['total'] as num?)?.toDouble() ??
                  0);
        });

        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 253, 246, 210),
          appBar: AppBar(
            backgroundColor: kSecondaryColor,
            title: const PageHeaderTitle('Admin Dashboard'),
            actions: [
              IconButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AdminAlertsScreen.routeName),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (alertCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            alertCount > 99 ? '99+' : '$alertCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: kPrimaryColor,
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 18,
                    color: kSecondaryColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Log Out',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradientColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x221B3A68),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your central hub for orders, categories, payments, and system alerts.',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _HeroStatChip(label: '${docs.length} Orders'),
                          _HeroStatChip(
                            label:
                                'SAR ${totalRevenue.toStringAsFixed(0)} Revenue',
                          ),
                          _HeroStatChip(label: '$alertCount Alerts'),
                          _LiveCountChip(
                            label: 'Products',
                            stream: _adminOrderService.productsStream(),
                          ),
                          _LiveCountChip(
                            label: 'Users',
                            stream: _adminOrderService.usersStream(),
                          ),
                          _LiveCountChip(
                            label: 'Categories',
                            stream: _adminOrderService.categoriesStream(),
                          ),
                          _LiveCountChip(
                            label: 'Drivers',
                            stream: _adminOrderService.driversStream(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isGrid = constraints.maxWidth >= 700;
                    final cards = [
                      AdminFeatureCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Orders',
                        description:
                            'View, filter, and update ordered, in transit, and delivered orders.',
                        badgeText: '${docs.length}',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminOrdersScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.category_rounded,
                        title: 'Categories',
                        description:
                            'Add or delete product categories while keeping default ones protected.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminCategoriesScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.local_shipping_rounded,
                        title: 'Drivers',
                        description:
                            'See every registered driver in a separate admin panel.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminDriversScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.payments_rounded,
                        title: 'Payments',
                        description:
                            'Monitor revenue and update paid, unpaid, or refunded orders.',
                        badgeText: 'SAR ${totalRevenue.toStringAsFixed(0)}',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminPaymentsScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.notifications_active_rounded,
                        title: 'Alerts',
                        description:
                            'Track ordered items that still need admin attention.',
                        badgeText: '$alertCount',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminAlertsScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.map_rounded,
                        title: 'Active Orders Map',
                        description:
                            'Monitor driver, seller, and buyer route maps for active orders.',
                        badgeText: '$activeTrackedOrders',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminActiveOrdersMapScreen.routeName,
                        ),
                      ),
                      AdminFeatureCard(
                        icon: Icons.storage_rounded,
                        title: 'Data Management',
                        description:
                            'View registered users and product posts from Firestore.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AdminRecordsScreen.routeName,
                        ),
                      ),
                    ];

                    if (!isGrid) {
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i != cards.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      );
                    }

                    final itemWidth = (constraints.maxWidth - 14) / 2;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: cards
                          .map(
                            (card) => SizedBox(width: itemWidth, child: card),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
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

class _LiveCountChip extends StatelessWidget {
  const _LiveCountChip({required this.label, required this.stream});

  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasError
            ? 'Error'
            : snapshot.connectionState == ConnectionState.waiting
            ? '...'
            : '${snapshot.data?.docs.length ?? 0}';
        return _HeroStatChip(label: '$value $label');
      },
    );
  }
}

class _FirebaseErrorPanel extends StatelessWidget {
  const _FirebaseErrorPanel({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8E3EE)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: kSecondaryColor,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Firebase data could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7C93)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
