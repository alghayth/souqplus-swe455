import 'package:flutter/material.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/screens/home/home_screen.dart';
import 'package:souqplus/screens/notifications/notifications_screen.dart';
import 'package:souqplus/screens/profile/profile_screen.dart';
import 'package:souqplus/screens/search/search_screen.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key, this.initialIndex = 0});

  static String routeName = "/";
  final int initialIndex;

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  late int currentSelectedIndex;

  @override
  void initState() {
    super.initState();
    currentSelectedIndex = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex > 3 ? 3 : widget.initialIndex);
  }

  final pages = [
    const HomeScreen(),
    const NotificationsScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: pages[currentSelectedIndex],
      floatingActionButton: const AppNavFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNav(selectedIndex: currentSelectedIndex),
    );
  }
}
