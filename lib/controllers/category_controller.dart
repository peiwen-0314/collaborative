import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';

class CategoryController extends ChangeNotifier {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // DATA
  // ============================================================

  List<CategoryModel> _categories = [];

  bool _isLoading = false;
  bool _isOperationLoading = false;

  String _searchQuery = '';
  String _selectedStatus = 'All Status';

  int _currentPage = 1;
  int _itemsPerPage = 10;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isLoading => _isLoading;

  bool get isOperationLoading =>
      _isOperationLoading;

  String get searchQuery =>
      _searchQuery;

  String get selectedStatus =>
      _selectedStatus;

  int get currentPage =>
      _currentPage;

  int get itemsPerPage =>
      _itemsPerPage;

  List<CategoryModel> get categories =>
      _categories;

  // ============================================================
  // FILTERED CATEGORIES
  // ============================================================

  List<CategoryModel> get filteredCategories {
    List<CategoryModel> result =
    List.from(_categories);

    // SEARCH
    if (_searchQuery.trim().isNotEmpty) {
      final query =
      _searchQuery.trim().toLowerCase();

      result = result.where((category) {
        return category.name
            .toLowerCase()
            .contains(query) ||
            category.description
                .toLowerCase()
                .contains(query);
      }).toList();
    }

    // STATUS FILTER
    if (_selectedStatus != 'All Status') {
      result = result.where((category) {
        return category.status ==
            _selectedStatus;
      }).toList();
    }

    return result;
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  List<CategoryModel> get paginatedCategories {
    final filtered =
        filteredCategories;

    final startIndex =
        (_currentPage - 1) *
            _itemsPerPage;

    if (startIndex >= filtered.length) {
      return [];
    }

    final endIndex =
    (startIndex + _itemsPerPage)
        .clamp(
      0,
      filtered.length,
    );

    return filtered.sublist(
      startIndex,
      endIndex,
    );
  }

  int get totalPages {
    if (filteredCategories.isEmpty) {
      return 1;
    }

    return (filteredCategories.length /
        _itemsPerPage)
        .ceil();
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  int get totalCategories =>
      _categories.length;

  int get activeCategories =>
      _categories
          .where(
            (category) =>
        category.status ==
            'Active',
      )
          .length;

  int get inactiveCategories =>
      _categories
          .where(
            (category) =>
        category.status ==
            'Inactive',
      )
          .length;

  int get totalAttractions =>
      _categories.fold(
        0,
            (total, category) =>
        total +
            category.attractionCount,
      );

  // ============================================================
  // LOAD CATEGORIES
  // ============================================================

  Future<void> loadCategories() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot =
      await _firestore
          .collection('categories')
          .orderBy(
        'createdAt',
        descending: true,
      )
          .get();

      _categories =
          snapshot.docs.map(
                (document) {
              return CategoryModel
                  .fromFirestore(
                document,
              );
            },
          ).toList();

      // Prevent invalid page number
      if (_currentPage > totalPages) {
        _currentPage = totalPages;
      }
    } catch (e) {
      debugPrint(
        'Load categories error: $e',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ADD CATEGORY
  // ============================================================

  Future<bool> addCategory({
    required String name,
    required String description,
    required String status,
  }) async {
    try {
      _isOperationLoading = true;
      notifyListeners();

      final trimmedName =
      name.trim();

      // Prevent duplicate category
      final duplicate =
      _categories.any(
            (category) =>
        category.name
            .toLowerCase() ==
            trimmedName
                .toLowerCase(),
      );

      if (duplicate) {
        return false;
      }

      final document =
      _firestore
          .collection(
        'categories',
      )
          .doc();

      final category =
      CategoryModel(
        id: document.id,
        name: trimmedName,
        description:
        description.trim(),
        status: status,
        attractionCount: 0,
        createdAt: DateTime.now(),
      );

      await document.set(
        category.toMap(),
      );

      await loadCategories();

      return true;
    } catch (e) {
      debugPrint(
        'Add category error: $e',
      );

      return false;
    } finally {
      _isOperationLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // UPDATE CATEGORY
  // ============================================================

  Future<bool> updateCategory({
    required String id,
    required String name,
    required String description,
    required String status,
  }) async {
    try {
      _isOperationLoading = true;
      notifyListeners();

      final trimmedName =
      name.trim();

      final duplicate =
      _categories.any(
            (category) =>
        category.id != id &&
            category.name
                .toLowerCase() ==
                trimmedName
                    .toLowerCase(),
      );

      if (duplicate) {
        return false;
      }

      await _firestore
          .collection('categories')
          .doc(id)
          .update({
        'name': trimmedName,
        'description':
        description.trim(),
        'status': status,
      });

      await loadCategories();

      return true;
    } catch (e) {
      debugPrint(
        'Update category error: $e',
      );

      return false;
    } finally {
      _isOperationLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // DELETE CATEGORY
  // ============================================================

  Future<bool> deleteCategory(
      String id,
      ) async {
    try {
      _isOperationLoading = true;
      notifyListeners();

      await _firestore
          .collection('categories')
          .doc(id)
          .delete();

      await loadCategories();

      return true;
    } catch (e) {
      debugPrint(
        'Delete category error: $e',
      );

      return false;
    } finally {
      _isOperationLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void setSearchQuery(
      String value,
      ) {
    _searchQuery = value;

    _currentPage = 1;

    notifyListeners();
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  void setStatus(
      String value,
      ) {
    _selectedStatus = value;

    _currentPage = 1;

    notifyListeners();
  }

  // ============================================================
  // RESET FILTER
  // ============================================================

  void resetFilter() {
    _searchQuery = '';

    _selectedStatus =
    'All Status';

    _currentPage = 1;

    notifyListeners();
  }

  // ============================================================
  // ITEMS PER PAGE
  // ============================================================

  void setItemsPerPage(
      int value,
      ) {
    _itemsPerPage = value;

    _currentPage = 1;

    notifyListeners();
  }

  // ============================================================
  // NEXT PAGE
  // ============================================================

  void nextPage() {
    if (_currentPage <
        totalPages) {
      _currentPage++;

      notifyListeners();
    }
  }

  // ============================================================
  // PREVIOUS PAGE
  // ============================================================

  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;

      notifyListeners();
    }
  }

  // ============================================================
  // GO TO PAGE
  // ============================================================

  void goToPage(
      int page,
      ) {
    if (page >= 1 &&
        page <= totalPages) {
      _currentPage = page;

      notifyListeners();
    }
  }
}