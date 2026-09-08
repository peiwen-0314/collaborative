import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import '../services/saved_attractions_service.dart';
import 'attraction_detail_page.dart';

class SavedAttractionsPage extends StatefulWidget {
  const SavedAttractionsPage({super.key});

  @override
  State<SavedAttractionsPage> createState() =>
      _SavedAttractionsPageState();
}

class _SavedAttractionsPageState extends State<SavedAttractionsPage> {
  static const Color green = Color(0xFF2E8B3C);
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color pageBackground = Color(0xFFFAFAFA);
  static const Color borderColor = Color(0xFFE4E4E4);
  static const Color secondaryText = Color(0xFF777777);

  final SavedAttractionsService _savedService =
      SavedAttractionsService.instance;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

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
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _savedService.watchSavedAttractions(),
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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Unable to load saved attractions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }

                  final savedDocs = snapshot.data?.docs ?? [];

                  if (savedDocs.isEmpty) {
                    return _emptyState();
                  }

                  return FutureBuilder<List<AttractionModel>>(
                    future: _loadSavedAttractions(savedDocs),
                    builder: (context, attractionSnapshot) {
                      if (attractionSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: green,
                          ),
                        );
                      }

                      final query =
                      _searchQuery.trim().toLowerCase();

                      final attractions =
                      (attractionSnapshot.data ??
                          const <AttractionModel>[])
                          .where((attraction) {
                        if (query.isEmpty) {
                          return true;
                        }

                        final searchableText = [
                          attraction.name,
                          attraction.state,
                          attraction.area,
                          attraction.categoryName,
                          ...attraction.categoryNames,
                        ].join(' ').toLowerCase();

                        return searchableText.contains(query);
                      }).toList();

                      if (attractions.isEmpty) {
                        return const Center(
                          child: Text(
                            'No saved attraction found.',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          24,
                        ),
                        itemCount: attractions.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _SavedAttractionCard(
                            attraction: attractions[index],
                            onRemove: () async {
                              await _savedService.remove(
                                attractions[index].id,
                              );

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    backgroundColor: green,
                                    content: Text(
                                      '${attractions[index].name} removed from saved.',
                                    ),
                                  ),
                                );
                            },
                          );
                        },
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
      padding: const EdgeInsets.fromLTRB(
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
                  'Saved Attractions',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your favourite places, all in one list.',
                  style: TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 10,
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
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText:
          'Search saved attractions, locations or categories...',
          hintStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 11,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF8B8B8B),
            size: 20,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();

              setState(() {
                _searchQuery = '';
              });
            },
            icon: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF8B8B8B),
            ),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
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

  // ============================================================
  // LOAD LATEST ATTRACTIONS
  // ============================================================

  Future<List<AttractionModel>> _loadSavedAttractions(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> savedDocs,
      ) async {
    final attractions = <AttractionModel>[];

    for (final savedDoc in savedDocs) {
      final data = savedDoc.data();

      final attractionId =
      (data['attractionId'] ?? savedDoc.id)
          .toString()
          .trim();

      if (attractionId.isEmpty) {
        continue;
      }

      try {
        final attractionDoc = await FirebaseFirestore.instance
            .collection('attractions')
            .doc(attractionId)
            .get();

        if (!attractionDoc.exists) {
          continue;
        }

        attractions.add(
          AttractionModel.fromFirestore(
            attractionDoc,
          ),
        );
      } catch (_) {
        // Skip any attraction that can no longer be loaded.
      }
    }

    return attractions;
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 35,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: paleGreen,
              child: Icon(
                Icons.favorite_border_rounded,
                size: 32,
                color: green,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'No saved attractions yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Tap the heart icon beside an attraction to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SAVED ATTRACTION CARD
// ============================================================

class _SavedAttractionCard extends StatelessWidget {
  const _SavedAttractionCard({
    required this.attraction,
    required this.onRemove,
  });

  final AttractionModel attraction;
  final VoidCallback onRemove;

  static const Color green = Color(0xFF2E8B3C);
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color borderColor = Color(0xFFE5E5E5);
  static const Color secondaryText = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttractionDetailPage(
                attraction: attraction,
              ),
            ),
          );
        },
        child: Container(
          height: 126,
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
                child: SizedBox(
                  width: 74,
                  height: 98,
                  child: imageUrl.isEmpty
                      ? _imageFallback()
                      : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return _imageFallback();
                    },
                  ),
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            attraction.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Multiple category tags
                    SizedBox(
                      height: 18,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories().length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 4),
                        itemBuilder: (context, index) {
                          return _categoryChip(
                            _categories()[index],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 11,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _locationText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Rating
                    _ratingRow(),

                    const SizedBox(height: 4),

                    // Opening hours
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _openingHoursText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 8,
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
      ),
    );
  }

  String _imageUrl() {
    if (attraction.coverImageUrl.trim().isNotEmpty) {
      return attraction.coverImageUrl.trim();
    }

    if (attraction.imageUrls.isNotEmpty) {
      return attraction.imageUrls.first;
    }

    return '';
  }

  Widget _imageFallback() {
    return Container(
      color: paleGreen,
      child: const Icon(
        Icons.landscape_outlined,
        color: green,
      ),
    );
  }

  List<String> _categories() {
    final categories = attraction.categoryNames
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    if (categories.isNotEmpty) {
      return categories;
    }

    final primary = attraction.categoryName.trim();

    if (primary.isNotEmpty) {
      return [primary];
    }

    return ['Attraction'];
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC8E6C9),
          width: 0.7,
        ),
      ),
      child: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 6.2,
          color: green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _locationText() {
    return [
      attraction.area,
      attraction.state,
    ]
        .where(
          (part) => part.trim().isNotEmpty,
    )
        .join(', ');
  }

  String _openingHoursText() {
    final openingHours = attraction.openingHours;

    // If every day is empty, treat the attraction as open all day.
    final hasAnyHours = openingHours.values.any(
          (periods) => periods.any(
            (period) => period.trim().isNotEmpty,
      ),
    );

    if (!hasAnyHours) {
      return 'Opening Hours: All Day';
    }

    const weekdayKeys = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final todayKey = weekdayKeys[DateTime.now().weekday - 1];

    List<String> todayPeriods = const [];

    for (final entry in openingHours.entries) {
      if (entry.key.trim().toLowerCase() == todayKey) {
        todayPeriods = entry.value
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
        break;
      }
    }

    if (todayPeriods.isEmpty ||
        todayPeriods.every(
              (value) => value.toLowerCase() == 'closed',
        )) {
      return 'Opening Hours: Closed Today';
    }

    return 'Opening Hours: ${todayPeriods.join(', ')}';
  }

  Widget _ratingRow() {
    return AnimatedBuilder(
      animation: AttractionReviewsService.instance,
      builder: (context, _) {
        final service =
            AttractionReviewsService.instance;

        final rating =
        service.averageRatingFor(
          attraction.id,
        );

        final reviewCount =
        service.reviewCountFor(
          attraction.id,
        );

        return Row(
          children: [
            Icon(
              rating > 0
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 11,
              color: rating > 0
                  ? const Color(0xFFFFB300)
                  : Colors.black38,
            ),

            const SizedBox(width: 3),

            Text(
              rating == 0
                  ? 'Not rated yet'
                  : rating.toStringAsFixed(1),
              style: TextStyle(
                color: rating > 0
                    ? Colors.black87
                    : Colors.black54,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(width: 5),

            Text(
              reviewCount == 0
                  ? '(0 reviews)'
                  : '($reviewCount review${reviewCount == 1 ? '' : 's'})',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 7.2,
              ),
            ),
          ],
        );
      },
    );
  }

  String _savedHint() {
    if (attraction.area.trim().isNotEmpty) {
      return attraction.area.trim();
    }

    if (attraction.state.trim().isNotEmpty) {
      return attraction.state.trim();
    }

    return 'EcoTravel';
  }
}
