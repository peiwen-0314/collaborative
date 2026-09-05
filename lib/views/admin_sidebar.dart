import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedPage,
    required this.onDashboardTap,
    required this.onAttractionTap,
    required this.onCategoryTap,
    required this.onCulturalHeritageTap,
    required this.onStampTap,
    required this.onReportTap,
    required this.onLogoutTap,
  });

  final String selectedPage;

  final VoidCallback onDashboardTap;
  final VoidCallback onAttractionTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onCulturalHeritageTap;
  final VoidCallback onStampTap;
  final VoidCallback onReportTap;
  final VoidCallback onLogoutTap;

  static const Color mainGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: mainGreen,
      child: Column(
        children: [
          const SizedBox(height: 30),

          // =====================================================
          // LOGO
          // =====================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

          const SizedBox(height: 35),

          // =====================================================
          // DASHBOARD
          // =====================================================
          sidebarItem(
            icon: Icons.home_outlined,
            title: 'Dashboard',
            selected: selectedPage == 'dashboard',
            onTap: onDashboardTap,
          ),

          // =====================================================
          // ATTRACTION MANAGEMENT
          // =====================================================
          sidebarItem(
            icon: Icons.place_outlined,
            title: 'Attraction Management',
            selected: selectedPage == 'attraction',
            onTap: onAttractionTap,
          ),

          // =====================================================
          // CATEGORY MANAGEMENT
          // =====================================================
          sidebarItem(
            icon: Icons.category_outlined,
            title: 'Categories Management',
            selected: selectedPage == 'category',
            onTap: onCategoryTap,
          ),

          // =====================================================
          // STAMP MANAGEMENT
          // =====================================================
          sidebarItem(
            icon: Icons.card_giftcard_outlined,
            title: 'Stamp Management',
            selected: selectedPage == 'stamp',
            onTap: onStampTap,
          ),

          // =====================================================
          // REPORTS & BOOKING
          // =====================================================
          sidebarItem(
            icon: Icons.analytics_outlined,
            title: 'Reports & Booking',
            selected: selectedPage == 'report',
            onTap: onReportTap,
          ),

          const Spacer(),

          const Divider(
            color: Colors.white24,
          ),

          // =====================================================
          // LOGOUT
          // =====================================================
          sidebarItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: onLogoutTap,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // SIDEBAR ITEM
  // ============================================================
  Widget sidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Material(
        color: selected
            ? Colors.white.withOpacity(0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
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

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
