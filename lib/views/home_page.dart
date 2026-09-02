import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../controllers/personalization_controller.dart';
import '../models/attraction.dart';
import '../widgets/eco_bottom_navigation.dart';

import 'ai_trip_planner_page.dart';
import 'attraction_detail_page.dart';
import 'attraction_search_page.dart';
import 'ride_home_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onTransportTap;
  final VoidCallback? onPlanTripTap;
  final VoidCallback? onCommunityTap;
  final VoidCallback? onProfileTap;

  const HomePage({
    super.key,
    this.onTransportTap,
    this.onPlanTripTap,
    this.onCommunityTap,
    this.onProfileTap,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color darkGreen =
  Color(0xFF1B5E20);

  static const Color lightGreen =
  Color(0xFFE8F5E9);

  static const Color pageBackground =
  Color(0xFFF8FAF8);

  static const Color textColor =
  Color(0xFF212121);

  static const Color secondaryText =
  Color(0xFF777777);

  final MobileHomeController _controller =
  MobileHomeController();

  final PersonalizationController
  _personalizationController =
  PersonalizationController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _controller.addListener(
      _refreshPage,
    );

    _personalizationController.addListener(
      _refreshPage,
    );

    _controller.loadHomeData();
    _personalizationController.loadRecommendations();
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _controller.refresh(),
      _personalizationController
          .refreshRecommendations(),
    ]);
  }

  void _openAiTripPlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiTripPlannerPage(),
      ),
    );
  }

  void _openTransportation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransportationPage(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(
      _refreshPage,
    );

    _personalizationController.removeListener(
      _refreshPage,
    );

    _controller.dispose();
    _personalizationController.dispose();

    super.dispose();
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
        child: RefreshIndicator(
          color: mainGreen,
          onRefresh: _refreshHome,

          child: SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              18,
            ),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                _header(),

                const SizedBox(height: 15),

                _searchBar(),

                const SizedBox(height: 13),

                _heroBanner(),

                const SizedBox(height: 12),

                _quickAccess(),

                const SizedBox(height: 14),

                _sectionHeader(
                  title: 'Recommended for You',
                  onViewAll: () {},
                ),

                const SizedBox(height: 9),

                _recommendationSection(),

                const SizedBox(height: 15),

                _sectionHeader(
                  title:
                  'Sustainable Travel Tips',
                  onViewAll: () {},
                ),

                const SizedBox(height: 9),

                _travelTips(),

                const SizedBox(height: 13),

                _yourImpact(),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 0,

        onHomeTap: () {
          // Already on Home Page.
        },

        onTransportTap: _openTransportation,

        onPlanTripTap: _openAiTripPlanner,

        onCommunityTap: widget.onCommunityTap,

        onProfileTap: widget.onProfileTap,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            // Logo
            Transform.translate(
              offset: const Offset(-7, 0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 55,
                fit: BoxFit.contain,
              ),
            ),

            const Spacer(),

            IconButton(
              visualDensity:
              VisualDensity.compact,
              onPressed: () {},
              icon: const Icon(
                Icons
                    .notifications_none_rounded,
                size: 28,
                color: textColor,
              ),
            ),

            const SizedBox(width: 1),

            GestureDetector(
              onTap: widget.onProfileTap,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: textColor,
                    width: 1.3,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 24,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Hello, ${_displayName()}!',
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              height: 1.1,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(height: 3),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Where will you green journey take you today ?',
            style: TextStyle(
              fontSize: 10.5,
              color: secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  String _displayName() {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 'Explorer';
    }

    final name = user.displayName?.trim();

    if (name != null &&
        name.isNotEmpty) {
      return name.split(' ').first;
    }

    return 'Explorer';
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBar() {
    return InkWell(
      onTap: _openAttractionSearch,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.09,
              ),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.search,
              size: 21,
              color: Color(0xFF999999),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search attractions...',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttractionSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttractionSearchPage(
          personalizationController:
          _personalizationController,
        ),
      ),
    );
  }

  // ============================================================
  // HERO BANNER
  // ============================================================

  Widget _heroBanner() {
    String? imageUrl;

    if (_controller
        .recommendedAttractions
        .isNotEmpty) {
      final first = _controller
          .recommendedAttractions.first;

      if (first.coverImageUrl
          .trim()
          .isNotEmpty) {
        imageUrl =
            first.coverImageUrl;
      } else if (first
          .imageUrls
          .isNotEmpty) {
        imageUrl =
            first.imageUrls.first;
      }
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(11),

      child: SizedBox(
        height: 119,
        width: double.infinity,

        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,

                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return _bannerFallback();
                },
              )
            else
              _bannerFallback(),

            Container(
              decoration:
              const BoxDecoration(
                gradient:
                LinearGradient(
                  begin:
                  Alignment.centerLeft,
                  end:
                  Alignment.centerRight,
                  colors: [
                    Color(
                      0xE6F3FFF4,
                    ),
                    Color(
                      0x88F3FFF4,
                    ),
                    Color(
                      0x00000000,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 13,
              top: 9,
              bottom: 8,
              width: 160,

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.white,
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                    ),
                    child:
                    const Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,
                      children: [
                        Icon(
                          Icons.eco,
                          color:
                          mainGreen,
                          size: 9,
                        ),
                        SizedBox(
                          width: 3,
                        ),
                        Text(
                          "Let's Travel Green!",
                          style:
                          TextStyle(
                            fontSize:
                            6.5,
                            color:
                            mainGreen,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  const Text(
                    'Explore Responsibly,',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      textColor,
                    ),
                  ),

                  const Text(
                    'Travel Sustainably',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      mainGreen,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  const Text(
                    'Discover eco-friendly destinations\nand make a positive impact',
                    maxLines: 2,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: TextStyle(
                      fontSize: 7,
                      height: 1.25,
                      color:
                      secondaryText,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    height: 25,
                    child:
                    ElevatedButton(
                      onPressed:
                      widget
                          .onPlanTripTap,

                      style:
                      ElevatedButton
                          .styleFrom(
                        elevation: 0,
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal:
                          11,
                        ),
                        backgroundColor:
                        mainGreen,
                        foregroundColor:
                        Colors.white,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            6,
                          ),
                        ),
                      ),

                      child:
                      const Row(
                        mainAxisSize:
                        MainAxisSize
                            .min,
                        children: [
                          Text(
                            'Plan Your Trip',
                            style:
                            TextStyle(
                              fontSize:
                              8,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                          SizedBox(
                              width: 4),
                          Icon(
                            Icons
                                .arrow_forward_rounded,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerFallback() {
    return Container(
      decoration:
      const BoxDecoration(
        gradient: LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            Color(0xFFDDEEDF),
            Color(0xFF86B987),
          ],
        ),
      ),
      child: const Align(
        alignment:
        Alignment.centerRight,
        child: Padding(
          padding:
          EdgeInsets.only(
            right: 28,
          ),
          child: Icon(
            Icons.landscape_rounded,
            size: 75,
            color:
            Color(0x77366F38),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACCESS
  // ============================================================

  Widget _quickAccess() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.07,
            ),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [
          Expanded(
            child: _quickItem(
              image:
              'assets/images/court.png',
              title:
              'Cultural &\nHeritage',
              color:
              const Color(
                0xFFEDE0F8,
              ),
              onTap: () {},
            ),
          ),

          Expanded(
            child: _quickItem(
              image:
              'assets/images/eco.png',
              title:
              'My Impact',
              color:
              const Color(
                0xFFE4F4E6,
              ),
              onTap: () {},
            ),
          ),

          Expanded(
            child: _quickItem(
              image:
              'assets/images/visa.png',
              title:
              'Heritage Passport',
              color:
              const Color(
                0xFFEDE5FA,
              ),
              onTap: () {},
            ),
          ),

          Expanded(
            child: _quickItem(
              icon:
              Icons.favorite_border,
              title: 'Saved',
              color:
              const Color(
                0xFFE8F3E9,
              ),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickItem({
    String? image,
    IconData? icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(8),
      onTap: onTap,

      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 2,
        ),

        child: Column(
          children: [
            Container(
              width: 31,
              height: 31,

              padding:
              const EdgeInsets.all(
                6,
              ),

              decoration: BoxDecoration(
                color: color,
                borderRadius:
                BorderRadius.circular(
                  7,
                ),
              ),

              child: image != null
                  ? Image.asset(
                image,
                fit:
                BoxFit.contain,
              )
                  : Icon(
                icon,
                size: 20,
                color:
                mainGreen,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              title,
              textAlign:
              TextAlign.center,
              maxLines: 2,
              overflow:
              TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 7.3,
                height: 1.15,
                color:
                Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader({
    required String title,
    required VoidCallback onViewAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w700,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(width: 8),

        InkWell(
          onTap: onViewAll,
          child: const Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  color: mainGreen,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons
                    .chevron_right_rounded,
                color: mainGreen,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECOMMENDATION
  // ============================================================

  Widget _recommendationSection() {
    if (_controller.isLoading ||
        _personalizationController.isLoadingRecommendations) {
      return const SizedBox(
        height: 99,
        child: Center(
          child:
          CircularProgressIndicator(
            color: mainGreen,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_personalizationController
        .recommendedAttractions
        .isEmpty) {
      return Container(
        height: 90,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            10,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No attraction available yet.',
          style: TextStyle(
            color: secondaryText,
            fontSize: 11,
          ),
        ),
      );
    }

    return SizedBox(
      height: 99,

      child: ListView.separated(
        scrollDirection:
        Axis.horizontal,

        itemCount: _personalizationController
            .recommendedAttractions
            .length,

        separatorBuilder:
            (context, index) =>
        const SizedBox(
          width: 8,
        ),

        itemBuilder:
            (context, index) {
          final attraction =
          _personalizationController
              .recommendedAttractions[
          index];

          return _recommendationCard(
            attraction,
          );
        },
      ),
    );
  }

  Widget _recommendationCard(
      AttractionModel attraction,
      ) {
    String imageUrl = '';

    if (attraction.coverImageUrl
        .trim()
        .isNotEmpty) {
      imageUrl =
          attraction.coverImageUrl;
    } else if (attraction
        .imageUrls
        .isNotEmpty) {
      imageUrl =
          attraction.imageUrls.first;
    }

    return SizedBox(
      width: 112,

      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttractionDetailPage(
                attraction: attraction,
              ),
            ),
          );

          _personalizationController.recordView(
            attraction,
          );
        },

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                7,
              ),

              child: SizedBox(
                width: 112,
                height: 53,

                child: imageUrl.isEmpty
                    ? Container(
                  color:
                  lightGreen,
                  child:
                  const Icon(
                    Icons
                        .landscape_outlined,
                    color:
                    mainGreen,
                  ),
                )
                    : Image.network(
                  imageUrl,
                  fit:
                  BoxFit.cover,

                  errorBuilder:
                      (
                      context,
                      error,
                      stackTrace,
                      ) {
                    return Container(
                      color:
                      lightGreen,
                      child:
                      const Icon(
                        Icons
                            .landscape_outlined,
                        color:
                        mainGreen,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: Text(
                    attraction.name,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                      FontWeight
                          .w600,
                      color:
                      textColor,
                    ),
                  ),
                ),

                const SizedBox(width: 2),

                const Icon(
                  Icons
                      .favorite_border_rounded,
                  size: 12,
                  color:
                  Color(0xFF777777),
                ),
              ],
            ),

            const SizedBox(height: 1),

            Text(
              _attractionLocation(
                attraction,
              ),
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 6.3,
                color:
                secondaryText,
              ),
            ),

            const Spacer(),

            Text(
              attraction.categoryName.isEmpty
                  ? 'Attraction'
                  : attraction.categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 6.5,
                color: mainGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _attractionLocation(
      AttractionModel attraction,
      ) {
    if (attraction.area.isEmpty) {
      return attraction.state;
    }

    return '${attraction.area}, ${attraction.state}';
  }

  // ============================================================
  // TRAVEL TIPS
  // ============================================================

  Widget _travelTips() {
    return Container(
      height: 69,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.07,
            ),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 67,
            height: 53,

            decoration: BoxDecoration(
              color:
              const Color(
                0xFFF0F7EB,
              ),
              borderRadius:
              BorderRadius.circular(
                8,
              ),
            ),

            padding:
            const EdgeInsets.all(
              4,
            ),

            child: Image.asset(
              'assets/images/pack.png',
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [
                Text(
                  'Pack Light, Travel Green',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w600,
                    color: textColor,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Bring reusable items and avoid single-use plastics',
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.25,
                    fontSize: 7,
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

  // ============================================================
  // YOUR IMPACT
  // ============================================================

  Widget _yourImpact() {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),

      decoration: BoxDecoration(
        color:
        const Color(
          0xFFE5F4E6,
        ),

        borderRadius:
        BorderRadius.circular(9),
      ),

      child: Row(
        children: [
          const Expanded(
            flex: 4,

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Your Impact',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: textColor,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                SizedBox(height: 1),

                Text(
                  'This Year',
                  style: TextStyle(
                    fontSize: 6.5,
                    color:
                    secondaryText,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: _impactItem(
              image:
              'assets/images/leaf (1).png',
              value: '12',
              label: 'Trips',
            ),
          ),

          Expanded(
            flex: 3,
            child: _impactItem(
              image:
              'assets/images/tree.png',
              value: '48',
              label: 'kg CO₂ Saved',
            ),
          ),

          Expanded(
            flex: 3,
            child: _impactItem(
              image:
              'assets/images/badge.png',
              value: '620',
              label: 'Eco Points',
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactItem({
    required String image,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        Container(
          width: 27,
          height: 27,

          decoration:
          const BoxDecoration(
            color: mainGreen,
            shape: BoxShape.circle,
          ),

          padding:
          const EdgeInsets.all(
            6,
          ),

          child: Image.asset(
            image,
            fit: BoxFit.contain,

            errorBuilder:
                (
                context,
                error,
                stackTrace,
                ) {
              return const Icon(
                Icons.eco,
                size: 15,
                color: Colors.white,
              );
            },
          ),
        ),

        const SizedBox(width: 4),

        Flexible(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 9,
                  color: textColor,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              Text(
                label,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 5.5,
                  color:
                  secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
