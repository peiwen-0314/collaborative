import 'package:flutter/material.dart';

import '../controllers/ai_trip_planner_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/user.dart';
import '../widgets/eco_bottom_navigation.dart';

import 'community_feed_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'ride_home_page.dart';
import 'trip_location_date_page.dart';

class AiTripPlannerPage extends StatefulWidget {
  const AiTripPlannerPage({super.key});

  @override
  State<AiTripPlannerPage> createState() =>
      _AiTripPlannerPageState();
}

class _AiTripPlannerPageState
    extends State<AiTripPlannerPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color lightGreen =
  Color(0xFFE8F5E9);

  static const Color textColor =
  Color(0xFF232323);

  static const Color secondaryText =
  Color(0xFF777777);

  static const Color pageBackground =
  Color(0xFFF8FAF8);

  final AiTripPlannerController _controller =
  AiTripPlannerController();

  final AuthController _authController =
  AuthController();

  UserModel? _profile;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_refresh);
    _controller.loadAttractions();

    _loadProfile();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    final profile =
    await _authController.getCurrentUserProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();

    super.dispose();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _startTripPlanning() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripLocationDatePage(
          controller: _controller,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
    );
  }

  void _goTransport() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TransportationPage(),
      ),
    );
  }

  void _goCommunity() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const CommunityFeedPage(),
      ),
    );
  }

  void _goProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ProfilePage(),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ProfilePage(),
      ),
    ).then(
          (_) => _loadProfile(),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            20,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // Same header concept as Home Page
              _header(),

              const SizedBox(height: 22),

              // Keep Plan Smarter section
              _plannerTitle(),

              const SizedBox(height: 14),

              _benefits(),

              const SizedBox(height: 12),

              _plannerCard(),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                  _startTripPlanning,
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Generate My Trip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    mainGreen,
                    foregroundColor:
                    Colors.white,
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar:
      EcoBottomNavigation(
        currentIndex: 2,

        onHomeTap: _goHome,

        onTransportTap: _goTransport,

        onPlanTripTap: () {
          // Already on AI Trip Planner.
        },

        onCommunityTap: _goCommunity,

        onProfileTap: _goProfile,
      ),
    );
  }

  // ============================================================
  // HEADER - SAME STYLE AS HOME PAGE
  // ============================================================

  Widget _header() {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-7, 0),
          child: Image.asset(
            'assets/images/logo.png',
            height: 55,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PLAN SMARTER
  // ============================================================

  Widget _plannerTitle() {
    return const Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Plan Smarter,',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),

        Row(
          children: [
            Text(
              'Travel Greener',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.w800,
                color: mainGreen,
              ),
            ),

            SizedBox(width: 4),

            Icon(
              Icons.eco,
              color: mainGreen,
              size: 24,
            ),
          ],
        ),

        SizedBox(height: 8),

        Text(
          'Let our AI create a personalized, sustainable itinerary '
              'that matches your travel style.',
          style: TextStyle(
            color: secondaryText,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BENEFITS
  // ============================================================

  Widget _benefits() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _Benefit(
              icon: Icons.eco,
              text:
              'Eco-friendly\nrecommendations',
            ),
          ),
          Expanded(
            child: _Benefit(
              icon:
              Icons.psychology_alt_rounded,
              text:
              'AI-powered\nitinerary',
            ),
          ),
          Expanded(
            child: _Benefit(
              icon: Icons.tune_rounded,
              text:
              'Personalized\nfor you',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLANNER CARD
  // ============================================================

  Widget _plannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color:
          const Color(0xFFE1E1E1),
        ),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row(
            Icons.location_on_outlined,
            'Travel Places',
            _controller
                .preferences
                .selectedState ??
                'Select your travel location',
          ),

          _divider(),

          _row(
            Icons.calendar_month_outlined,
            'Travel Dates',
            _controller
                .preferences.dateSummary,
          ),

          _divider(),

          _row(
            Icons.people_alt_outlined,
            'Travelers',
            _controller
                .preferences
                .travelerSummary,
          ),

          _divider(),

          _row(
            Icons
                .account_balance_wallet_outlined,
            'Budget Range',
            'MYR ${_controller.preferences.budget.toStringAsFixed(0)}',
          ),

          _divider(),

          _row(
            Icons.travel_explore_rounded,
            'Travel Style',
            _controller.preferences
                .travelStyles.isEmpty
                ? 'Choose your travel style'
                : _controller
                .preferences.travelStyles
                .join(', '),
          ),
        ],
      ),
    );
  }

  Widget _row(
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
            const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: mainGreen,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 60,
      endIndent: 12,
      color: Color(0xFFEAEAEA),
    );
  }
}

// ============================================================
// BENEFIT ITEM
// ============================================================

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Benefit({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration:
          const BoxDecoration(
            color: Color(0xFF2E7D32),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 17,
            color: Colors.white,
          ),
        ),

        const SizedBox(width: 6),

        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 7.4,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}