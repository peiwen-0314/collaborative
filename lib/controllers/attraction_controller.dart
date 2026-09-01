import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/category.dart';

class SelectedAttractionImage {
  final String name;
  final Uint8List bytes;

  SelectedAttractionImage({
    required this.name,
    required this.bytes,
  });
}

class AttractionController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<AttractionModel> _attractions = [];
  List<CategoryModel> _categories = [];

  bool _isLoading = false;
  bool _isProcessing = false;

  String _searchQuery = '';
  String _selectedStatus = 'All Status';
  String _selectedCategory = 'All Categories';

  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<SelectedAttractionImage> _selectedImages = [];
  int _coverImageIndex = 0;

  List<AttractionModel> get attractions => _attractions;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String get searchQuery => _searchQuery;
  String get selectedStatus => _selectedStatus;
  String get selectedCategory => _selectedCategory;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  List<SelectedAttractionImage> get selectedImages =>
      List.unmodifiable(_selectedImages);
  int get coverImageIndex => _coverImageIndex;

  List<AttractionModel> get filteredAttractions {
    List<AttractionModel> result = List.from(_attractions);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((attraction) {
        return attraction.name.toLowerCase().contains(query) ||
            attraction.state.toLowerCase().contains(query) ||
            attraction.area.toLowerCase().contains(query) ||
            attraction.categoryName.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedStatus != 'All Status') {
      result = result
          .where((attraction) => attraction.status == _selectedStatus)
          .toList();
    }

    if (_selectedCategory != 'All Categories') {
      result = result
          .where((attraction) => attraction.categoryId == _selectedCategory)
          .toList();
    }

    return result;
  }

  List<AttractionModel> get paginatedAttractions {
    final filtered = filteredAttractions;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filtered.length) return [];

    final endIndex = startIndex + _itemsPerPage > filtered.length
        ? filtered.length
        : startIndex + _itemsPerPage;

    return filtered.sublist(startIndex, endIndex);
  }

  int get totalPages {
    if (filteredAttractions.isEmpty) return 1;
    return (filteredAttractions.length / _itemsPerPage).ceil();
  }

  int get totalAttractions => _attractions.length;
  int get activeAttractions =>
      _attractions.where((item) => item.status == 'Active').length;
  int get inactiveAttractions =>
      _attractions.where((item) => item.status == 'Inactive').length;
  int get totalCategories =>
      _attractions.map((item) => item.categoryId).where((id) => id.isNotEmpty).toSet().length;

  Future<void> loadData() async {
    try {
      _isLoading = true;
      notifyListeners();
      await Future.wait([
        loadCategories(notify: false),
        loadAttractions(notify: false),
      ]);
    } catch (e) {
      debugPrint('Load attraction data error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories({bool notify = true}) async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      _categories = snapshot.docs
          .map(CategoryModel.fromFirestore)
          .where((category) => category.status == 'Active')
          .toList();
      _categories.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Load categories error: $e');
    }
  }

  Future<void> loadAttractions({bool notify = true}) async {
    try {
      final snapshot = await _firestore.collection('attractions').get();
      _attractions = snapshot.docs.map(AttractionModel.fromFirestore).toList();
      _attractions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_currentPage > totalPages) _currentPage = totalPages;
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Load attractions error: $e');
    }
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _currentPage = 1;
    notifyListeners();
  }

  void setStatus(String value) {
    _selectedStatus = value;
    _currentPage = 1;
    notifyListeners();
  }

  void setCategory(String value) {
    _selectedCategory = value;
    _currentPage = 1;
    notifyListeners();
  }

  void resetFilter() {
    _searchQuery = '';
    _selectedStatus = 'All Status';
    _selectedCategory = 'All Categories';
    _currentPage = 1;
    notifyListeners();
  }

  void setItemsPerPage(int value) {
    _itemsPerPage = value;
    _currentPage = 1;
    notifyListeners();
  }

  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      notifyListeners();
    }
  }

  void nextPage() {
    if (_currentPage < totalPages) {
      _currentPage++;
      notifyListeners();
    }
  }

  void goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  Future<void> pickImages() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isEmpty) return;

      for (final PlatformFile file in files) {
        final Uint8List bytes = await file.readAsBytes();

        _selectedImages.add(
          SelectedAttractionImage(
            name: file.name,
            bytes: bytes,
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Pick images error: $e');
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    _selectedImages.removeAt(index);

    if (_selectedImages.isEmpty) {
      _coverImageIndex = 0;
    } else if (_coverImageIndex == index) {
      _coverImageIndex = 0;
    } else if (_coverImageIndex > index) {
      _coverImageIndex--;
    }
    notifyListeners();
  }

  void setCoverImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      _coverImageIndex = index;
      notifyListeners();
    }
  }

  void clearSelectedImages() {
    _selectedImages.clear();
    _coverImageIndex = 0;
    notifyListeners();
  }

  Future<String> _uploadImage({
    required String attractionId,
    required SelectedAttractionImage image,
    required int index,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final reference = _storage
        .ref()
        .child('attractions')
        .child(attractionId)
        .child('${timestamp}_${index}_$safeName');

    await reference.putData(
      image.bytes,
      SettableMetadata(contentType: _contentType(image.name)),
    );

    return reference.getDownloadURL();
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<bool> addAttraction({
    required String name,
    required String categoryId,
    required String categoryName,
    required String state,
    required String area,
    required String description,
    required bool isFreeEntry,
    required double malaysianAdultFee,
    required double malaysianChildFee,
    required double malaysianSeniorFee,
    required double nonMalaysianAdultFee,
    required double nonMalaysianChildFee,
    required double nonMalaysianSeniorFee,
    required String openingTime,
    required String closingTime,
    required String recommendedDuration,
    required String address,
    required String phoneNumber,
    required List<String> facilities,
    required List<String> highlights,
    required String status,
  }) async {
    try {
      _isProcessing = true;
      notifyListeners();

      final duplicate = await _firestore
          .collection('attractions')
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty) {
        debugPrint('Add attraction error: duplicate attraction name');
        return false;
      }

      final document = _firestore.collection('attractions').doc();

      final List<String> urls = await Future.wait(
        List.generate(
          _selectedImages.length,
              (index) {
            return _uploadImage(
              attractionId: document.id,
              image: _selectedImages[index],
              index: index,
            );
          },
        ),
      );

      String coverImageUrl = '';
      if (urls.isNotEmpty) {
        final index = _coverImageIndex < urls.length ? _coverImageIndex : 0;
        coverImageUrl = urls[index];
      }

      final attraction = AttractionModel(
        id: document.id,
        name: name.trim(),
        categoryId: categoryId,
        categoryName: categoryName,
        state: state,
        area: area.trim(),
        description: description.trim(),
        isFreeEntry: isFreeEntry,
        malaysianAdultFee: isFreeEntry ? 0 : malaysianAdultFee,
        malaysianChildFee: isFreeEntry ? 0 : malaysianChildFee,
        malaysianSeniorFee: isFreeEntry ? 0 : malaysianSeniorFee,
        nonMalaysianAdultFee: isFreeEntry ? 0 : nonMalaysianAdultFee,
        nonMalaysianChildFee: isFreeEntry ? 0 : nonMalaysianChildFee,
        nonMalaysianSeniorFee: isFreeEntry ? 0 : nonMalaysianSeniorFee,
        openingTime: openingTime,
        closingTime: closingTime,
        recommendedDuration: recommendedDuration,
        address: address.trim(),
        phoneNumber: phoneNumber.trim(),
        facilities: facilities,
        highlights: highlights,
        imageUrls: urls,
        coverImageUrl: coverImageUrl,
        status: status,
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(document, attraction.toMap());
      batch.update(
        _firestore.collection('categories').doc(categoryId),
        {'attractionCount': FieldValue.increment(1)},
      );
      await batch.commit();

      clearSelectedImages();
      return true;
    } catch (e) {
      debugPrint('Add attraction error: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> updateAttraction({
    required AttractionModel original,
    required String name,
    required String categoryId,
    required String categoryName,
    required String state,
    required String area,
    required String description,
    required bool isFreeEntry,
    required double malaysianAdultFee,
    required double malaysianChildFee,
    required double malaysianSeniorFee,
    required double nonMalaysianAdultFee,
    required double nonMalaysianChildFee,
    required double nonMalaysianSeniorFee,
    required String openingTime,
    required String closingTime,
    required String recommendedDuration,
    required String address,
    required String phoneNumber,
    required List<String> facilities,
    required List<String> highlights,
    required List<String> existingImageUrls,
    required String? selectedExistingCoverUrl,
    required String status,
  }) async {
    try {
      _isProcessing = true;
      notifyListeners();

      final duplicate = await _firestore
          .collection('attractions')
          .where('name', isEqualTo: name.trim())
          .get();
      if (duplicate.docs.any((doc) => doc.id != original.id)) {
        debugPrint('Update attraction error: duplicate attraction name');
        return false;
      }

      final List<String> newUrls = await Future.wait(
        List.generate(
          _selectedImages.length,
              (index) {
            return _uploadImage(
              attractionId: original.id,
              image: _selectedImages[index],
              index: index,
            );
          },
        ),
      );

      final List<String> finalImages = [...existingImageUrls, ...newUrls];
      String finalCoverUrl = '';

      if (selectedExistingCoverUrl != null &&
          finalImages.contains(selectedExistingCoverUrl)) {
        finalCoverUrl = selectedExistingCoverUrl;
      } else if (newUrls.isNotEmpty) {
        final newIndex = _coverImageIndex < newUrls.length ? _coverImageIndex : 0;
        finalCoverUrl = newUrls[newIndex];
      } else if (finalImages.isNotEmpty) {
        finalCoverUrl = finalImages.first;
      }

      final batch = _firestore.batch();
      final attractionRef = _firestore.collection('attractions').doc(original.id);

      batch.update(attractionRef, {
        'name': name.trim(),
        'categoryId': categoryId,
        'categoryName': categoryName,
        'state': state,
        'area': area.trim(),
        'description': description.trim(),
        'isFreeEntry': isFreeEntry,
        'malaysianAdultFee': isFreeEntry ? 0 : malaysianAdultFee,
        'malaysianChildFee': isFreeEntry ? 0 : malaysianChildFee,
        'malaysianSeniorFee': isFreeEntry ? 0 : malaysianSeniorFee,
        'nonMalaysianAdultFee': isFreeEntry ? 0 : nonMalaysianAdultFee,
        'nonMalaysianChildFee': isFreeEntry ? 0 : nonMalaysianChildFee,
        'nonMalaysianSeniorFee': isFreeEntry ? 0 : nonMalaysianSeniorFee,
        'openingTime': openingTime,
        'closingTime': closingTime,
        'recommendedDuration': recommendedDuration,
        'address': address.trim(),
        'phoneNumber': phoneNumber.trim(),
        'facilities': facilities,
        'highlights': highlights,
        'imageUrls': finalImages,
        'coverImageUrl': finalCoverUrl,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        // Remove obsolete legacy fee fields if they exist.
        'adultFee': FieldValue.delete(),
        'childFee': FieldValue.delete(),
      });

      if (original.categoryId != categoryId) {
        batch.update(
          _firestore.collection('categories').doc(original.categoryId),
          {'attractionCount': FieldValue.increment(-1)},
        );
        batch.update(
          _firestore.collection('categories').doc(categoryId),
          {'attractionCount': FieldValue.increment(1)},
        );
      }

      await batch.commit();
      clearSelectedImages();
      return true;
    } catch (e) {
      debugPrint('Update attraction error: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> deleteStorageImage(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Delete storage image error: $e');
    }
  }

  Future<bool> deleteAttraction(AttractionModel attraction) async {
    try {
      _isProcessing = true;
      notifyListeners();

      final batch = _firestore.batch();
      batch.delete(_firestore.collection('attractions').doc(attraction.id));
      batch.update(
        _firestore.collection('categories').doc(attraction.categoryId),
        {'attractionCount': FieldValue.increment(-1)},
      );
      await batch.commit();

      // Storage cleanup after Firestore succeeds.
      for (final url in attraction.imageUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (e) {
          debugPrint('Image delete error: $e');
        }
      }

      await loadAttractions(notify: false);
      return true;
    } catch (e) {
      debugPrint('Delete attraction error: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
