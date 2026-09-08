import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controllers/personalization_controller.dart';
import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import 'attraction_detail_page.dart';

class AttractionSearchPage extends StatefulWidget {
  final PersonalizationController
  personalizationController;

  /// When true, this page is opened from Home > Recommended for You > View All.
  /// It first displays only the user's recommendations. Once the user types a
  /// search keyword, the search runs across ALL active attractions.
  final bool showRecommendationsInitially;

  const AttractionSearchPage({
    super.key,
    required this.personalizationController,
    this.showRecommendationsInitially = false,
  });

  @override
  State<AttractionSearchPage> createState() =>
      _AttractionSearchPageState();
}

class _AttractionSearchPageState
    extends State<AttractionSearchPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);
  static const Color lightGreen =
  Color(0xFFE8F5E9);
  static const Color pageBackground =
  Color(0xFFF8FAF8);
  static const Color textColor =
  Color(0xFF212121);
  static const Color secondaryText =
  Color(0xFF777777);
  static const Color borderColor =
  Color(0xFFE2E6E2);

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';
  String? _selectedCategoryId;
  String? _selectedState;
  String? _selectedArea;
  String _feeFilter = 'All';

  List<AttractionModel> _allAttractions = [];
  List<AttractionModel> _filteredAttractions = [];

  /// Current Active categories from Firestore.
  /// Inactive / Deleted categories are never shown, searched or filtered.
  final Map<String, String> _activeCategories = {};

  bool _hasRecordedCurrentSearch = false;

  @override
  void initState() {
    super.initState();

    widget.personalizationController.addListener(
      _controllerChanged,
    );

    _loadActiveCategories();
  }

  @override
  void dispose() {
    widget.personalizationController.removeListener(
      _controllerChanged,
    );

    _searchController.dispose();
    super.dispose();
  }

  void _controllerChanged() {
    if (!mounted) {
      return;
    }

    _syncAttractions();
  }

  Future<void> _loadActiveCategories() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance
          .collection('categories')
          .get();

      final active = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final status =
        (data['status'] ?? 'Active')
            .toString()
            .trim()
            .toLowerCase();

        if (status != 'active') {
          continue;
        }

        final name =
        (data['name'] ?? '')
            .toString()
            .trim();

        if (name.isNotEmpty) {
          active[doc.id] = name;
        }
      }

      if (!mounted) return;

      setState(() {
        _activeCategories
          ..clear()
          ..addAll(active);
      });

      _syncAttractions();
    } catch (e) {
      debugPrint(
        'Load active categories in AttractionSearchPage error: $e',
      );

      if (!mounted) return;

      // Fail closed: if category status cannot be verified,
      // do not expose stale category tags.
      setState(() {
        _activeCategories.clear();
      });

      _syncAttractions();
    }
  }

  void _syncAttractions() {
    final source = List<AttractionModel>.from(
      widget.personalizationController
          .allActiveAttractions,
    );

    final sanitized = <AttractionModel>[];

    for (final attraction in source) {
      // Extra protection: user page only shows Active attractions.
      if (attraction.status.trim().toLowerCase() != 'active') {
        continue;
      }

      final clean =
      _sanitizeAttractionCategories(
        attraction,
      );

      // No Active categories left = do not show to user.
      if (clean.categoryIds.isEmpty) {
        continue;
      }

      sanitized.add(clean);
    }

    _allAttractions = sanitized;

    if (_selectedCategoryId != null &&
        !_activeCategories.containsKey(
          _selectedCategoryId,
        )) {
      _selectedCategoryId = null;
    }

    _applyFilters(
      recordSearch: false,
    );
  }

  AttractionModel _sanitizeAttractionCategories(
      AttractionModel attraction,
      ) {
    final ids = <String>[];

    for (final rawId in attraction.categoryIds) {
      final id = rawId.trim();

      if (id.isNotEmpty && !ids.contains(id)) {
        ids.add(id);
      }
    }

    final oldPrimaryId =
    attraction.categoryId.trim();

    if (oldPrimaryId.isNotEmpty &&
        !ids.contains(oldPrimaryId)) {
      ids.insert(0, oldPrimaryId);
    }

    final activeIds = <String>[];
    final activeNames = <String>[];

    for (final id in ids) {
      final activeName =
      _activeCategories[id];

      if (activeName == null) {
        // Inactive / Deleted -> skip it completely.
        continue;
      }

      activeIds.add(id);
      activeNames.add(activeName);
    }

    if (activeIds.isEmpty) {
      return attraction.copyWith(
        categoryId: '',
        categoryName: '',
        categoryIds: const <String>[],
        categoryNames: const <String>[],
      );
    }

    final newPrimaryId =
    activeIds.contains(oldPrimaryId)
        ? oldPrimaryId
        : activeIds.first;

    final newPrimaryName =
        _activeCategories[newPrimaryId] ??
            activeNames.first;

    return attraction.copyWith(
      categoryId: newPrimaryId,
      categoryName: newPrimaryName,
      categoryIds: activeIds,
      categoryNames: activeNames,
    );
  }

  List<_FilterOption> get _categories {
    // IMPORTANT:
    // Show ALL Active categories from Firestore here,
    // even if a category currently has zero attractions.
    final result = _activeCategories.entries
        .map(
          (entry) => _FilterOption(
        id: entry.key,
        label: entry.value,
      ),
    )
        .toList();

    result.sort(
          (a, b) => a.label
          .toLowerCase()
          .compareTo(
        b.label.toLowerCase(),
      ),
    );

    return result;
  }

  List<String> get _states {
    final values = _allAttractions
        .map((item) => item.state.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort(
          (a, b) => a
          .toLowerCase()
          .compareTo(b.toLowerCase()),
    );

    return values;
  }

  List<String> get _areas {
    Iterable<AttractionModel> source =
        _allAttractions;

    if (_selectedState != null) {
      source = source.where(
            (item) =>
        item.state.trim() ==
            _selectedState,
      );
    }

    final values = source
        .map((item) => item.area.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort(
          (a, b) => a
          .toLowerCase()
          .compareTo(b.toLowerCase()),
    );

    return values;
  }

  void _applyFilters({
    bool recordSearch = false,
  }) {
    final keyword =
    _searchText.trim().toLowerCase();

    // If this page was opened from "Recommended for You":
    // - no keyword: show only recommended attractions;
    // - keyword entered: search ALL active attractions.
    final List<AttractionModel> source;

    if (widget.showRecommendationsInitially &&
        keyword.isEmpty) {
      source = List<AttractionModel>.from(
        widget.personalizationController
            .recommendedAttractions,
      );
    } else {
      source =
      List<AttractionModel>.from(
        _allAttractions,
      );
    }

    final result = source.where(
          (attraction) {
        final searchableText = [
          attraction.name,
          attraction.categoryName,
          ...attraction.categoryNames,
          attraction.state,
          attraction.area,
          attraction.description,
          attraction.address,
          ...attraction.highlights,
          ...attraction.facilities,
        ].join(' ').toLowerCase();

        final matchesSearch =
            keyword.isEmpty ||
                searchableText
                    .contains(keyword);

        final matchesCategory =
            _selectedCategoryId == null ||
                attraction.categoryId ==
                    _selectedCategoryId ||
                attraction.categoryIds
                    .contains(
                  _selectedCategoryId,
                );

        final matchesState =
            _selectedState == null ||
                attraction.state.trim() ==
                    _selectedState;

        final matchesArea =
            _selectedArea == null ||
                attraction.area.trim() ==
                    _selectedArea;

        final matchesFee =
            _feeFilter == 'All' ||
                (_feeFilter == 'Free' &&
                    attraction.isFreeEntry) ||
                (_feeFilter == 'Paid' &&
                    !attraction.isFreeEntry);

        return matchesSearch &&
            matchesCategory &&
            matchesState &&
            matchesArea &&
            matchesFee;
      },
    ).toList();

    // Keep recommendation ranking/order when no search has been entered.
    // Normal search results remain alphabetical.
    if (!(widget.showRecommendationsInitially &&
        keyword.isEmpty)) {
      result.sort(
            (a, b) => a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _filteredAttractions = result;
      });
    } else {
      _filteredAttractions = result;
    }

    if (recordSearch &&
        keyword.isNotEmpty) {
      widget.personalizationController
          .recordSearch(
        query: _searchText.trim(),
        matchedAttractions: result,
      );

      _hasRecordedCurrentSearch = true;
    }
  }

  void _submitSearch(String value) {
    _searchText = value.trim();
    _hasRecordedCurrentSearch = false;

    _applyFilters(
      recordSearch:
      _searchText.isNotEmpty,
    );
  }

  void _onSearchChanged(String value) {
    _searchText = value;
    _hasRecordedCurrentSearch = false;

    // Filter visually while typing, but do not
    // write behavioral scores for every keystroke.
    _applyFilters(
      recordSearch: false,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchText = '';
    _hasRecordedCurrentSearch = false;

    _applyFilters(
      recordSearch: false,
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedState = null;
      _selectedArea = null;
      _feeFilter = 'All';
    });

    _applyFilters(
      recordSearch: false,
    );
  }

  void _openAttraction(
      AttractionModel attraction,
      ) {
    // If the user typed a query but tapped a
    // result without pressing Enter/Search,
    // count that search once at this point.
    if (_searchText.trim().isNotEmpty &&
        !_hasRecordedCurrentSearch) {
      widget.personalizationController
          .recordSearch(
        query: _searchText.trim(),
        matchedAttractions:
        _filteredAttractions,
      );

      _hasRecordedCurrentSearch = true;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AttractionDetailPage(
              attraction: attraction,
            ),
      ),
    );

    // Personalization runs in background.
    widget.personalizationController
        .recordView(attraction);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget
        .personalizationController
        .isLoadingRecommendations &&
        _allAttractions.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: mainGreen,
                  ),
                ),
              )
            else ...[
              _topSection(),
              Expanded(
                child: _resultSection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    final String title =
    widget.showRecommendationsInitially
        ? 'Recommended for You'
        : 'Explore Attractions';

    final String subtitle =
    widget.showRecommendationsInitially
        ? 'Personalised places selected for you.'
        : 'Discover places, experiences and hidden gems.';

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
            onPressed: () =>
                Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.black87,
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
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

  Widget _topSection() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.fromLTRB(
        14,
        2,
        14,
        10,
      ),
      child: Column(
        children: [
          _searchBar(),
          const SizedBox(height: 10),
          _filterRow(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      autofocus:
      !widget.showRecommendationsInitially,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      onSubmitted: _submitSearch,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
      decoration: InputDecoration(
        hintText:
        'Search attractions, locations or categories...',
        hintStyle: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 11,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF8B8B8B),
          size: 20,
        ),
        suffixIcon:
        _searchController.text.isEmpty
            ? null
            : IconButton(
          onPressed: _clearSearch,
          icon: const Icon(
            Icons.close,
            size: 18,
            color:
            Color(0xFF8B8B8B),
          ),
        ),
        filled: true,
        fillColor:
        const Color(0xFFF5F5F5),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: mainGreen,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _filterRow() {
    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterButton(
            label: _categoryLabel(),
            isActive:
            _selectedCategoryId != null,
            onTap: _showCategoryFilter,
          ),
          const SizedBox(width: 8),
          _filterButton(
            label:
            _selectedState ?? 'State',
            isActive:
            _selectedState != null,
            onTap: _showStateFilter,
          ),
          const SizedBox(width: 8),
          _filterButton(
            label:
            _selectedArea ?? 'Area',
            isActive:
            _selectedArea != null,
            onTap: _showAreaFilter,
          ),
          const SizedBox(width: 8),
          _filterButton(
            label: _feeFilter == 'All'
                ? 'Entry Fee'
                : _feeFilter,
            isActive:
            _feeFilter != 'All',
            onTap: _showFeeFilter,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _resetFilters,
              style: TextButton.styleFrom(
                foregroundColor:
                mainGreen,
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 8,
                ),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
          _selectedState != null ||
          _selectedArea != null ||
          _feeFilter != 'All';

  String _categoryLabel() {
    if (_selectedCategoryId == null) {
      return 'Category';
    }

    for (final category in _categories) {
      if (category.id ==
          _selectedCategoryId) {
        return category.label;
      }
    }

    return 'Category';
  }

  Widget _filterButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(20),
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? lightGreen
              : Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? mainGreen
                : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 120,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isActive
                      ? mainGreen
                      : textColor,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons
                  .keyboard_arrow_down_rounded,
              size: 15,
              color: isActive
                  ? mainGreen
                  : secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultSection() {
    return RefreshIndicator(
      color: mainGreen,
      onRefresh: () async {
        await widget
            .personalizationController
            .refreshRecommendations();

        await _loadActiveCategories();

        if (!mounted) return;

        _syncAttractions();
      },
      child: CustomScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchText
                          .trim()
                          .isNotEmpty
                          ? 'Search Results'
                          : widget.showRecommendationsInitially
                          ? 'Recommended for You'
                          : 'All Attractions',
                      style:
                      const TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    '${_filteredAttractions.length} found',
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
          ),
          if (_filteredAttractions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(),
            )
          else
            SliverPadding(
              padding:
              const EdgeInsets.fromLTRB(
                14,
                0,
                14,
                24,
              ),
              sliver:
              SliverList.separated(
                itemCount:
                _filteredAttractions
                    .length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 10,
                ),
                itemBuilder:
                    (context, index) {
                  return _attractionCard(
                    _filteredAttractions[
                    index],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _attractionCard(
      AttractionModel attraction,
      ) {
    final imageUrl =
    attraction.coverImageUrl
        .trim()
        .isNotEmpty
        ? attraction.coverImageUrl.trim()
        : attraction.imageUrls.isNotEmpty
        ? attraction.imageUrls.first
        : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () =>
            _openAttraction(attraction),
        borderRadius:
        BorderRadius.circular(9),
        child: Container(
          constraints:
          const BoxConstraints(
            minHeight: 116,
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(9),
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
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // =================================================
              // IMAGE
              // =================================================
              ClipRRect(
                borderRadius:
                BorderRadius.circular(8),
                child: SizedBox(
                  width: 74,
                  height: 98,
                  child: imageUrl.isEmpty
                      ? _imageFallback()
                      : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) =>
                        _imageFallback(),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // =================================================
              // INFORMATION
              // =================================================
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),

                    Text(
                      attraction.name,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Same category tag design as Home.
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                      _categoryTags(
                        attraction,
                      )
                          .map(
                        _categoryChip,
                      )
                          .toList(),
                    ),

                    const SizedBox(height: 5),

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
                            _location(
                              attraction,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              secondaryText,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    _ratingRow(
                      attraction.id,
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .access_time_filled,
                          size: 10,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _openingHours(
                              attraction,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              secondaryText,
                              fontSize: 7.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          attraction.isFreeEntry
                              ? 'Free'
                              : _startingFee(
                            attraction,
                          ),
                          style:
                          const TextStyle(
                            fontSize: 8,
                            color: mainGreen,
                            fontWeight:
                            FontWeight.w700,
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

  Widget _ratingRow(
      String attractionId,
      ) {
    return AnimatedBuilder(
      animation:
      AttractionReviewsService.instance,
      builder: (context, _) {
        final service =
            AttractionReviewsService.instance;

        final double rating =
        service.averageRatingFor(
          attractionId,
        );

        final int reviewCount =
        service.reviewCountFor(
          attractionId,
        );

        return Row(
          children: [
            Icon(
              rating > 0
                  ? Icons.star_rounded
                  : Icons
                  .star_border_rounded,
              size: 11,
              color: rating > 0
                  ? const Color(
                0xFFFFB300,
              )
                  : Colors.black38,
            ),
            const SizedBox(width: 3),
            Text(
              rating > 0
                  ? rating.toStringAsFixed(1)
                  : 'Not rated yet',
              style: TextStyle(
                fontSize: 8,
                color: rating > 0
                    ? Colors.black87
                    : secondaryText,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              reviewCount == 0
                  ? '(0 reviews)'
                  : '($reviewCount review${reviewCount == 1 ? '' : 's'})',
              style: const TextStyle(
                fontSize: 7.2,
                color: secondaryText,
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _categoryTags(
      AttractionModel attraction,
      ) {
    final tags = attraction.categoryNames
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    if (tags.isNotEmpty) {
      return tags;
    }

    final primary =
    attraction.categoryName.trim();

    if (primary.isNotEmpty) {
      return [primary];
    }

    return ['Attraction'];
  }

  Widget _categoryChip(
      String category,
      ) {
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
          color: mainGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: lightGreen,
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_outlined,
        color: mainGreen,
        size: 28,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color:
              Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 12),
            const Text(
              'No attractions found',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Try another keyword or change the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                _searchText = '';
                _resetFilters();
              },
              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                mainGreen,
                side: const BorderSide(
                  color: mainGreen,
                ),
              ),
              child:
              const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryFilter() async {
    final selected =
    await _showOptionSheet<String?>(
      title: 'Category',
      currentValue:
      _selectedCategoryId,
      options: [
        const _SheetOption<String?>(
          value: null,
          label: 'All Categories',
        ),
        ..._categories.map(
              (item) =>
              _SheetOption<String?>(
                value: item.id,
                label: item.label,
              ),
        ),
      ],
    );

    if (!mounted) return;

    setState(() {
      _selectedCategoryId = selected;
    });

    _applyFilters();
  }

  Future<void> _showStateFilter() async {
    final selected =
    await _showOptionSheet<String?>(
      title: 'State',
      currentValue: _selectedState,
      options: [
        const _SheetOption<String?>(
          value: null,
          label: 'All States',
        ),
        ..._states.map(
              (state) =>
              _SheetOption<String?>(
                value: state,
                label: state,
              ),
        ),
      ],
    );

    if (!mounted) return;

    setState(() {
      _selectedState = selected;

      if (_selectedArea != null &&
          !_areas.contains(
            _selectedArea,
          )) {
        _selectedArea = null;
      }
    });

    _applyFilters();
  }

  Future<void> _showAreaFilter() async {
    final selected =
    await _showOptionSheet<String?>(
      title: 'Area',
      currentValue: _selectedArea,
      options: [
        const _SheetOption<String?>(
          value: null,
          label: 'All Areas',
        ),
        ..._areas.map(
              (area) =>
              _SheetOption<String?>(
                value: area,
                label: area,
              ),
        ),
      ],
    );

    if (!mounted) return;

    setState(() {
      _selectedArea = selected;
    });

    _applyFilters();
  }

  Future<void> _showFeeFilter() async {
    final selected =
    await _showOptionSheet<String>(
      title: 'Entry Fee',
      currentValue: _feeFilter,
      options: const [
        _SheetOption<String>(
          value: 'All',
          label: 'All Entry Fees',
        ),
        _SheetOption<String>(
          value: 'Free',
          label: 'Free Entry',
        ),
        _SheetOption<String>(
          value: 'Paid',
          label: 'Paid Entry',
        ),
      ],
    );

    if (!mounted ||
        selected == null) {
      return;
    }

    setState(() {
      _feeFilter = selected;
    });

    _applyFilters();
  }

  Future<T?> _showOptionSheet<T>({
    required String title,
    required T currentValue,
    required List<_SheetOption<T>>
    options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor:
      Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.sizeOf(
                context,
              ).height *
                  0.65,
            ),
            decoration:
            const BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.vertical(
                top: Radius.circular(
                  22,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Padding(
                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    20,
                    18,
                    12,
                    10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                          const TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight
                                .w700,
                            color:
                            textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(
                              context,
                            ),
                        icon: const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                ),
                Flexible(
                  child:
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount:
                    options.length,
                    itemBuilder:
                        (context, index) {
                      final option =
                      options[index];

                      final selected =
                          option.value ==
                              currentValue;

                      return ListTile(
                        onTap: () =>
                            Navigator.pop(
                              context,
                              option.value,
                            ),
                        title: Text(
                          option.label,
                          style:
                          TextStyle(
                            fontSize: 13,
                            color: selected
                                ? mainGreen
                                : textColor,
                            fontWeight:
                            selected
                                ? FontWeight
                                .w600
                                : FontWeight
                                .w400,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                          Icons
                              .check_rounded,
                          color:
                          mainGreen,
                        )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _location(
      AttractionModel attraction,
      ) {
    final area =
    attraction.area.trim();
    final state =
    attraction.state.trim();

    if (area.isEmpty) {
      return state;
    }

    if (state.isEmpty) {
      return area;
    }

    return '$area, $state';
  }

  String _openingHours(
      AttractionModel attraction,
      ) {
    if (attraction.isOpen24Hours) {
      return 'Opening Hours: All Day';
    }

    final hasWeeklyHours =
    attraction.openingHours.values.any(
          (periods) => periods.any(
            (period) =>
        period.trim().isNotEmpty &&
            period.trim().toLowerCase() !=
                'closed',
      ),
    );

    if (!hasWeeklyHours) {
      return 'Opening Hours: All Day';
    }

    const weekdayKeys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final todayKey =
    weekdayKeys[DateTime.now().weekday - 1];

    List<String> periods = const [];

    for (final entry
    in attraction.openingHours.entries) {
      if (entry.key.trim().toLowerCase() ==
          todayKey) {
        periods = entry.value
            .map((value) => value.trim())
            .where(
              (value) =>
          value.isNotEmpty &&
              value.toLowerCase() !=
                  'closed',
        )
            .toList();
        break;
      }
    }

    if (periods.isEmpty) {
      return 'Opening Hours: Closed Today';
    }

    return 'Opening Hours: ${periods.join(', ')}';
  }

  String _startingFee(
      AttractionModel attraction,
      ) {
    final fee =
        attraction.malaysianAdultFee;

    if (fee <= 0) {
      return 'View rates';
    }

    final value = fee % 1 == 0
        ? fee.toInt().toString()
        : fee.toStringAsFixed(2);

    return 'From MYR $value';
  }
}

class _FilterOption {
  final String id;
  final String label;

  const _FilterOption({
    required this.id,
    required this.label,
  });
}

class _SheetOption<T> {
  final T value;
  final String label;

  const _SheetOption({
    required this.value,
    required this.label,
  });
}
