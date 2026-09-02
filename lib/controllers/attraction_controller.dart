import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/category.dart';
import '../services/here_geocoding_service.dart';

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
  final HereGeocodingService _hereGeocoding = HereGeocodingService();

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
  bool get isHereConfigured => _hereGeocoding.isConfigured;

  Future<HereCoordinates?> _findCoordinates({
    required String name,
    required String address,
    required String area,
    required String state,
  }) async {
    if (!_hereGeocoding.isConfigured) {
      debugPrint('HERE_API_KEY is not configured. Coordinates remain 0.');
      return null;
    }

    try {
      return await _hereGeocoding.geocodeAttraction(
        name: name,
        address: address,
        area: area,
        state: state,
      );
    } catch (e) {
      debugPrint('HERE geocoding error: $e');
      return null;
    }
  }

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

    if (startIndex >= filtered.length) {
      return [];
    }

    final endIndex = startIndex + _itemsPerPage > filtered.length
        ? filtered.length
        : startIndex + _itemsPerPage;

    return filtered.sublist(startIndex, endIndex);
  }

  int get totalPages {
    if (filteredAttractions.isEmpty) {
      return 1;
    }
    return (filteredAttractions.length / _itemsPerPage).ceil();
  }

  int get totalAttractions => _attractions.length;

  int get activeAttractions =>
      _attractions.where((item) => item.status == 'Active').length;

  int get inactiveAttractions =>
      _attractions.where((item) => item.status == 'Inactive').length;

  int get totalCategories => _attractions
      .map((item) => item.categoryId)
      .where((id) => id.trim().isNotEmpty)
      .toSet()
      .length;

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

      _attractions =
          snapshot.docs.map(AttractionModel.fromFirestore).toList();

      _attractions.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      if (_currentPage > totalPages) {
        _currentPage = totalPages;
      }

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
    if (attractionId.trim().isEmpty) {
      throw Exception('Cannot upload image: attraction ID is empty.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName =
    image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

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

      if (categoryId.trim().isEmpty) {
        debugPrint('Add attraction error: category ID is empty');
        return false;
      }

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
        final index =
        _coverImageIndex < urls.length ? _coverImageIndex : 0;
        coverImageUrl = urls[index];
      }

      final coordinates = await _findCoordinates(
        name: name,
        address: address,
        area: area,
        state: state,
      );

      final attraction = AttractionModel(
        id: document.id,
        name: name.trim(),
        categoryId: categoryId.trim(),
        categoryName: categoryName.trim(),
        state: state.trim(),
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
        latitude: coordinates?.latitude ?? 0,
        longitude: coordinates?.longitude ?? 0,
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
        _firestore.collection('categories').doc(categoryId.trim()),
        {
          'attractionCount': FieldValue.increment(1),
        },
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

      final attractionId = original.id.trim();
      final oldCategoryId = original.categoryId.trim();
      final newCategoryId = categoryId.trim();

      if (attractionId.isEmpty) {
        debugPrint('Update attraction error: attraction ID is empty');
        return false;
      }

      if (newCategoryId.isEmpty) {
        debugPrint('Update attraction error: new category ID is empty');
        return false;
      }

      final duplicate = await _firestore
          .collection('attractions')
          .where('name', isEqualTo: name.trim())
          .get();

      if (duplicate.docs.any((doc) => doc.id != attractionId)) {
        debugPrint('Update attraction error: duplicate attraction name');
        return false;
      }

      final List<String> newUrls = await Future.wait(
        List.generate(
          _selectedImages.length,
              (index) {
            return _uploadImage(
              attractionId: attractionId,
              image: _selectedImages[index],
              index: index,
            );
          },
        ),
      );

      final List<String> finalImages = [
        ...existingImageUrls,
        ...newUrls,
      ];

      final bool locationChanged =
          original.name.trim() != name.trim() ||
              original.address.trim() != address.trim() ||
              original.area.trim() != area.trim() ||
              original.state.trim() != state.trim();

      final coordinates = locationChanged ||
          original.latitude == 0 ||
          original.longitude == 0
          ? await _findCoordinates(
        name: name,
        address: address,
        area: area,
        state: state,
      )
          : null;

      final double finalLatitude =
          coordinates?.latitude ?? original.latitude;
      final double finalLongitude =
          coordinates?.longitude ?? original.longitude;

      String finalCoverUrl = '';

      if (selectedExistingCoverUrl != null &&
          finalImages.contains(selectedExistingCoverUrl)) {
        finalCoverUrl = selectedExistingCoverUrl;
      } else if (newUrls.isNotEmpty) {
        final newIndex =
        _coverImageIndex < newUrls.length ? _coverImageIndex : 0;
        finalCoverUrl = newUrls[newIndex];
      } else if (finalImages.isNotEmpty) {
        finalCoverUrl = finalImages.first;
      }

      final batch = _firestore.batch();
      final attractionRef =
      _firestore.collection('attractions').doc(attractionId);

      batch.update(
        attractionRef,
        {
          'name': name.trim(),
          'categoryId': newCategoryId,
          'categoryName': categoryName.trim(),
          'state': state.trim(),
          'area': area.trim(),
          'description': description.trim(),
          'isFreeEntry': isFreeEntry,
          'malaysianAdultFee': isFreeEntry ? 0 : malaysianAdultFee,
          'malaysianChildFee': isFreeEntry ? 0 : malaysianChildFee,
          'malaysianSeniorFee': isFreeEntry ? 0 : malaysianSeniorFee,
          'nonMalaysianAdultFee':
          isFreeEntry ? 0 : nonMalaysianAdultFee,
          'nonMalaysianChildFee':
          isFreeEntry ? 0 : nonMalaysianChildFee,
          'nonMalaysianSeniorFee':
          isFreeEntry ? 0 : nonMalaysianSeniorFee,
          'openingTime': openingTime.trim(),
          'closingTime': closingTime.trim(),
          'recommendedDuration': recommendedDuration.trim(),
          'address': address.trim(),
          'phoneNumber': phoneNumber.trim(),
          'latitude': finalLatitude,
          'longitude': finalLongitude,
          if (coordinates != null) ...{
            'geocodedAddress': coordinates.matchedAddress,
            'geocodedAt': FieldValue.serverTimestamp(),
            'geocodingProvider': 'HERE',
          },
          'facilities': facilities,
          'highlights': highlights,
          'imageUrls': finalImages,
          'coverImageUrl': finalCoverUrl,
          'status': status.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'adultFee': FieldValue.delete(),
          'childFee': FieldValue.delete(),
        },
      );

      if (oldCategoryId != newCategoryId) {
        if (oldCategoryId.isNotEmpty) {
          batch.update(
            _firestore.collection('categories').doc(oldCategoryId),
            {
              'attractionCount': FieldValue.increment(-1),
            },
          );
        }

        if (newCategoryId.isNotEmpty) {
          batch.update(
            _firestore.collection('categories').doc(newCategoryId),
            {
              'attractionCount': FieldValue.increment(1),
            },
          );
        }
      }

      await batch.commit();

      clearSelectedImages();
      await loadAttractions(notify: false);

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
      if (url.trim().isEmpty) return;

      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Delete storage image error: $e');
    }
  }

  Future<Map<String, int>> geocodeAllMissingAttractions() async {
    int updated = 0;
    int failed = 0;
    int skipped = 0;

    if (!_hereGeocoding.isConfigured) {
      throw StateError(
        'HERE_API_KEY is missing. Run with '
            '--dart-define=HERE_API_KEY=YOUR_KEY.',
      );
    }

    try {
      _isProcessing = true;
      notifyListeners();

      final snapshot = await _firestore.collection('attractions').get();

      for (final document in snapshot.docs) {
        final attraction = AttractionModel.fromFirestore(document);

        if (attraction.latitude != 0 && attraction.longitude != 0) {
          skipped++;
          continue;
        }

        final coordinates = await _findCoordinates(
          name: attraction.name,
          address: attraction.address,
          area: attraction.area,
          state: attraction.state,
        );

        if (coordinates == null) {
          failed++;
          continue;
        }

        await document.reference.update({
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
          'geocodedAddress': coordinates.matchedAddress,
          'geocodedAt': FieldValue.serverTimestamp(),
          'geocodingProvider': 'HERE',
        });

        updated++;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      await loadAttractions(notify: false);
      return {'updated': updated, 'failed': failed, 'skipped': skipped};
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAttraction(AttractionModel attraction) async {
    try {
      _isProcessing = true;
      notifyListeners();

      final attractionId = attraction.id.trim();
      final categoryId = attraction.categoryId.trim();

      if (attractionId.isEmpty) {
        debugPrint('Delete attraction error: attraction ID is empty');
        return false;
      }

      final batch = _firestore.batch();

      batch.delete(
        _firestore.collection('attractions').doc(attractionId),
      );

      if (categoryId.isNotEmpty) {
        batch.update(
          _firestore.collection('categories').doc(categoryId),
          {
            'attractionCount': FieldValue.increment(-1),
          },
        );
      }

      await batch.commit();

      for (final url in attraction.imageUrls) {
        if (url.trim().isEmpty) continue;

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
