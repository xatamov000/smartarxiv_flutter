// lib/pages/widgets/bottom_nav.dart
//
// BottomNav (simple):
// - HomeShell yo‘q
// - Named route yo‘q
// - PushReplacement bilan 3 ta page orasida yuradi

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../documents_page.dart';
import '../profile_page.dart';
import '../scan_page.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _navItem(
              context,
              index: 0,
              label: "Documents",
              icon: Icons.description,
            ),
          ),
          Expanded(
            child: _navItem(
              context,
              index: 1,
              label: "Scan",
              icon: Icons.center_focus_strong,
            ),
          ),
          Expanded(
            child: _navItem(
              context,
              index: 2,
              label: "Profile",
              icon: Icons.person,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => _navigate(context, index),
      child:
          isSelected
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.white, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.iconGrey, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.iconGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
    );
  }

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget page;
    switch (index) {
      case 0:
        page = const DocumentsPage();
        break;
      case 1:
        page = const ScanPage();
        break;
      case 2:
        page = const ProfilePage();
        break;
      default:
        page = const DocumentsPage();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
      ),
    );
  }
}
