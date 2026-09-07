import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import '../services/community_content_service.dart';
import '../widgets/community_section_switcher.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/heritage_image.dart';
import 'ai_trip_planner_page.dart';
import 'attraction_reviews_page.dart';
import 'community_feed_page.dart';
import 'home_page.dart';
import 'ride_home_page.dart';

/// Entry point for the attraction-reviews feature: lists active attractions
/// from Firestore, searchable and filterable by category. Attractions
/// are ordered by their current average rating. Tapping one opens
/// [AttractionReviewsPage].
class AttractionReviewsListPage extends StatefulWidget {
  const AttractionReviewsListPage({super.key});

  @override
  State<AttractionReviewsListPage> createState() =>
      _AttractionReviewsListPageState();
}

class _AttractionReviewsListPageState
    extends State<AttractionReviewsListPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE7F5E5);

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<String> get _categories {
    final set = <String>{'All'};
    set.addAll(CommunityContentService.instance.activeCategoryNames);
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    CommunityContentService.instance.start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _openTransport() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TransportationPage()),
    );
  }

  void _openPlanTrip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AiTripPlannerPage()),
    );
  }

  void _openCommunity() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CommunityFeedPage()),
    );
  }

  void _showComingSoon(String page) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$page coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Attraction Reviews',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          CommunitySectionSwitcher(
            showingReviews: true,
            onCommunityTap: _openCommunity,
            onReviewsTap: () {},
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(
                () => _searchQuery = value.trim().toLowerCase(),
              ),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search attractions',
                prefixIcon: const Icon(Icons.search, color: green),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE1E5DF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE1E5DF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: green, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  selectedColor: paleGreen,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: green,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  side: const BorderSide(color: green),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                AttractionReviewsService.instance,
                CommunityContentService.instance,
              ]),
              builder: (context, _) {
                final service = AttractionReviewsService.instance;
                final contentService = CommunityContentService.instance;

                if (contentService.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: green),
                  );
                }

                if (contentService.errorMessage != null &&
                    contentService.attractions.isEmpty) {
                  return _FirebaseError(
                    message: contentService.errorMessage!,
                    onRetry: contentService.retry,
                  );
                }

                final attractions = contentService.attractions.where(
                  (attraction) {
                    final matchesCategory = _selectedCategory == 'All' ||
                        attraction.categoryName.trim().toLowerCase() ==
                            _selectedCategory.toLowerCase();
                    final searchableText = [
                      attraction.name,
                      attraction.categoryName,
                      attraction.area,
                      attraction.state,
                    ].join(' ').toLowerCase();
                    final matchesSearch = _searchQuery.isEmpty ||
                        searchableText.contains(_searchQuery);
                    return matchesCategory && matchesSearch;
                  },
                ).toList()
                  ..sort((a, b) {
                    final ratingComparison = service
                        .averageRatingFor(b.id)
                        .compareTo(service.averageRatingFor(a.id));
                    if (ratingComparison != 0) return ratingComparison;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                if (attractions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No attractions in this category.'
                            : 'No attractions match your search.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  itemCount: attractions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final attraction = attractions[index];
                    final count = AttractionReviewsService.instance
                        .reviewCountFor(attraction.id);
                    final rating = AttractionReviewsService.instance
                        .averageRatingFor(attraction.id);
                    return _AttractionCard(
                      attraction: attraction,
                      reviewCount: count,
                      averageRating: rating,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 3,
        onHomeTap: _openHome,
        onTransportTap: _openTransport,
        onPlanTripTap: _openPlanTrip,
        onCommunityTap: _openCommunity,
        onProfileTap: () => _showComingSoon('Profile'),
      ),
    );
  }
}

class _AttractionCard extends StatelessWidget {
  const _AttractionCard({
    required this.attraction,
    required this.reviewCount,
    required this.averageRating,
  });

  final AttractionModel attraction;
  final int reviewCount;
  final double averageRating;

  static const Color green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttractionReviewsPage(attraction: attraction),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E5DF)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: HeritageImage(
                imageUrl: attraction.coverImageUrl,
                width: 88,
                height: 88,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [attraction.area, attraction.state]
                          .where((part) => part.trim().isNotEmpty)
                          .join(', '),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          averageRating > 0
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 15,
                          color: averageRating > 0
                              ? const Color(0xFFFFB300)
                              : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          averageRating == 0
                              ? 'Not rated yet'
                              : averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: averageRating > 0
                                ? Colors.black87
                                : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          reviewCount == 0
                              ? '(0 reviews)'
                              : '($reviewCount review${reviewCount == 1 ? '' : 's'})',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseError extends StatelessWidget {
  const _FirebaseError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
