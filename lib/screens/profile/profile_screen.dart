import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/screens/favorite/favorite_screen.dart';
import 'package:souqplus/screens/profile/my_account_screen.dart';
import 'package:souqplus/screens/profile/posted_products_screen.dart';
import 'package:souqplus/screens/profile/purchase_history_screen.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';
import 'package:souqplus/services/seller_stripe_service.dart';

import 'components/profile_menu.dart';

class ProfileScreen extends StatefulWidget {
  static String routeName = "/profile";

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  bool _awaitingStripeReturn = false;
  bool _isCheckingStripeReturn = false;

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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      SignInScreen.routeName,
      (route) => false,
    );
  }

  Future<void> _connectStripe() async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to connect Stripe.')),
      );
      return;
    }

    final connected = await SellerStripeService.ensureConnectedBeforePosting(
      context,
      user: user,
      dialogMessage:
          'Complete Stripe onboarding to unlock posting and payouts.',
      successReminder:
          'Complete Stripe onboarding, then return to the app to finish connecting your account.',
    );

    if (!mounted) return;
    if (connected == SellerStripePostingAccess.connected) {
      _awaitingStripeReturn = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stripe account is connected.')),
      );
      return;
    }

    if (connected == SellerStripePostingAccess.onboardingStarted) {
      _awaitingStripeReturn = true;
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed ||
        !_awaitingStripeReturn ||
        _isCheckingStripeReturn ||
        !mounted) {
      return;
    }

    final user = _currentUser;
    if (user == null) {
      _awaitingStripeReturn = false;
      return;
    }

    _isCheckingStripeReturn = true;
    try {
      final isConnected = await SellerStripeService.hasConnectedAccount(user);
      if (!mounted) return;

      if (isConnected) {
        _awaitingStripeReturn = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Stripe account connected successfully. You can now post products and receive payments.',
            ),
          ),
        );
      }
    } finally {
      _isCheckingStripeReturn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!
        : 'User';
    final email = user?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: const PageHeaderTitle("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Favorites',
            onPressed: () =>
                Navigator.pushNamed(context, FavoriteScreen.routeName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ProfileMenu(
              text: "Edit Profile",
              icon: "assets/icons/User Icon.svg",
              press: () =>
                  Navigator.pushNamed(context, MyAccountScreen.routeName),
            ),
            ProfileMenu(
              text: "My Favorites",
              icon: "assets/icons/Heart Icon.svg",
              press: () =>
                  Navigator.pushNamed(context, FavoriteScreen.routeName),
            ),
            ProfileMenu(
              text: "Purchase History",
              icon: "assets/icons/receipt.svg",
              press: () => Navigator.pushNamed(
                context,
                PurchaseHistoryScreen.routeName,
              ),
            ),
            ProfileMenu(
              text: "Connect Stripe",
              icon: "assets/icons/Bill Icon.svg",
              press: _connectStripe,
            ),
            ProfileMenu(
              text: "Posted Product",
              icon: "assets/icons/Shop Icon.svg",
              press: () =>
                  Navigator.pushNamed(context, PostedProductsScreen.routeName),
            ),
            ProfileMenu(
              text: "Log Out",
              icon: "assets/icons/Log out.svg",
              press: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
