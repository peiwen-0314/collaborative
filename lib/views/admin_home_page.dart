import 'package:flutter/material.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const Color mainGreen =
  Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7F5),

      body: Row(
        children: [
          // =====================================================
          // SIDEBAR
          // =====================================================
          Container(
            width: 240,
            color: mainGreen,
            child: Column(
              children: [
                const SizedBox(height: 30),

                const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.eco,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'EcoTravel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  'Admin Portal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 35),

                sidebarItem(
                  icon: Icons.home_outlined,
                  title: 'Dashboard',
                  selected: true,
                  onTap: () {},
                ),

                sidebarItem(
                  icon: Icons.place_outlined,
                  title:
                  'Attraction Management',
                  onTap: () {
                    // TODO navigation
                  },
                ),

                sidebarItem(
                  icon:
                  Icons.card_giftcard_outlined,
                  title: 'Stamp Management',
                  onTap: () {
                    // TODO navigation
                  },
                ),

                sidebarItem(
                  icon: Icons.people_outline,
                  title: 'User Management',
                  onTap: () {
                    // TODO navigation
                  },
                ),

                sidebarItem(
                  icon:
                  Icons.receipt_long_outlined,
                  title:
                  'Booking / Reports',
                  onTap: () {
                    // TODO navigation
                  },
                ),

                const Spacer(),

                const Divider(
                  color: Colors.white24,
                ),

                sidebarItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // =====================================================
          // MAIN CONTENT
          // =====================================================
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              Colors.black87,
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

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                              Color(
                                0xFFE8F5E9,
                              ),
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
                                fontWeight:
                                FontWeight.w600,
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
                        alignment:
                        WrapAlignment.center,
                        children: [
                          dashboardCard(
                            icon:
                            Icons.place_outlined,
                            title:
                            'Attraction Management',
                            description:
                            'Add, edit and manage attractions.',
                            onTap: () {
                              // TODO:
                              // Navigator.push(...)
                            },
                          ),

                          dashboardCard(
                            icon: Icons
                                .card_giftcard_outlined,
                            title:
                            'Stamp Management',
                            description:
                            'Manage travel stamps and rewards.',
                            onTap: () {
                              // TODO navigation
                            },
                          ),

                          dashboardCard(
                            icon:
                            Icons.people_outline,
                            title:
                            'User Management',
                            description:
                            'View and manage registered users.',
                            onTap: () {
                              // TODO navigation
                            },
                          ),

                          dashboardCard(
                            icon: Icons
                                .analytics_outlined,
                            title:
                            'Reports & Booking',
                            description:
                            'View booking information and reports.',
                            onTap: () {
                              // TODO navigation
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
  // SIDEBAR ITEM
  // ============================================================

  static Widget sidebarItem({
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
        borderRadius:
        BorderRadius.circular(10),
        child: InkWell(
          borderRadius:
          BorderRadius.circular(10),
          onTap: onTap,
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

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
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
        borderRadius:
        BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius:
          BorderRadius.circular(16),
          child: Padding(
            padding:
            const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: mainGreen
                        .withOpacity(0.10),
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
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
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    Colors.grey.shade600,
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