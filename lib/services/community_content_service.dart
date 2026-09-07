import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/attraction.dart';
import '../models/category.dart';

/// Live Firestore content shared by the community feed and attraction reviews.
///
/// The admin module writes to the same `attractions` and `categories`
/// collections, so admin changes appear here without maintaining duplicate data.
class CommunityContentService extends ChangeNotifier {
  CommunityContentService._();

  static final CommunityContentService instance = CommunityContentService._();

  /// User-facing order shared by Attraction Reviews and Community Feed.
  static const List<String> categoryDisplayOrder = [
    'Sightseeing & Landmark',
    'Entertainment',
    'Eco & Sustainable',
    'Local Experience',
    'Beach & Island',
    'Nature & Parks',
    'Heritage & History',
    'Adventure & Outdoor',
    'Nightlife & Night View',
    'Shopping & Markets',
    'Arts & Culture',
    'Food & Dining',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attractionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;

  List<AttractionModel> _attractions = const [];
  List<CategoryModel> _categories = const [];
  bool _started = false;
  bool _attractionsLoaded = false;
  bool _categoriesLoaded = false;
  String? _errorMessage;

  List<AttractionModel> get attractions => List.unmodifiable(_attractions);
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isLoading => !_attractionsLoaded || !_categoriesLoaded;
  String? get errorMessage => _errorMessage;

  List<String> get activeCategoryNames {
    final activeNamesByLowerCase = <String, String>{};
    for (final category in _categories
        .where((category) => category.status.toLowerCase() == 'active')
        .where((category) => category.name.trim().isNotEmpty)) {
      activeNamesByLowerCase[category.name.trim().toLowerCase()] =
          category.name.trim();
    }

    // Use the canonical spelling and order above, while still respecting the
    // Active/Inactive status stored in Firestore.
    return categoryDisplayOrder
        .where(
          (name) => activeNamesByLowerCase.containsKey(name.toLowerCase()),
        )
        .toList();
  }

  void start() {
    if (_started) return;
    _started = true;

    _attractionsSub = _firestore.collection('attractions').snapshots().listen(
      (snapshot) {
        _attractions = snapshot.docs
            .map(AttractionModel.fromFirestore)
            .where(
              (attraction) =>
                  attraction.status.toLowerCase() == 'active' &&
                  attraction.name.isNotEmpty,
            )
            .toList();
        _attractionsLoaded = true;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _attractionsLoaded = true;
        _errorMessage = 'Unable to load attractions from Firebase.';
        notifyListeners();
      },
    );

    _categoriesSub = _firestore.collection('categories').snapshots().listen(
      (snapshot) {
        _categories = snapshot.docs.map(CategoryModel.fromFirestore).toList();
        _categoriesLoaded = true;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _categoriesLoaded = true;
        _errorMessage = 'Unable to load categories from Firebase.';
        notifyListeners();
      },
    );
  }

  Future<void> retry() async {
    await _attractionsSub?.cancel();
    await _categoriesSub?.cancel();
    _started = false;
    _attractionsLoaded = false;
    _categoriesLoaded = false;
    _errorMessage = null;
    notifyListeners();
    start();
  }
}
