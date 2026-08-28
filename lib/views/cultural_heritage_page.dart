import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/heritage_data.dart';
import '../models/heritage_attraction.dart';
import 'ai_attraction_recognition_page.dart';
import 'heritage_detail_page.dart';
import 'heritage_diary_page.dart';
import 'nearby_heritage_page.dart';

class CulturalHeritagePage extends StatefulWidget {
  const CulturalHeritagePage({super.key});

  @override
  State<CulturalHeritagePage> createState() => _CulturalHeritagePageState();
}

class _CulturalHeritagePageState extends State<CulturalHeritagePage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFDDF4D8);

  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 1) {
      return _Shell(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _setIndex,
        child: const AiAttractionRecognitionPage(embedded: true),
      );
    }
    if (_selectedIndex == 2) {
      return _Shell(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _setIndex,
        child: const HeritageDiaryPage(embedded: true),
      );
    }
    if (_selectedIndex == 3) {
      return _Shell(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _setIndex,
        child: const NearbyHeritagePage(embedded: true),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final attractions = HeritageData.attractions.where((attraction) {
      if (query.isEmpty) return true;
      final haystack = [
        attraction.name,
        attraction.state,
        attraction.city,
        attraction.category,
        ...attraction.aliases,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 51),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cultural & Heritage',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Your Journey. Your Story.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: lightGreen,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _setIndex(1),
                                child: const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    color: green,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search your locations, heritages or keywords...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 12,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF7A7A7A),
                              size: 21,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFE5E5E5),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 19),
                      ]),
                    ),
                  ),
                  if (attractions.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No heritage attraction found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      sliver: SliverList.separated(
                        itemCount: attractions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) => _HeritageCard(
                          attraction: attractions[index],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _ModuleNavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _setIndex,
            ),
          ],
        ),
      ),
    );
  }

  void _setIndex(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: child),
            _ModuleNavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleNavigationBar extends StatelessWidget {
  const _ModuleNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 64,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: const Color(0xFF111111),
      indicatorColor: const Color(0xFFDDF4D8),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.account_balance_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.account_balance, color: Color(0xFF2E7D32)),
          label: 'Heritage',
        ),
        NavigationDestination(
          icon: Icon(Icons.center_focus_strong, color: Colors.white70),
          selectedIcon: Icon(Icons.center_focus_strong, color: Color(0xFF2E7D32)),
          label: 'Recognise',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.auto_stories, color: Color(0xFF2E7D32)),
          label: 'Diary',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.location_on, color: Color(0xFF2E7D32)),
          label: 'Nearby',
        ),
      ],
    );
  }
}

class _HeritageCard extends StatelessWidget {
  const _HeritageCard({required this.attraction});

  static const Color green = Color(0xFF2E7D32);
  static const Color tagGreen = Color(0xFF499453);
  static const Color lightGreen = Color(0xFFE5F5E4);

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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeritageDetailPage(attraction: attraction),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: SizedBox(
            height: 120,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    attraction.imageAsset,
                    width: 86,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        attraction.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          attraction.category,
                          style: const TextStyle(
                            color: tagGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: Color(0xFF676767),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              attraction.locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Color(0xFF676767),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            size: 11,
                            color: Color(0xFF676767),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Opening Hours: ${attraction.openingHours}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 7.5,
                                color: Color(0xFF676767),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                InkWell(
                  onTap: _openMap,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(7),
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
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF3AA54A),
                          size: 25,
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: const Text(
                              'View On Map',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 6.5,
                                color: Colors.black87,
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
      ),
    );
  }
}
