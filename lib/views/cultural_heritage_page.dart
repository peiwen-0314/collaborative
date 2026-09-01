import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_firestore_service.dart';
import '../services/heritage_nearby_service.dart';
import '../widgets/heritage_image.dart';
import 'ai_attraction_recognition_page.dart';
import 'heritage_detail_page.dart';

class CulturalHeritagePage extends StatefulWidget {
  const CulturalHeritagePage({super.key});

  @override
  State<CulturalHeritagePage> createState() => _CulturalHeritagePageState();
}

class _CulturalHeritagePageState extends State<CulturalHeritagePage> {
  static const Color green = Color(0xFF2E8B3C);

  // TEST MODE:
  // This resets only when the app process starts again.
  // Therefore the popup appears once per app run, not every rebuild.
  static bool _popupShownThisRun = false;
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color pageBackground = Color(0xFFFAFAFA);
  static const Color borderColor = Color(0xFFE4E4E4);

  final TextEditingController _searchController =
  TextEditingController();

  final HeritageFirestoreService _firestoreService =
  HeritageFirestoreService();

  final HeritageNearbyService _nearbyService =
  HeritageNearbyService();

  bool _nearbyPopupVisible = false;

  @override
  void initState() {
    super.initState();

    // TEST MODE:
    // Show the nearby popup only ONCE for each full app run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNearbyPopupOncePerRun();
    });
  }

  Future<void> _showNearbyPopupOncePerRun() async {
    if (_popupShownThisRun || !mounted) {
      return;
    }

    _popupShownThisRun = true;

    try {
      // Large test radius so a result can be found from TAR UMT.
      // Results are sorted nearest-first by HeritageNearbyService.
      final results = await _nearbyService.findNearby(
        radiusMeters: 1000000,
      );

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        debugPrint(
          'No heritage attraction available for popup test.',
        );
        return;
      }

      await _showNearbyPopup(results.first);
    } catch (error) {
      debugPrint(
        'Nearby popup test error: $error',
      );
    }
  }

  Future<void> _showNearbyPopup(
      NearbyHeritageResult result,
      ) async {
    if (!mounted || _nearbyPopupVisible) {
      return;
    }

    final route = ModalRoute.of(context);

    if (route != null && !route.isCurrent) {
      return;
    }

    _nearbyPopupVisible = true;

    final attraction = result.attraction;
    final distance = result.distanceMeters.round();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return Dialog(
            elevation: 8,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 26,
              vertical: 30,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 360,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // =====================================================
                  // TOP IMAGE
                  // =====================================================
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/nearby_popup.png',
                          width: double.infinity,
                          height: 165,
                          fit: BoxFit.cover,
                        ),
                      ),

                      Positioned(
                        top: 9,
                        right: 9,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // =====================================================
                  // CONTENT
                  // =====================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      17,
                      14,
                      17,
                      16,
                    ),
                    child: Column(
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${attraction.name}\nis just ',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 17,
                                  height: 1.28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: '$distance m',
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 17,
                                  height: 1.28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' away!',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 17,
                                  height: 1.28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          attraction.shortDescription.isNotEmpty
                              ? attraction.shortDescription
                              : 'A historic landmark nearby. '
                              'Discover its rich history and culture.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // =================================================
                        // DISTANCE + VISIT TIME
                        // =================================================
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2FAF2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD6E8D6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        color: green,
                                        size: 17,
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Distance',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$distance m',
                                        style: const TextStyle(
                                          color: green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              Container(
                                width: 1,
                                height: 54,
                                color: const Color(0xFFD6E8D6),
                              ),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        color: green,
                                        size: 17,
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Est. Visit Time',
                                        style: TextStyle(
                                          color: Color(0xFF777777),
                                          fontSize: 9,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        attraction.recommendedTime.isNotEmpty
                                            ? attraction.recommendedTime
                                            : '1 - 2 hours',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =================================================
                        // BUTTONS
                        // =================================================
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: green,
                                  side: const BorderSide(
                                    color: green,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Maybe Later',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 9),

                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();

                                  if (!mounted) {
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HeritageDetailPage(
                                            attraction: attraction,
                                          ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Explore Now',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _nearbyPopupVisible = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<HeritageAttraction>>(
                stream: _firestoreService.watchAttractions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: green,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load heritage content from Firestore.\n\n'
                              '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }

                  final query =
                  _searchController.text.trim().toLowerCase();

                  final attractions =
                  (snapshot.data ??
                      const <HeritageAttraction>[])
                      .where((attraction) {
                    if (query.isEmpty) {
                      return true;
                    }

                    final searchableText = [
                      attraction.name,
                      attraction.state,
                      attraction.city,
                      attraction.category,
                      ...attraction.aliases,
                    ].join(' ').toLowerCase();

                    return searchableText.contains(query);
                  }).toList();

                  if (attractions.isEmpty) {
                    return const Center(
                      child: Text(
                        'No heritage attraction found.',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding:
                    const EdgeInsets.fromLTRB(
                      14,
                      0,
                      14,
                      24,
                    ),
                    itemCount: attractions.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(
                      height: 10,
                    ),
                    itemBuilder: (context, index) {
                      return _HeritageCard(
                        attraction: attractions[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        6,
        12,
        14,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.black87,
            ),
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cultural & Heritage',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your Journey. Your Story.',
                  style: TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          Material(
            color: paleGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const AiAttractionRecognitionPage(),
                  ),
                );
              },
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: green,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText:
          'Search your locations, heritages or keywords...',
          hintStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 11,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF8B8B8B),
            size: 20,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: green,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERITAGE CARD
// ============================================================

class _HeritageCard extends StatelessWidget {
  const _HeritageCard({
    required this.attraction,
  });

  static const Color green = Color(0xFF2E8B3C);
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color borderColor = Color(0xFFE5E5E5);

  final HeritageAttraction attraction;

  // ============================================================
  // OPEN MAP
  // ============================================================

  Future<void> _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
          '${attraction.latitude},${attraction.longitude}',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeritageDetailPage(
                attraction: attraction,
              ),
            ),
          );
        },

        child: Container(
          height: 116,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),

          child: Row(
            children: [
              // =================================================
              // IMAGE
              // =================================================

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HeritageImage(
                  imageUrl: attraction.imageUrl,
                  width: 74,
                  height: 98,
                ),
              ),

              const SizedBox(width: 10),

              // =================================================
              // INFORMATION
              // =================================================

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),

                    Text(
                      attraction.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Category
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: paleGreen,
                        borderRadius:
                        BorderRadius.circular(4),
                      ),
                      child: Text(
                        attraction.category,
                        style: const TextStyle(
                          color: green,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // A little more space
                    const SizedBox(height: 5),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 11,
                          color: Color(0xFF777777),
                        ),

                        const SizedBox(width: 3),

                        Expanded(
                          child: Text(
                            attraction.locationText,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:
                              Color(0xFF777777),
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Opening hours
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          size: 10,
                          color: Color(0xFF777777),
                        ),

                        const SizedBox(width: 3),

                        Expanded(
                          child: Text(
                            'Opening Hours: ${attraction.openingHours}',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:
                              Color(0xFF777777),
                              fontSize: 7.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // =================================================
              // MINI MAP
              // =================================================

              GestureDetector(
                onTap: _openMap,
                child: Container(
                  width: 70,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF0F5F2,
                    ),
                    borderRadius:
                    BorderRadius.circular(2),
                    border: Border.all(
                      color: const Color(
                        0xFFE6E6E6,
                      ),
                    ),
                  ),

                  child: Stack(
                    children: [
                      // Horizontal road
                      Positioned(
                        left: 6,
                        right: -5,
                        top: 18,
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            height: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Vertical road
                      Positioned(
                        left: 28,
                        top: -5,
                        child: Transform.rotate(
                          angle: 0.15,
                          child: Container(
                            width: 2,
                            height: 65,
                            color: const Color(
                              0xFFD9E6EA,
                            ),
                          ),
                        ),
                      ),

                      // Pin
                      const Center(
                        child: Padding(
                          padding:
                          EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: green,
                            size: 19,
                          ),
                        ),
                      ),

                      // View map label
                      Positioned(
                        left: 5,
                        right: 5,
                        bottom: 5,
                        child: Container(
                          height: 12,
                          alignment:
                          Alignment.center,
                          decoration:
                          BoxDecoration(
                            color:
                            Colors.white,
                            borderRadius:
                            BorderRadius
                                .circular(
                              6,
                            ),
                            boxShadow:
                            const [
                              BoxShadow(
                                color:
                                Color(
                                  0x18000000,
                                ),
                                blurRadius:
                                2,
                              ),
                            ],
                          ),
                          child: const Text(
                            'View On Map',
                            style: TextStyle(
                              fontSize: 6,
                              color:
                              Colors.black87,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}