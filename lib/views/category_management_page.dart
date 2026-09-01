import 'package:flutter/material.dart';

import '../controllers/category_controller.dart';
import '../models/category.dart';
import 'admin_sidebar.dart';
import 'attraction_management_page.dart';

class CategoryManagementPage
    extends StatefulWidget {
  const CategoryManagementPage({
    super.key,
  });

  @override
  State<CategoryManagementPage>
  createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends State<CategoryManagementPage> {
  static const Color mainGreen =
  Color(0xFF0B6B2B);

  static const Color pageBackground =
  Color(0xFFF7F8FA);

  final CategoryController
  _categoryController =
  CategoryController();

  final TextEditingController
  _searchController =
  TextEditingController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _categoryController.addListener(
      _refreshPage,
    );

    _categoryController
        .loadCategories();
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();

    _categoryController.removeListener(
      _refreshPage,
    );

    _categoryController.dispose();

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
            selectedPage: 'category',

            onDashboardTap: () {
              Navigator.pop(context);
            },

            onAttractionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttractionManagementPage(),
                ),
              );
            },

            onCategoryTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManagementPage(),
                ),
              );
            },

            onStampTap: () {},

            onReportTap: () {},

            onLogoutTap: () {
              Navigator.popUntil(
                context,
                    (route) =>
                route.isFirst,
              );
            },
          ),

          // =====================================================
          // MAIN CONTENT
          // =====================================================

          Expanded(
            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets.all(
                28,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

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

                  _categoryTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _pageHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,

            children: [
              Text(
                'Category Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Color(0xFF111827),
                ),
              ),

              SizedBox(height: 5),

              Text(
                'View, add, edit or remove attraction categories.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                  Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // ADD BUTTON
        // ======================================================

        ElevatedButton.icon(
          onPressed:
          _categoryController
              .isOperationLoading
              ? null
              : _showAddCategoryDialog,

          icon:
          const Icon(
            Icons.add,
            size: 20,
          ),

          label:
          const Text(
            'Add New Category',
          ),

          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            mainGreen,

            foregroundColor:
            Colors.white,

            elevation: 0,

            padding:
            const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                7,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _statistics() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),

      decoration:
      BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFE5E7EB,
          ),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child:
            _statItem(
              icon: Icons
                  .grid_view_outlined,

              title:
              'Total Categories',

              value:
              '${_categoryController.totalCategories}',

              description:
              'All categories',

              color:
              mainGreen,
            ),
          ),

          _divider(),

          Expanded(
            child:
            _statItem(
              icon: Icons
                  .check_circle_outline,

              title:
              'Active Categories',

              value:
              '${_categoryController.activeCategories}',

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
            child:
            _statItem(
              icon: Icons
                  .visibility_off_outlined,

              title:
              'Inactive Categories',

              value:
              '${_categoryController.inactiveCategories}',

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
            child:
            _statItem(
              icon: Icons
                  .sell_outlined,

              title:
              'Total Attractions',

              value:
              '${_categoryController.totalAttractions}',

              description:
              'Across all categories',

              color:
              const Color(
                0xFF2563EB,
              ),
            ),
          ),
        ],
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

          decoration:
          BoxDecoration(
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
            CrossAxisAlignment
                .start,

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
      const Color(
        0xFFE5E7EB,
      ),
    );
  }

  // ============================================================
  // SEARCH + FILTER
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
        const BorderRadius
            .vertical(
          top:
          Radius.circular(
            10,
          ),
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFE5E7EB,
          ),
        ),
      ),

      child: Row(
        children: [
          // ====================================================
          // SEARCH
          // ====================================================

          Expanded(
            flex: 3,

            child:
            TextField(
              controller:
              _searchController,

              onChanged: (
                  value,
                  ) {
                _categoryController
                    .setSearchQuery(
                  value,
                );
              },

              decoration:
              InputDecoration(
                hintText:
                'Search category name or description...',

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
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          // ====================================================
          // STATUS FILTER
          // ====================================================

          SizedBox(
            width: 230,

            child:
            DropdownButtonFormField<
                String>(
              value:
              _categoryController
                  .selectedStatus,

              decoration:
              InputDecoration(
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
                  _categoryController
                      .setStatus(
                    value,
                  );
                }
              },
            ),
          ),

          const Spacer(),

          // ====================================================
          // RESET
          // ====================================================

          OutlinedButton.icon(
            onPressed: () {
              _searchController
                  .clear();

              _categoryController
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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY TABLE
  // ============================================================

  Widget _categoryTable() {
    // PAGE LOAD / REFRESH LOADING
    if (_categoryController
        .isLoading) {
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
                'Loading categories...',
                style:
                TextStyle(
                  color:
                  Color(
                    0xFF667085,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final categories =
        _categoryController
            .paginatedCategories;

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
          const Color(
            0xFFE5E7EB,
          ),
        ),
      ),

      child:
      Column(
        children: [
          _tableHeader(),

          if (categories
              .isEmpty)
            const Padding(
              padding:
              EdgeInsets.all(
                50,
              ),

              child:
              Column(
                children: [
                  Icon(
                    Icons
                        .category_outlined,

                    size: 45,

                    color:
                    Colors.grey,
                  ),

                  SizedBox(
                    height: 10,
                  ),

                  Text(
                    'No categories found.',
                  ),
                ],
              ),
            ),

          ...categories.map(
                (category) {
              return _categoryRow(
                category,
              );
            },
          ),

          _pagination(),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _tableHeader() {
    return Container(
      height: 55,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
      ),

      color:
      const Color(
        0xFFFAFAFA,
      ),

      child:
      const Row(
        children: [
          Expanded(
            flex: 2,

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
            flex: 3,

            child:
            Text(
              'Description',

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
              'Attractions',

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

          Expanded(
            child:
            Text(
              'Created At',

              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          SizedBox(
            width: 110,

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
  // CATEGORY ROW
  // ============================================================

  Widget _categoryRow(
      CategoryModel category,
      ) {
    final statusColor =
    category.status ==
        'Active'
        ? const Color(
      0xFF15803D,
    )
        : const Color(
      0xFFDC2626,
    );

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),

      decoration:
      const BoxDecoration(
        border:
        Border(
          top:
          BorderSide(
            color:
            Color(
              0xFFE5E7EB,
            ),
          ),
        ),
      ),

      child:
      Row(
        children: [
          // CATEGORY
          Expanded(
            flex: 2,

            child:
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,

                  decoration:
                  BoxDecoration(
                    color:
                    mainGreen
                        .withOpacity(
                      0.10,
                    ),

                    shape:
                    BoxShape.circle,
                  ),

                  child:
                  const Icon(
                    Icons
                        .category_outlined,

                    color:
                    mainGreen,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                  Text(
                    category.name,

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // DESCRIPTION
          Expanded(
            flex: 3,

            child:
            Text(
              category.description,

              maxLines: 2,

              overflow:
              TextOverflow
                  .ellipsis,
            ),
          ),

          // ATTRACTIONS
          Expanded(
            child:
            Text(
              '${category.attractionCount}',
            ),
          ),

          // STATUS
          Expanded(
            child:
            Align(
              alignment:
              Alignment
                  .centerLeft,

              child:
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),

                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                Text(
                  category.status,

                  style:
                  TextStyle(
                    color:
                    statusColor,
                  ),
                ),
              ),
            ),
          ),

          // CREATED AT
          Expanded(
            child:
            Text(
              _formatDate(
                category.createdAt,
              ),
            ),
          ),

          // ACTIONS
          SizedBox(
            width: 110,

            child:
            Row(
              children: [
                IconButton(
                  tooltip:
                  'Edit Category',

                  onPressed:
                  _categoryController
                      .isOperationLoading
                      ? null
                      : () {
                    _showEditCategoryDialog(
                      category,
                    );
                  },

                  icon:
                  const Icon(
                    Icons
                        .edit_outlined,

                    color:
                    mainGreen,
                  ),
                ),

                IconButton(
                  tooltip:
                  'Delete Category',

                  onPressed:
                  _categoryController
                      .isOperationLoading
                      ? null
                      : () {
                    _showDeleteDialog(
                      category,
                    );
                  },

                  icon:
                  const Icon(
                    Icons
                        .delete_outline,

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
  // ADD CATEGORY
  // ============================================================

  void _showAddCategoryDialog() {
    _showCategoryDialog();
  }

  // ============================================================
  // EDIT CATEGORY
  // ============================================================

  void _showEditCategoryDialog(
      CategoryModel category,
      ) {
    _showCategoryDialog(
      category: category,
    );
  }

  // ============================================================
  // ADD / EDIT DIALOG
  // ============================================================

  void _showCategoryDialog({
    CategoryModel? category,
  }) {
    final isEditing =
        category != null;

    final nameController =
    TextEditingController(
      text:
      category?.name ??
          '',
    );

    final descriptionController =
    TextEditingController(
      text:
      category
          ?.description ??
          '',
    );

    String selectedStatus =
        category?.status ??
            'Active';

    bool isSaving = false;

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
              Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons
                        .edit_outlined
                        : Icons
                        .add_circle_outline,

                    color:
                    mainGreen,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Text(
                    isEditing
                        ? 'Edit Category'
                        : 'Add New Category',
                  ),
                ],
              ),

              content:
              SizedBox(
                width: 480,

                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    TextField(
                      controller:
                      nameController,

                      enabled:
                      !isSaving,

                      decoration:
                      const InputDecoration(
                        labelText:
                        'Category Name *',

                        filled:
                        true,

                        fillColor:
                        Colors.white,

                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextField(
                      controller:
                      descriptionController,

                      enabled:
                      !isSaving,

                      maxLines: 4,

                      decoration:
                      const InputDecoration(
                        labelText:
                        'Description *',

                        filled:
                        true,

                        fillColor:
                        Colors.white,

                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    DropdownButtonFormField<
                        String>(
                      value:
                      selectedStatus,

                      decoration:
                      const InputDecoration(
                        labelText:
                        'Status *',

                        filled:
                        true,

                        fillColor:
                        Colors.white,

                        border:
                        OutlineInputBorder(),
                      ),

                      items:
                      const [
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
                      isSaving
                          ? null
                          : (
                          value,
                          ) {
                        if (value !=
                            null) {
                          setDialogState(
                                () {
                              selectedStatus =
                                  value;
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              actions:
              [
                OutlinedButton(
                  onPressed:
                  isSaving
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

                ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    mainGreen,

                    foregroundColor:
                    Colors.white,

                    minimumSize:
                    const Size(
                      140,
                      45,
                    ),
                  ),

                  onPressed:
                  isSaving
                      ? null
                      : () async {
                    final name =
                    nameController.text.trim();

                    final description =
                    descriptionController.text.trim();

                    if (name.isEmpty ||
                        description.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please complete all required fields.',
                          ),
                        ),
                      );

                      return;
                    }

                    // START LOADING
                    setDialogState(
                          () {
                        isSaving =
                        true;
                      },
                    );

                    bool success;

                    if (isEditing) {
                      success =
                      await _categoryController
                          .updateCategory(
                        id:
                        category.id,

                        name:
                        name,

                        description:
                        description,

                        status:
                        selectedStatus,
                      );
                    } else {
                      success =
                      await _categoryController
                          .addCategory(
                        name:
                        name,

                        description:
                        description,

                        status:
                        selectedStatus,
                      );
                    }

                    if (!mounted) {
                      return;
                    }

                    if (!success) {
                      setDialogState(
                            () {
                          isSaving =
                          false;
                        },
                      );

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to save category. The category name may already exist.',
                          ),
                        ),
                      );

                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? 'Category updated successfully.'
                              : 'Category added successfully.',
                        ),
                      ),
                    );
                  },

                  child:
                  isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,

                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2.5,

                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isEditing
                        ? 'Save Changes'
                        : 'Add Category',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE DIALOG
  // ============================================================

  void _showDeleteDialog(
      CategoryModel category,
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
                    Icons
                        .warning_amber_rounded,
                    color: Colors.red,
                    size: 32,
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Text(
                    'Delete Category',
                  ),
                ],
              ),

              content:
              Text(
                'Are you sure you want to delete "${category.name}"?',
              ),

              actions:
              [
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

                ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    Colors.red,

                    foregroundColor:
                    Colors.white,

                    minimumSize:
                    const Size(
                      110,
                      45,
                    ),
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

                    final success =
                    await _categoryController
                        .deleteCategory(
                      category.id,
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

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to delete category.',
                          ),
                        ),
                      );

                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Category deleted successfully.',
                        ),
                      ),
                    );
                  },

                  child:
                  isDeleting
                      ? const SizedBox(
                    width: 20,
                    height: 20,

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
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  Widget _pagination() {
    final controller =
        _categoryController;

    final total =
        controller
            .filteredCategories
            .length;

    final start =
    total == 0
        ? 0
        : ((controller.currentPage -
        1) *
        controller
            .itemsPerPage) +
        1;

    final end =
    total == 0
        ? 0
        : (start +
        controller
            .paginatedCategories
            .length -
        1)
        .clamp(
      0,
      total,
    );

    return Padding(
      padding:
      const EdgeInsets.all(
        18,
      ),

      child:
      Row(
        children: [
          Text(
            'Showing $start to $end of $total results',
          ),

          const Spacer(),

          IconButton(
            onPressed:
            controller.currentPage >
                1
                ? controller
                .previousPage
                : null,

            icon:
            const Icon(
              Icons.chevron_left,
            ),
          ),

          for (
          int page = 1;
          page <=
              controller
                  .totalPages;
          page++
          )
            if (page <= 5)
              Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 3,
                ),

                child:
                _pageButton(
                  page,
                ),
              ),

          IconButton(
            onPressed:
            controller.currentPage <
                controller
                    .totalPages
                ? controller
                .nextPage
                : null,

            icon:
            const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE BUTTON
  // ============================================================

  Widget _pageButton(
      int page,
      ) {
    final selected =
        page ==
            _categoryController
                .currentPage;

    return InkWell(
      onTap: () {
        _categoryController
            .goToPage(
          page,
        );
      },

      child:
      Container(
        width: 36,
        height: 36,

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
  // FORMAT DATE
  // ============================================================

  String _formatDate(
      DateTime date,
      ) {
    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final year =
        date.year;

    return '$day/$month/$year';
  }
}