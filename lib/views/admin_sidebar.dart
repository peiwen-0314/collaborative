import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:collaborative_asg/views/attraction_management_page.dart';
import 'package:collaborative_asg/views/category_management_page.dart';

import 'admin_challenge_management_page.dart';
import 'admin_home_page.dart';
import 'admin_login_page.dart';
import 'admin_moderation_page.dart';
import 'admin_reports_analytics_page.dart';
import 'admin_stamp_management_page.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedPage,

    // =========================================================
    // LEGACY CALLBACKS
    // =========================================================
    // Keep these temporarily so existing admin pages
    // do not break. Sidebar navigation is now handled
    // internally, so these callbacks are no longer required.
    this.onDashboardTap,
    this.onAttractionTap,
    this.onCategoryTap,
    this.onCulturalHeritageTap,
    this.onModerationTap,
    this.onStampTap,
    this.onChallengeTap,
    this.onReportTap,
    this.onLogoutTap,
  });

  final String selectedPage;

  // ===========================================================
  // LEGACY OPTIONAL CALLBACKS
  // ===========================================================

  final VoidCallback? onDashboardTap;
  final VoidCallback? onAttractionTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onCulturalHeritageTap;
  final VoidCallback? onModerationTap;
  final VoidCallback? onStampTap;
  final VoidCallback? onChallengeTap;
  final VoidCallback? onReportTap;
  final VoidCallback? onLogoutTap;

  static const Color mainGreen =
  Color(0xFF2E7D32);

  // ===========================================================
  // NAVIGATION
  // ===========================================================

  void _navigate(
      BuildContext context, {
        required String pageKey,
        required Widget page,
      }) {
    // Already on this page
    if (selectedPage == pageKey) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  // ===========================================================
  // LOGOUT
  // ===========================================================

  Future<void> _logout(
      BuildContext context,
      ) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AdminLoginPage(),
      ),
          (route) => false,
    );
  }

  // ===========================================================
  // BUILD
  // ===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 240,
      color: mainGreen,
      child: Column(
        children: [
          const SizedBox(
            height: 30,
          ),

          // ===================================================
          // LOGO
          // ===================================================

          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/admin_logo.png',
                width: 180,
                height: 60,
                fit: BoxFit.contain,
              ),
            ],
          ),

          const Text(
            'Admin Portal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 35,
          ),

          // ===================================================
          // DASHBOARD
          // ===================================================

          sidebarItem(
            icon: Icons.home_outlined,
            title: 'Dashboard',
            selected:
            selectedPage ==
                'dashboard',
            onTap: () {
              _navigate(
                context,
                pageKey: 'dashboard',
                page:
                const AdminHomePage(),
              );
            },
          ),

          // ===================================================
          // ATTRACTION MANAGEMENT
          // ===================================================

          sidebarItem(
            icon: Icons.place_outlined,
            title:
            'Attraction Management',
            selected:
            selectedPage ==
                'attraction',
            onTap: () {
              _navigate(
                context,
                pageKey: 'attraction',
                page:
                const AttractionManagementPage(),
              );
            },
          ),

          // ===================================================
          // CATEGORY MANAGEMENT
          // ===================================================

          sidebarItem(
            icon:
            Icons.category_outlined,
            title:
            'Categories Management',
            selected:
            selectedPage ==
                'category',
            onTap: () {
              _navigate(
                context,
                pageKey: 'category',
                page:
                const CategoryManagementPage(),
              );
            },
          ),

          // ===================================================
          // CONTENT MODERATION
          // ===================================================

          sidebarItem(
            icon: Icons.shield_outlined,
            title:
            'Content Moderation',
            selected:
            selectedPage ==
                'moderation',
            onTap: () {
              _navigate(
                context,
                pageKey: 'moderation',
                page:
                const AdminModerationPage(),
              );
            },
          ),

          // ===================================================
          // STAMP MANAGEMENT
          // ===================================================

          sidebarItem(
            icon:
            Icons.card_giftcard_outlined,
            title:
            'Stamp Management',
            selected:
            selectedPage ==
                'stamp',
            onTap: () {
              _navigate(
                context,
                pageKey: 'stamp',
                page:
                const AdminStampManagementPage(),
              );
            },
          ),

          // ===================================================
          // CHALLENGE MANAGEMENT
          // ===================================================

          sidebarItem(
            icon:
            Icons.emoji_events_outlined,
            title:
            'Challenge Management',
            selected:
            selectedPage ==
                'challenge',
            onTap: () {
              _navigate(
                context,
                pageKey: 'challenge',
                page:
                const AdminChallengeManagementPage(),
              );
            },
          ),

          // ===================================================
          // REPORTS & ANALYTICS
          // ===================================================

          sidebarItem(
            icon:
            Icons.analytics_outlined,
            title:
            'Reports & Analytics',
            selected:
            selectedPage ==
                'report',
            onTap: () {
              _navigate(
                context,
                pageKey: 'report',
                page:
                const AdminReportsAnalyticsPage(),
              );
            },
          ),

          const Spacer(),

          const Divider(
            color: Colors.white24,
          ),

          // ===================================================
          // LOGOUT
          // ===================================================

          sidebarItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              await _logout(
                context,
              );
            },
          ),

          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // SIDEBAR ITEM
  // ===========================================================

  Widget sidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Material(
        color: selected
            ? Colors.white.withOpacity(
          0.18,
        )
            : Colors.transparent,
        borderRadius:
        BorderRadius.circular(
          10,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
          BorderRadius.circular(
            10,
          ),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Text(
                    title,
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}