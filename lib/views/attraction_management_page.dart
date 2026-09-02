import 'package:flutter/material.dart';

import '../controllers/attraction_controller.dart';
import '../models/attraction.dart';
import 'add_attraction_page.dart';
import 'bulk_attraction_import_page.dart';
import 'admin_sidebar.dart';
import 'admin_heritage_management_page.dart';
import 'category_management_page.dart';
import 'edit_attraction_page.dart';

class AttractionManagementPage extends StatefulWidget {
  const AttractionManagementPage({super.key});

  @override
  State<AttractionManagementPage> createState() =>
      _AttractionManagementPageState();
}

class _AttractionManagementPageState
    extends State<AttractionManagementPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF667085);

  final AttractionController _controller = AttractionController();
  final TextEditingController _searchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(
      _refreshPage,
    );

    _controller.loadData();
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    _controller.removeListener(
      _refreshPage,
    );

    _controller.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      body: Row(
        children: [
          // =====================================================
          // SIDEBAR
          // =====================================================

          AdminSidebar(
            selectedPage: 'attraction',

            onDashboardTap: () {
              Navigator.popUntil(
                context,
                    (route) => route.isFirst,
              );
            },

            onAttractionTap: () {},

            onCategoryTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const CategoryManagementPage(),
                ),
              );
            },

            onCulturalHeritageTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const AdminCulturalHeritageManagementPage(),
                ),
              );
            },

            onStampTap: () {},

            onReportTap: () {},

            onLogoutTap: () {
              Navigator.popUntil(
                context,
                    (route) => route.isFirst,
              );
            },
          ),

          // =====================================================
          // MAIN CONTENT
          // =====================================================

          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(
                    28,
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      _pageHeader(),

                      const SizedBox(
                        height: 22,
                      ),

                      _statistics(),

                      const SizedBox(
                        height: 20,
                      ),

                      _filterBar(),

                      _attractionTable(),
                    ],
                  ),
                ),

                if (_controller.isProcessing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,

                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: mainGreen,
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
  // HEADER
  // SAME HEIGHT / STYLE AS CATEGORY MANAGEMENT
  // ============================================================

  Widget _pageHeader() {
    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final bool compact =
            constraints.maxWidth < 760;

        final Widget title = const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Attraction Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'View, add, import, edit or remove attraction details.',
              style: TextStyle(
                fontSize: 13,
                color: secondaryText,
              ),
            ),
          ],
        );

        final Widget importButton =
        OutlinedButton(
          onPressed: _controller.isProcessing
              ? null
              : _openBulkImport,
          style: OutlinedButton.styleFrom(
            foregroundColor: mainGreen,
            side: const BorderSide(
              color: mainGreen,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(7),
            ),
          ),
          child: const Text(
            'Import Attractions',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        final Widget coordinateButton =
        OutlinedButton.icon(
          onPressed: _controller.isProcessing
              ? null
              : _generateMissingCoordinates,
          style: OutlinedButton.styleFrom(
            foregroundColor: mainGreen,
            side: const BorderSide(
              color: mainGreen,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(7),
            ),
          ),
          icon: const Icon(
            Icons.add_location_alt_outlined,
            size: 18,
          ),
          label: const Text(
            'Generate Coordinates',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        final Widget addButton =
        ElevatedButton(
          onPressed: _controller.isProcessing
              ? null
              : _openAddAttraction,
          style: ElevatedButton.styleFrom(
            backgroundColor: mainGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(7),
            ),
          ),
          child: const Text(
            'Add New Attraction',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  coordinateButton,
                  importButton,
                  addButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: title,
            ),
            coordinateButton,
            const SizedBox(width: 10),
            importButton,
            const SizedBox(width: 10),
            addButton,
          ],
        );
      },
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _statistics() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border: Border.all(
          color: borderColor,
        ),
      ),

      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          if (constraints.maxWidth < 900) {
            return Wrap(
              spacing: 20,
              runSpacing: 18,

              children: [
                SizedBox(
                  width:
                  constraints.maxWidth <
                      560
                      ? constraints.maxWidth
                      : (constraints.maxWidth -
                      20) /
                      2,

                  child: _statItem(
                    icon:
                    Icons.place_outlined,

                    title:
                    'Total Attractions',

                    value:
                    '${_controller.totalAttractions}',

                    description:
                    'All attractions',

                    color:
                    mainGreen,
                  ),
                ),

                SizedBox(
                  width:
                  constraints.maxWidth <
                      560
                      ? constraints.maxWidth
                      : (constraints.maxWidth -
                      20) /
                      2,

                  child: _statItem(
                    icon:
                    Icons.check_circle_outline,

                    title:
                    'Active Attractions',

                    value:
                    '${_controller.activeAttractions}',

                    description:
                    'Currently active',

                    color:
                    const Color(
                      0xFF15803D,
                    ),
                  ),
                ),

                SizedBox(
                  width:
                  constraints.maxWidth <
                      560
                      ? constraints.maxWidth
                      : (constraints.maxWidth -
                      20) /
                      2,

                  child: _statItem(
                    icon:
                    Icons.visibility_off_outlined,

                    title:
                    'Inactive Attractions',

                    value:
                    '${_controller.inactiveAttractions}',

                    description:
                    'Currently inactive',

                    color:
                    const Color(
                      0xFFF59E0B,
                    ),
                  ),
                ),

                SizedBox(
                  width:
                  constraints.maxWidth <
                      560
                      ? constraints.maxWidth
                      : (constraints.maxWidth -
                      20) /
                      2,

                  child: _statItem(
                    icon:
                    Icons.category_outlined,

                    title:
                    'Categories Used',

                    value:
                    '${_controller.totalCategories}',

                    description:
                    'Across attractions',

                    color:
                    const Color(
                      0xFF2563EB,
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _statItem(
                  icon:
                  Icons.place_outlined,

                  title:
                  'Total Attractions',

                  value:
                  '${_controller.totalAttractions}',

                  description:
                  'All attractions',

                  color:
                  mainGreen,
                ),
              ),

              _divider(),

              Expanded(
                child: _statItem(
                  icon:
                  Icons.check_circle_outline,

                  title:
                  'Active Attractions',

                  value:
                  '${_controller.activeAttractions}',

                  description:
                  'Currently active',

                  color:
                  const Color(
                    0xFF15803D,
                  ),
                ),
              ),

              _divider(),

              Expanded(
                child: _statItem(
                  icon:
                  Icons.visibility_off_outlined,

                  title:
                  'Inactive Attractions',

                  value:
                  '${_controller.inactiveAttractions}',

                  description:
                  'Currently inactive',

                  color:
                  const Color(
                    0xFFF59E0B,
                  ),
                ),
              ),

              _divider(),

              Expanded(
                child: _statItem(
                  icon:
                  Icons.category_outlined,

                  title:
                  'Categories Used',

                  value:
                  '${_controller.totalCategories}',

                  description:
                  'Across attractions',

                  color:
                  const Color(
                    0xFF2563EB,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 55,
          height: 55,

          decoration: BoxDecoration(
            color:
            color.withOpacity(
              0.10,
            ),

            shape:
            BoxShape.circle,
          ),

          child: Icon(
            icon,
            color: color,
          ),
        ),

        const SizedBox(
          width: 14,
        ),

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
                ),
              ),

              Text(
                value,

                style:
                const TextStyle(
                  fontSize: 24,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              Text(
                description,

                style:
                const TextStyle(
                  fontSize: 10,

                  color:
                  Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 70,

      margin:
      const EdgeInsets.symmetric(
        horizontal: 20,
      ),

      color:
      borderColor,
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _filterBar() {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        const BorderRadius.vertical(
          top:
          Radius.circular(
            10,
          ),
        ),

        border:
        Border.all(
          color:
          borderColor,
        ),
      ),

      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final bool compact =
              constraints.maxWidth < 900;

          final Widget search =
          TextField(
            controller:
            _searchController,

            onChanged:
            _controller
                .setSearchQuery,

            decoration:
            InputDecoration(
              hintText:
              'Search attraction, state, area or category...',

              prefixIcon:
              const Icon(
                Icons.search,
              ),

              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  7,
                ),

                borderSide:
                const BorderSide(
                  color:
                  Color(
                    0xFFD0D5DD,
                  ),
                ),
              ),

              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  7,
                ),

                borderSide:
                const BorderSide(
                  color:
                  mainGreen,
                ),
              ),
            ),
          );

          final Widget category =
          DropdownButtonFormField<
              String>(
            value:
            _controller
                .selectedCategory,

            isExpanded:
            true,

            decoration:
            _dropdownDecoration(),

            items: [
              const DropdownMenuItem<
                  String>(
                value:
                'All Categories',

                child:
                Text(
                  'All Categories',

                  overflow:
                  TextOverflow
                      .ellipsis,
                ),
              ),

              ..._controller
                  .categories
                  .map(
                    (item) {
                  return DropdownMenuItem<
                      String>(
                    value:
                    item.id,

                    child:
                    Text(
                      item.name,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  );
                },
              ),
            ],

            onChanged:
                (value) {
              if (value !=
                  null) {
                _controller
                    .setCategory(
                  value,
                );
              }
            },
          );

          final Widget status =
          DropdownButtonFormField<
              String>(
            value:
            _controller
                .selectedStatus,

            isExpanded:
            true,

            decoration:
            _dropdownDecoration(),

            items:
            const [
              DropdownMenuItem(
                value:
                'All Status',

                child:
                Text(
                  'All Status',
                ),
              ),

              DropdownMenuItem(
                value:
                'Active',

                child:
                Text(
                  'Active',
                ),
              ),

              DropdownMenuItem(
                value:
                'Inactive',

                child:
                Text(
                  'Inactive',
                ),
              ),
            ],

            onChanged:
                (value) {
              if (value !=
                  null) {
                _controller
                    .setStatus(
                  value,
                );
              }
            },
          );

          final Widget reset =
          OutlinedButton.icon(
            onPressed: () {
              _searchController
                  .clear();

              _controller
                  .resetFilter();
            },

            icon:
            const Icon(
              Icons.refresh,
            ),

            label:
            const Text(
              'Reset',
            ),
          );

          if (compact) {
            return Column(
              children: [
                search,

                const SizedBox(
                  height: 12,
                ),

                category,

                const SizedBox(
                  height: 12,
                ),

                status,

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  width:
                  double.infinity,

                  child:
                  reset,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,

                child:
                search,
              ),

              const SizedBox(
                width: 14,
              ),

              SizedBox(
                width: 230,

                child:
                category,
              ),

              const SizedBox(
                width: 14,
              ),

              SizedBox(
                width: 230,

                child:
                status,
              ),

              const Spacer(),

              reset,
            ],
          );
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),

        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFD0D5DD,
          ),
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),

        borderSide:
        const BorderSide(
          color:
          mainGreen,
        ),
      ),
    );
  }

  // ============================================================
  // ATTRACTION TABLE
  // ============================================================

  Widget _attractionTable() {
    if (_controller.isLoading) {
      return Container(
        height: 300,

        color:
        Colors.white,

        child:
        const Center(
          child:
          Column(
            mainAxisAlignment:
            MainAxisAlignment
                .center,

            children: [
              CircularProgressIndicator(
                color:
                mainGreen,
              ),

              SizedBox(
                height: 14,
              ),

              Text(
                'Loading attractions...',

                style:
                TextStyle(
                  color:
                  secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<AttractionModel>
    attractions =
        _controller
            .paginatedAttractions;

    return Container(
      width:
      double.infinity,

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        border:
        Border.all(
          color:
          borderColor,
        ),
      ),

      child:
      Column(
        children: [
          LayoutBuilder(
            builder: (
                context,
                constraints,
                ) {
              if (constraints.maxWidth <
                  1050) {
                return SingleChildScrollView(
                  scrollDirection:
                  Axis.horizontal,

                  child:
                  SizedBox(
                    width:
                    1050,

                    child:
                    _tableContent(
                      attractions,
                    ),
                  ),
                );
              }

              return _tableContent(
                attractions,
              );
            },
          ),

          _pagination(),
        ],
      ),
    );
  }

  Widget _tableContent(
      List<AttractionModel> attractions,
      ) {
    return Column(
      children: [
        _tableHeader(),

        if (attractions.isEmpty)
          const Padding(
            padding:
            EdgeInsets.all(
              50,
            ),

            child:
            Column(
              children: [
                Icon(
                  Icons.place_outlined,

                  size:
                  45,

                  color:
                  Colors.grey,
                ),

                SizedBox(
                  height:
                  10,
                ),

                Text(
                  'No attractions found.',
                ),
              ],
            ),
          ),

        ...attractions.map(
              (attraction) {
            return _attractionRow(
              attraction,
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _tableHeader() {
    return Container(
      height:
      55,

      padding:
      const EdgeInsets.symmetric(
        horizontal:
        18,
      ),

      color:
      const Color(
        0xFFFAFAFA,
      ),

      child:
      const Row(
        children: [
          Expanded(
            flex:
            3,

            child:
            Text(
              'Attraction',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex:
            2,

            child:
            Text(
              'Category',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex:
            2,

            child:
            Text(
              'Location',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex:
            2,

            child:
            Text(
              'Entry Fee',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child:
            Text(
              'Status',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          SizedBox(
            width:
            110,

            child:
            Text(
              'Actions',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTRACTION ROW
  // ============================================================

  Widget _attractionRow(
      AttractionModel attraction,
      ) {
    final Color statusColor =
    attraction.status ==
        'Active'
        ? const Color(
      0xFF15803D,
    )
        : const Color(
      0xFFDC2626,
    );

    // ==========================================================
    // IMAGE URL
    // ==========================================================

    final String displayImageUrl =
    attraction.coverImageUrl
        .trim()
        .isNotEmpty
        ? attraction
        .coverImageUrl
        .trim()
        : attraction
        .imageUrls
        .isNotEmpty
        ? attraction
        .imageUrls
        .first
        .trim()
        : '';

    debugPrint(
      '======================================',
    );

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        18,

        vertical:
        14,
      ),

      decoration:
      const BoxDecoration(
        border:
        Border(
          top:
          BorderSide(
            color:
            borderColor,
          ),
        ),
      ),

      child:
      Row(
        children: [
          // =====================================================
          // ATTRACTION
          // =====================================================

          Expanded(
            flex:
            3,

            child:
            Row(
              children: [
                _attractionImage(
                  displayImageUrl,
                ),

                const SizedBox(
                  width:
                  12,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [
                      Text(
                        attraction.name,

                        maxLines:
                        1,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),

                      const SizedBox(
                        height:
                        3,
                      ),

                      Text(
                        attraction
                            .description,

                        maxLines:
                        1,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(
                          fontSize:
                          11,

                          color:
                          secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // CATEGORY
          // =====================================================

          Expanded(
            flex:
            2,

            child:
            Text(
              attraction.categoryName,

              maxLines:
              1,

              overflow:
              TextOverflow.ellipsis,
            ),
          ),

          // =====================================================
          // LOCATION
          // =====================================================

          Expanded(
            flex:
            2,

            child:
            Text(
              '${attraction.area}, ${attraction.state}',

              maxLines:
              2,

              overflow:
              TextOverflow.ellipsis,
            ),
          ),

          // =====================================================
          // ENTRY FEE
          // =====================================================

          Expanded(
            flex:
            2,

            child:
            attraction.isFreeEntry
                ? const Text(
              'Free Entry',

              style:
              TextStyle(
                color:
                mainGreen,

                fontWeight:
                FontWeight
                    .w600,
              ),
            )
                : Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  'MY Adult: RM ${attraction.malaysianAdultFee.toStringAsFixed(2)}',

                  style:
                  const TextStyle(
                    fontSize:
                    11,
                  ),
                ),

                const SizedBox(
                  height:
                  3,
                ),

                Text(
                  'Non-MY Adult: RM ${attraction.nonMalaysianAdultFee.toStringAsFixed(2)}',

                  style:
                  const TextStyle(
                    fontSize:
                    11,

                    color:
                    secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // STATUS
          // =====================================================

          Expanded(
            child:
            Align(
              alignment:
              Alignment.centerLeft,

              child:
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  10,

                  vertical:
                  5,
                ),

                decoration:
                BoxDecoration(
                  color:
                  statusColor.withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                Text(
                  attraction.status,

                  style:
                  TextStyle(
                    color:
                    statusColor,
                  ),
                ),
              ),
            ),
          ),

          // =====================================================
          // ACTIONS
          // =====================================================

          SizedBox(
            width:
            110,

            child:
            Row(
              children: [
                IconButton(
                  tooltip:
                  'Edit Attraction',

                  onPressed:
                  _controller.isProcessing
                      ? null
                      : () {
                    _openEditAttraction(
                      attraction,
                    );
                  },

                  icon:
                  const Icon(
                    Icons.edit_outlined,

                    color:
                    mainGreen,
                  ),
                ),

                IconButton(
                  tooltip:
                  'Delete Attraction',

                  onPressed:
                  _controller.isProcessing
                      ? null
                      : () {
                    _showDeleteDialog(
                      attraction,
                    );
                  },

                  icon:
                  const Icon(
                    Icons.delete_outline,

                    color:
                    Colors.red,
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
  // IMAGE WIDGET
  // ============================================================

  Widget _attractionImage(
      String imageUrl,
      ) {
    if (imageUrl.isEmpty) {

      return Container(
        width:
        56,

        height:
        48,

        decoration:
        BoxDecoration(
          color:
          const Color(
            0xFFF2F4F7,
          ),

          borderRadius:
          BorderRadius.circular(
            7,
          ),
        ),

        alignment:
        Alignment.center,

        child:
        const Icon(
          Icons.image_outlined,

          color:
          secondaryText,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        7,
      ),

      child:
      Image.network(
        imageUrl,

        width:
        56,

        height:
        48,

        fit:
        BoxFit.cover,

        loadingBuilder: (
            context,
            child,
            loadingProgress,
            ) {
          if (loadingProgress ==
              null) {

            return child;
          }

          return Container(
            width:
            56,

            height:
            48,

            color:
            const Color(
              0xFFF2F4F7,
            ),

            alignment:
            Alignment.center,

            child:
            const SizedBox(
              width:
              18,

              height:
              18,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2,

                color:
                mainGreen,
              ),
            ),
          );
        },

        errorBuilder: (
            context,
            error,
            stackTrace,
            ) {

          return Container(
            width:
            56,

            height:
            48,

            color:
            const Color(
              0xFFF2F4F7,
            ),

            alignment:
            Alignment.center,

            child:
            const Icon(
              Icons.broken_image_outlined,

              color:
              Colors.red,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  Widget _pagination() {
    final int total =
        _controller
            .filteredAttractions
            .length;

    final int start =
    total == 0
        ? 0
        : ((_controller.currentPage -
        1) *
        _controller.itemsPerPage) +
        1;

    final int end =
    total == 0
        ? 0
        : (start +
        _controller
            .paginatedAttractions
            .length -
        1) >
        total
        ? total
        : start +
        _controller
            .paginatedAttractions
            .length -
        1;

    return Padding(
      padding:
      const EdgeInsets.all(
        18,
      ),

      child:
      LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final bool compact =
              constraints.maxWidth < 600;

          final Widget info =
          Text(
            'Showing $start to $end of $total results',
          );

          final Widget buttons =
          Row(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              IconButton(
                onPressed:
                _controller.currentPage >
                    1
                    ? _controller.previousPage
                    : null,

                icon:
                const Icon(
                  Icons.chevron_left,
                ),
              ),

              for (int page = 1;
              page <=
                  _controller.totalPages;
              page++)
                if (page <= 5)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      3,
                    ),

                    child:
                    _pageButton(
                      page,
                    ),
                  ),

              IconButton(
                onPressed:
                _controller.currentPage <
                    _controller.totalPages
                    ? _controller.nextPage
                    : null,

                icon:
                const Icon(
                  Icons.chevron_right,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                info,

                const SizedBox(
                  height:
                  10,
                ),

                buttons,
              ],
            );
          }

          return Row(
            children: [
              info,

              const Spacer(),

              buttons,
            ],
          );
        },
      ),
    );
  }

  Widget _pageButton(
      int page,
      ) {
    final bool selected =
        page ==
            _controller.currentPage;

    return InkWell(
      onTap: () {
        _controller
            .goToPage(
          page,
        );
      },

      child:
      Container(
        width:
        36,

        height:
        36,

        decoration:
        BoxDecoration(
          color:
          selected
              ? mainGreen
              : Colors.white,

          borderRadius:
          BorderRadius.circular(
            6,
          ),

          border:
          Border.all(
            color:
            selected
                ? mainGreen
                : const Color(
              0xFFD0D5DD,
            ),
          ),
        ),

        child:
        Center(
          child:
          Text(
            '$page',

            style:
            TextStyle(
              color:
              selected
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GENERATE MISSING COORDINATES WITH HERE API
  // ============================================================

  Future<void> _generateMissingCoordinates() async {
    if (!_controller.isHereConfigured) {
      _showMessage(
        'HERE API key is missing. Run the app with '
            '--dart-define=HERE_API_KEY=YOUR_KEY.',
        isError: true,
      );
      return;
    }

    final int missingCount = _controller.attractions
        .where(
          (item) =>
      item.latitude == 0 || item.longitude == 0,
    )
        .length;

    if (missingCount == 0) {
      _showMessage(
        'All attractions already have coordinates.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                color: mainGreen,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Generate Coordinates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '$missingCount attraction${missingCount == 1 ? '' : 's'} '
                'do not have coordinates. HERE Geocoding will use each '
                'attraction name and address to generate latitude and longitude.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final result =
      await _controller.geocodeAllMissingAttractions();

      if (!mounted) return;

      _showMessage(
        'Coordinates completed: '
            '${result['updated'] ?? 0} updated, '
            '${result['failed'] ?? 0} failed, '
            '${result['skipped'] ?? 0} skipped.',
        isError: (result['failed'] ?? 0) > 0 &&
            (result['updated'] ?? 0) == 0,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to generate coordinates: $error',
        isError: true,
      );
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? Colors.red.shade700 : mainGreen,
      ),
    );
  }

  // ============================================================
  // BULK IMPORT
  // ============================================================

  Future<void> _openBulkImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const BulkAttractionImportPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.loadData();
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _openAddAttraction() async {
    final bool? result =
    await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (context) =>
        const AddAttractionPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _controller
          .loadData();
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _openEditAttraction(
      AttractionModel attraction,
      ) async {
    final bool? result =
    await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (context) =>
            EditAttractionPage(
              attraction:
              attraction,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _controller
          .loadData();
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  void _showDeleteDialog(
      AttractionModel attraction,
      ) {
    bool isDeleting =
    false;

    showDialog(
      context:
      context,

      barrierDismissible:
      false,

      builder:
          (dialogContext) {
        return StatefulBuilder(
          builder: (
              dialogContext,
              setDialogState,
              ) {
            return AlertDialog(
              backgroundColor:
              Colors.white,

              title:
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,

                    color:
                    Colors.red,

                    size:
                    32,
                  ),

                  SizedBox(
                    width:
                    10,
                  ),

                  Text(
                    'Delete Attraction',
                  ),
                ],
              ),

              content:
              Text(
                'Are you sure you want to delete "${attraction.name}"?',
              ),

              actions: [
                SizedBox(
                  width:
                  110,

                  height:
                  45,

                  child:
                  OutlinedButton(
                    onPressed:
                    isDeleting
                        ? null
                        : () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },

                    child:
                    const Text(
                      'Cancel',
                    ),
                  ),
                ),

                SizedBox(
                  width:
                  110,

                  height:
                  45,

                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.red,

                      foregroundColor:
                      Colors.white,
                    ),

                    onPressed:
                    isDeleting
                        ? null
                        : () async {
                      setDialogState(
                            () {
                          isDeleting =
                          true;
                        },
                      );

                      final bool success =
                      await _controller
                          .deleteAttraction(
                        attraction,
                      );

                      if (!mounted) {
                        return;
                      }

                      if (!success) {
                        setDialogState(
                              () {
                            isDeleting =
                            false;
                          },
                        );

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content:
                            Text(
                              'Failed to delete attraction.',
                            ),
                          ),
                        );

                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );

                      await _controller
                          .loadData();

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            'Attraction deleted successfully.',
                          ),
                        ),
                      );
                    },

                    child:
                    isDeleting
                        ? const SizedBox(
                      width:
                      20,

                      height:
                      20,

                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2.5,

                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Delete',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
