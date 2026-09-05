import 'package:flutter/material.dart';

import '../controllers/personalization_controller.dart';
import '../models/attraction.dart';
import 'attraction_detail_page.dart';

class AttractionSearchPage extends StatefulWidget {
  final PersonalizationController
  personalizationController;

  const AttractionSearchPage({
    super.key,
    required this.personalizationController,
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

  bool _hasRecordedCurrentSearch = false;

  @override
  void initState() {
    super.initState();

    widget.personalizationController.addListener(
      _controllerChanged,
    );

    _syncAttractions();
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

    final latest = widget
        .personalizationController
        .allActiveAttractions;

    if (latest.length != _allAttractions.length) {
      _syncAttractions();
    }
  }

  void _syncAttractions() {
    _allAttractions = List<AttractionModel>.from(
      widget.personalizationController
          .allActiveAttractions,
    );

    _applyFilters(
      recordSearch: false,
    );
  }

  List<_FilterOption> get _categories {
    final map = <String, String>{};

    for (final attraction in _allAttractions) {
      final id = attraction.categoryId.trim();
      final name =
      attraction.categoryName.trim();

      if (id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }

    final result = map.entries
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

    final result = _allAttractions.where(
          (attraction) {
        final searchableText = [
          attraction.name,
          attraction.categoryName,
          attraction.state,
          attraction.area,
          attraction.description,
          attraction.address,
          ...attraction.highlights,
          ...attraction.facilities,
        ].join(' ').toLowerCase();

        final matchesSearch =
            keyword.isEmpty ||
                searchableText.contains(keyword);

        final matchesCategory =
            _selectedCategoryId == null ||
                attraction.categoryId ==
                    _selectedCategoryId;

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

    result.sort(
          (a, b) => a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      ),
    );

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
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: textColor,
          ),
        ),
        title: const Text(
          'Explore Attractions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child:
          CircularProgressIndicator(
            color: mainGreen,
          ),
        )
            : Column(
          children: [
            _topSection(),
            Expanded(
              child: _resultSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        14,
      ),
      child: Column(
        children: [
          _searchBar(),
          const SizedBox(height: 12),
          _filterRow(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius:
        BorderRadius.circular(11),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction:
        TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: _submitSearch,
        style: const TextStyle(
          fontSize: 12,
          color: textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 21,
            color: Color(0xFF999999),
          ),
          hintText:
          'Search attraction, category or location...',
          hintStyle: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFFAAAAAA),
          ),
          suffixIcon:
          _searchController.text.isEmpty
              ? null
              : IconButton(
            onPressed: _clearSearch,
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color:
              secondaryText,
            ),
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
                18,
                17,
                18,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchText
                          .trim()
                          .isEmpty
                          ? 'All Attractions'
                          : 'Search Results',
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
                18,
                0,
                18,
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
        ? attraction.coverImageUrl
        .trim()
        : attraction
        .imageUrls.isNotEmpty
        ? attraction
        .imageUrls.first
        : '';

    return Material(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(12),
      child: InkWell(
        onTap: () =>
            _openAttraction(attraction),
        borderRadius:
        BorderRadius.circular(12),
        child: Container(
          padding:
          const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  9,
                ),
                child: SizedBox(
                  width: 96,
                  height: 96,
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
              const SizedBox(width: 11),
              Expanded(
                child: SizedBox(
                  height: 96,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        attraction.name,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight:
                          FontWeight
                              .w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        _location(
                          attraction,
                        ),
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 9,
                          color:
                          secondaryText,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        attraction
                            .categoryName
                            .trim()
                            .isEmpty
                            ? 'Attraction'
                            : attraction
                            .categoryName,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 8.5,
                          color: mainGreen,
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
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
                                fontSize: 8,
                                color:
                                secondaryText,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            attraction
                                .isFreeEntry
                                ? 'Free'
                                : _startingFee(
                              attraction,
                            ),
                            style:
                            const TextStyle(
                              fontSize: 9,
                              color:
                              mainGreen,
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                        ],
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
    final open =
    attraction.openingTime.trim();
    final close =
    attraction.closingTime.trim();

    if (open.isEmpty ||
        close.isEmpty) {
      return 'Hours unavailable';
    }

    return '$open - $close';
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
