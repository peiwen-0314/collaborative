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

            onAttractionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttractionManagementPage(),
                ),
              );
            },

            onCategoryTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttractionManagementPage(),
                ),
              );
            },


            onStampTap: () {
              // Later add navigation
            },

            onReportTap: () {
              // Later add navigation
            },

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

                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Manage EcoTravel system functions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
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
                          dashboardCard(
                            icon: Icons.place_outlined,
                            title: 'Attraction Management',
                            description:
                            'Add, edit and manage attractions.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AttractionManagementPage(),
                                ),
                              );
                            },
                          ),

                          dashboardCard(
                            icon: Icons.people_outline,
                            title: 'Categories Management',
                            description:
                            'View and manage attraction categories.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CategoryManagementPage(),
                                ),
                              );
                            },
                          ),

                          dashboardCard(
                            icon: Icons.card_giftcard_outlined,
                            title: 'Stamp Management',
                            description:
                            'Manage travel stamps and rewards.',
                            onTap: () {
                              // Later add navigation
                            },
                          ),

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
      height: 170,

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
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