import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_firestore_service.dart';
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
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color pageBackground = Color(0xFFFAFAFA);
  static const Color borderColor = Color(0xFFE4E4E4);

  final TextEditingController _searchController = TextEditingController();
  final HeritageFirestoreService _firestoreService = HeritageFirestoreService();

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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: green),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load heritage content from Firestore.\n\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }

                  final query = _searchController.text.trim().toLowerCase();
                  final attractions = (snapshot.data ?? const <HeritageAttraction>[])
                      .where((attraction) {
                    if (query.isEmpty) return true;
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: attractions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _HeritageCard(attraction: attractions[index]);
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 14, 8),
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
                    builder: (_) => const AiAttractionRecognitionPage(),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText: 'Search your locations, heritages or keywords...',
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: green, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _HeritageCard extends StatelessWidget {
  const _HeritageCard({required this.attraction});

  static const Color green = Color(0xFF2E8B3C);
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color borderColor = Color(0xFFE5E5E5);

  final HeritageAttraction attraction;

  Future<void> _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
          '${attraction.latitude},${attraction.longitude}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              builder: (_) => HeritageDetailPage(attraction: attraction),
            ),
          );
        },
        child: Container(
          height: 116,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HeritageImage(
                  imageUrl: attraction.imageUrl,
                  width: 74,
                  height: 98,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
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
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: paleGreen,
                        borderRadius: BorderRadius.circular(4),
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
                    const Spacer(),
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 7.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openMap,
                child: Container(
                  width: 68,
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: borderColor),
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/heritage/map_placeholder.jpg',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      const Icon(
                        Icons.location_on,
                        color: green,
                        size: 23,
                      ),
                      Positioned(
                        left: 5,
                        right: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE2E2E2),
                            ),
                          ),
                          child: const Text(
                            'View On Map',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 5.8,
                              fontWeight: FontWeight.w500,
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
