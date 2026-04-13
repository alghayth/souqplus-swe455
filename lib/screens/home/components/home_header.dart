import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/screens/profile/profile_screen.dart';
import 'package:souqplus/services/notification_service.dart';

import 'icon_btn_with_counter.dart';
import 'search_field.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onFilterPressed,
    required this.showBadge,
  });

  final VoidCallback onFilterPressed;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Expanded(child: SearchField()),
          const SizedBox(width: 16),
          if (user == null)
            IconBtnWithCounter(
              svgSrc: "assets/icons/Bell.svg",
              press: () => AppBottomNav.openTab(context, 1),
            )
          else
            StreamBuilder<int>(
              stream: NotificationService.instance.unreadCountStream(user.uid),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return IconBtnWithCounter(
                  svgSrc: "assets/icons/Bell.svg",
                  numOfitem: unreadCount,
                  press: () => AppBottomNav.openTab(context, 1),
                );
              },
            ),
          const SizedBox(width: 8),
          IconBtnWithCounter(
            svgSrc: "assets/icons/User Icon.svg",
            press: () => Navigator.pushNamed(context, ProfileScreen.routeName),
          ),
          const SizedBox(width: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filter',
                icon: const Icon(Icons.tune),
                onPressed: onFilterPressed,
              ),
              if (showBadge)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
