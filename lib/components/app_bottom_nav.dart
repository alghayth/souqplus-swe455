import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/seller_stripe_service.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
  });

  final int selectedIndex;

  static const Color _activeColor = kPrimaryColor;
  static const Color _inactiveColor = Color(0xFF98A2B3);

  static void openTab(BuildContext context, int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: selectedIndex == 0,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
              onTap: () => openTab(context, 0),
            ),
            _NavItem(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              isSelected: selectedIndex == 1,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
              onTap: () => openTab(context, 1),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: 'Search',
              isSelected: selectedIndex == 2,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
              onTap: () => openTab(context, 2),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              isSelected: selectedIndex == 3,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
              onTap: () => openTab(context, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class AppNavFab extends StatefulWidget {
  const AppNavFab({
    super.key,
    this.isSellerPage = false,
  });

  final bool isSellerPage;

  @override
  State<AppNavFab> createState() => _AppNavFabState();
}

class _AppNavFabState extends State<AppNavFab> with WidgetsBindingObserver {
  bool _awaitingStripeReturn = false;
  bool _isCheckingStripeOnResume = false;
  bool _isOpeningSeller = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed ||
        !_awaitingStripeReturn ||
        _isCheckingStripeOnResume ||
        widget.isSellerPage ||
        !mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _awaitingStripeReturn = false;
      return;
    }

    _isCheckingStripeOnResume = true;
    try {
      final isConnected = await SellerStripeService.hasConnectedAccount(user);
      if (!mounted) return;

      if (isConnected) {
        _awaitingStripeReturn = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stripe connected successfully. You can create a post now.'),
          ),
        );
        Navigator.pushNamed(context, '/seller');
      }
    } finally {
      _isCheckingStripeOnResume = false;
    }
  }

  Future<void> _handleOpenSeller() async {
    if (_isOpeningSeller) return;

    setState(() => _isOpeningSeller = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a product post.'),
        ),
      );
      if (mounted) {
        setState(() => _isOpeningSeller = false);
      }
      return;
    }

    try {
      final result = await SellerStripeService.ensureConnectedBeforePosting(
        context,
        user: user,
        dialogMessage:
            'Connect your Stripe seller account before opening the create product screen.',
        successReminder:
            'Complete Stripe onboarding, then return to the app to create your post.',
      );

      if (!mounted) return;

      if (result == SellerStripePostingAccess.connected) {
        _awaitingStripeReturn = false;
        Navigator.pushNamed(context, '/seller');
        return;
      }

      if (result == SellerStripePostingAccess.onboardingStarted) {
        _awaitingStripeReturn = true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open seller page: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningSeller = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: widget.isSellerPage ? 'seller_page_nav_fab' : 'app_bottom_nav_fab',
      onPressed: widget.isSellerPage ? null : _handleOpenSeller,
      backgroundColor: kPrimaryColor,
      child: _isOpeningSeller
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
