import 'package:flutter/material.dart';
import 'package:souqplus/models/cart.dart';
import 'package:souqplus/screens/cart/cart_screen.dart';
import 'package:souqplus/screens/cart/checkout_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_alerts_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_categories_screen.dart';
import 'package:souqplus/screens/complete_profile/complete_profile_screen.dart';
import 'package:souqplus/screens/details/details_screen.dart';
import 'package:souqplus/screens/favorite/favorite_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_dashboard_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_orders_screen.dart';
import 'package:souqplus/screens/admin_dashboard/admin_payments_screen.dart';
import 'package:souqplus/screens/forgot_password/forgot_password_screen.dart';
import 'package:souqplus/screens/home/home_screen.dart';
import 'package:souqplus/screens/init_screen.dart';
import 'package:souqplus/screens/login_success/login_success_screen.dart';
import 'package:souqplus/screens/notifications/notifications_screen.dart';
import 'package:souqplus/screens/otp/otp_screen.dart';
import 'package:souqplus/screens/products/products_screen.dart';
import 'package:souqplus/screens/profile/my_account_screen.dart';
import 'package:souqplus/screens/profile/posted_products_screen.dart';
import 'package:souqplus/screens/profile/profile_screen.dart';
import 'package:souqplus/screens/profile/purchase_history_screen.dart';
import 'package:souqplus/screens/Regitration/registration_screen.dart';
import 'package:souqplus/screens/search/search_screen.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';
import 'package:souqplus/screens/sign_in/driver_sign_in_screen.dart'; // ✅ DRIVER
import 'package:souqplus/screens/splash/splash_screen.dart';
import 'package:souqplus/seller.dart';
import 'package:souqplus/screens/driver_registration/driver_registration_screen.dart';

// ✅ ROLE SCREEN
import 'package:souqplus/screens/driver_registration/driver_home_screen.dart';

final Map<String, WidgetBuilder> routes = {
  InitScreen.routeName: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialIndex = args is int ? args : 0;
    return InitScreen(initialIndex: initialIndex);
  },


DriverRegistrationScreen.routeName: (context) =>
    const DriverRegistrationScreen(),
  // SPLASH
  SplashScreen.routeName: (context) => const SplashScreen(),

  // ✅ ROLE SELECTION
  // USER LOGIN
  SignInScreen.routeName: (context) => const SignInScreen(),

  // ✅ DRIVER LOGIN
  DriverSignInScreen.routeName: (context) =>
      const DriverSignInScreen(),

  // ADMIN
  AdminDashboardScreen.routeName: (context) => const AdminDashboardScreen(),
  AdminOrdersScreen.routeName: (context) => const AdminOrdersScreen(),
  AdminCategoriesScreen.routeName: (context) =>
      const AdminCategoriesScreen(),
  AdminPaymentsScreen.routeName: (context) =>
      const AdminPaymentsScreen(),
  AdminAlertsScreen.routeName: (context) => const AdminAlertsScreen(),

  // OTHER SCREENS
  ForgotPasswordScreen.routeName: (context) =>
      const ForgotPasswordScreen(),
  LoginSuccessScreen.routeName: (context) =>
      const LoginSuccessScreen(),
  RegistrationScreen.routeName: (context) =>
      const RegistrationScreen(),
  CompleteProfileScreen.routeName: (context) =>
      const CompleteProfileScreen(),
      DriverHomeScreen.routeName: (context) => const DriverHomeScreen(),

  OtpScreen.routeName: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final email = (args['email'] as String? ?? '').trim();
      final initialError = (args['initialError'] as String?)?.trim();
      return OtpScreen(
        email: email,
        registrationData: args,
        initialError: initialError,
      );
    }
    final email = (args as String? ?? '').trim();
    return OtpScreen(email: email);
  },

  HomeScreen.routeName: (context) => const InitScreen(initialIndex: 0),
  "/home": (context) => const HomeScreen(),

  ProductsScreen.routeName: (context) => const ProductsScreen(),
  DetailsScreen.routeName: (context) => const DetailsScreen(),
  FavoriteScreen.routeName: (context) => const FavoriteScreen(),
  CartScreen.routeName: (context) => const CartScreen(),

  CheckoutScreen.routeName: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    List<Cart>? initialItems;

    if (args is List<Cart>) {
      initialItems = args;
    } else if (args is Map<String, dynamic>) {
      final routeItems = args['initialItems'];
      if (routeItems is List<Cart>) {
        initialItems = routeItems;
      }
    }

    return CheckoutScreen(initialItems: initialItems);
  },

  SearchScreen.routeName: (context) =>
      const InitScreen(initialIndex: 2),
  ProfileScreen.routeName: (context) =>
      const InitScreen(initialIndex: 3),
  NotificationsScreen.routeName: (context) =>
      const NotificationsScreen(),
  MyAccountScreen.routeName: (context) =>
      const MyAccountScreen(),
  PurchaseHistoryScreen.routeName: (context) =>
      const PurchaseHistoryScreen(),
  PostedProductsScreen.routeName: (context) =>
      const PostedProductsScreen(),

  SellerScreen.routeName: (context) => const SellerScreen(),
};
