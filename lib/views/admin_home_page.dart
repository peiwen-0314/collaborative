import 'package:collaborative_asg/views/attraction_management_page.dart';
import 'package:collaborative_asg/views/category_management_page.dart';
import 'package:flutter/material.dart';

import 'admin_sidebar.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const Color mainGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),

      body: Row(
        children: [
          // =====================================================
          // SIDEBAR
          // =====================================================
          AdminSidebar(
            selectedPage: 'dashboard',

            onDashboardTap: () {
              // Already on dashboard
            },

            // ===================================================
            // ATTRACTION MANAGEMENT
            // ===================================================
            onAttractionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const AttractionManagementPage(),
                ),
              );
            },

            // ===================================================
            // CATEGORY MANAGEMENT
            // ===================================================
            onCategoryTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const CategoryManagementPage(),
                ),
              );
            },

            // Cultural & Heritage is now managed inside
            // Attraction Management.
            onCulturalHeritageTap: () {},

            // ===================================================
            // STAMP MANAGEMENT
            // ===================================================
            onStampTap: () {
              // Later add navigation
            },

            // ===================================================
            // REPORT
            // ===================================================
            onReportTap: () {
              // Later add navigation
            },

            // ===================================================
            // LOGOUT
            // ===================================================
            onLogoutTap: () {
              Navigator.pop(context);
            },
          ),

          // =====================================================
          // MAIN CONTENT
          // =====================================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =================================================
                  // HEADER
                  // =================================================
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            'Manage EcoTravel system functions.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      // =============================================
                      // ADMIN PROFILE
                      // =============================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(
                                Icons.person,
                                color: mainGreen,
                                size: 19,
                              ),
                            ),

                            SizedBox(width: 8),

                            Text(
                              'Administrator',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // =================================================
                  // NAVIGATION CARDS
                  // =================================================
                  Expanded(
                    child: Center(
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          // =========================================
                          // ATTRACTION MANAGEMENT
                          // =========================================
                          dashboardCard(
                            icon: Icons.place_outlined,
                            title: 'Attraction Management',
                            description:
                            'Add, edit and manage all attractions, including Cultural & Heritage.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const AttractionManagementPage(),
                                ),
                              );
                            },
                          ),

                          // =========================================
                          // CATEGORY MANAGEMENT
                          // =========================================
                          dashboardCard(
                            icon: Icons.category_outlined,
                            title: 'Categories Management',
                            description:
                            'View and manage attraction categories.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const CategoryManagementPage(),
                                ),
                              );
                            },
                          ),

                          // =========================================
                          // STAMP MANAGEMENT
                          // =========================================
                          dashboardCard(
                            icon: Icons.card_giftcard_outlined,
                            title: 'Stamp Management',
                            description:
                            'Manage travel stamps and rewards.',
                            onTap: () {
                              // Later add navigation
                            },
                          ),

                          // =========================================
                          // REPORTS & BOOKING
                          // =========================================
                          dashboardCard(
                            icon: Icons.analytics_outlined,
                            title: 'Reports & Booking',
                            description:
                            'View booking information and reports.',
                            onTap: () {
                              // Later add navigation
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD CARD
  // ============================================================
  static Widget dashboardCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 280,
      height: 185,

      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,

        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),

          child: Padding(
            padding: const EdgeInsets.all(22),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,

                  decoration: BoxDecoration(
                    color: mainGreen.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Icon(
                    icon,
                    color: mainGreen,
                    size: 25,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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