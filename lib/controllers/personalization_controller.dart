import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/interest_category.dart';

class PersonalizationController extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PersonalizationController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // RECOMMENDATION WEIGHTS
  // ============================================================
  //
  // Home recommendation score:
  //
  // 55% Category preference
  // 20% Location preference
  // 15% Historical travel-style preference
  // 10% Attraction data quality
  //
  // Existing behaviour signals remain:
  // - initial selected interest
  // - view attraction
  // - search
  // - wishlist / save
  // - add to trip
  //
  // New signals:
  // - repeated interest in a state/location
  // - travel styles selected while generating AI trips
  //
  static const double _categoryComponentMax = 55;
  static const double _locationComponentMax = 20;
  static const double _travelStyleComponentMax = 15;
  static const double _qualityComponentMax = 10;

  // Behaviour strength.
  static const double _viewCategoryWeight = 1.0;
  static const double _searchCategoryWeight = 2.0;
  static const double _wishlistCategoryWeight = 3.0;
  static const double _tripAddCategoryWeight = 4.0;

  // Location is intentionally weaker than category preference.
  static const double _viewLocationWeight = 0.5;
  static const double _searchLocationWeight = 1.5;
  static const double _wishlistLocationWeight = 2.0;
  static const double _tripAddLocationWeight = 2.5;

  // Generating a trip is a strong location signal, but the selected
  // travel styles are weaker because they may describe only this trip.
  static const double _generatedTripLocationWeight = 3.0;
  static const double _generatedTravelStyleWeight = 1.0;

  // ============================================================
  // TRAVEL STYLE -> ATTRACTION TAG MAPPING
  // ============================================================
  //
  // Travel Style is a user-friendly persona.
  // Category is an attraction tag.
  //
  // They do NOT need to have exactly the same name.
  //
  static const Map<String, List<String>> _travelStyleKeywords = {
    'Sustainable Explorer': [
      'eco',
      'sustainable',
      'green',
      'nature',
      'conservation',
      'environment',
      'community',
      'local',
    ],
    'Culture Seeker': [
      'culture',
      'cultural',
      'heritage',
      'history',
      'historical',
      'museum',
      'religious',
      'temple',
      'architecture',
      'traditional',
    ],
    'Nature Lover': [
      'nature',
      'forest',
      'park',
      'garden',
      'waterfall',
      'island',
      'beach',
      'mountain',
      'wildlife',
      'scenic',
    ],
    'Relax & Unwind': [
      'beach',
      'garden',
      'spa',
      'relax',
      'leisure',
      'scenic',
      'lake',
      'resort',
      'view',
    ],
    'Adventure Enthusiast': [
      'adventure',
      'hiking',
      'trail',
      'trekking',
      'climb',
      'cycling',
      'kayak',
      'water sport',
      'outdoor',
      'extreme',
    ],
    'Foodie': [
      'food',
      'market',
      'cuisine',
      'restaurant',
      'street food',
      'local food',
      'cafe',
      'culinary',
      'dining',
    ],
  };

  // ============================================================
  // STATE
  // ============================================================

  final List<InterestCategory> _categories = [];
  final List<AttractionModel> _allActiveAttractions = [];
  final List<AttractionModel> _recommendedAttractions = [];
  final Set<String> _selectedInterestIds = {};

  Map<String, double> _preferenceScores = {};
  Map<String, double> _locationScores = {};
  Map<String, double> _travelStyleScores = {};

  bool _isLoadingCategories = false;
  bool _isLoadingRecommendations = false;
  bool _isSavingInterests = false;

  String? _errorMessage;

  // ============================================================
  // GETTERS
  // ============================================================

  List<InterestCategory> get categories =>
      List.unmodifiable(_categories);

  List<AttractionModel> get allActiveAttractions =>
      List.unmodifiable(_allActiveAttractions);

  List<AttractionModel> get recommendedAttractions =>
      List.unmodifiable(_recommendedAttractions);

  Set<String> get selectedInterestIds =>
      Set.unmodifiable(_selectedInterestIds);

  Map<String, double> get preferenceScores =>
      Map.unmodifiable(_preferenceScores);

  Map<String, double> get locationScores =>
      Map.unmodifiable(_locationScores);

  Map<String, double> get travelStyleScores =>
      Map.unmodifiable(_travelStyleScores);

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isSavingInterests => _isSavingInterests;

  String? get errorMessage => _errorMessage;

  User? get currentUser => _auth.currentUser;

  bool isSelected(String categoryId) =>
      _selectedInterestIds.contains(categoryId);

  // ============================================================
  // ONBOARDING
  // ============================================================

  Future<bool> needsOnboarding() async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      final snapshot =
      await _firestore.collection('users').doc(user.uid).get();

      if (!snapshot.exists) {
        return true;
      }

      final data =
          snapshot.data() ?? <String, dynamic>{};

      return data['onboardingCompleted'] != true;
    } catch (e) {
      debugPrint('Check onboarding error: $e');
      return true;
    }
  }

  Future<void> loadCategories() async {
    try {
      _isLoadingCategories = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot =
      await _firestore.collection('categories').get();

      _categories
        ..clear()
        ..addAll(
          snapshot.docs
              .where((doc) {
            final data = doc.data();

            return (data['status'] ?? 'Active')
                .toString() ==
                'Active';
          })
              .map(
                (doc) => InterestCategory(
              id: doc.id,
              name:
              (doc.data()['name'] ?? '')
                  .toString()
                  .trim(),
            ),
          )
              .where(
                (item) => item.name.isNotEmpty,
          ),
        );

      _categories.sort(
            (a, b) => a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        ),
      );

      final user = _auth.currentUser;

      if (user != null) {
        final userDoc =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        final data = userDoc.data();

        if (data != null &&
            data['selectedInterests'] is List) {
          _selectedInterestIds
            ..clear()
            ..addAll(
              (data['selectedInterests'] as List)
                  .map((e) => e.toString())
                  .where(
                    (e) => e.isNotEmpty,
              ),
            );
        }
      }
    } catch (e) {
      _errorMessage =
      'Unable to load interests.';

      debugPrint(
        'Load interest categories error: $e',
      );
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  void toggleInterest(String categoryId) {
    if (_selectedInterestIds.contains(categoryId)) {
      _selectedInterestIds.remove(categoryId);
    } else {
      _selectedInterestIds.add(categoryId);
    }

    notifyListeners();
  }

  Future<bool> saveInitialInterests() async {
    final user = _auth.currentUser;

    if (user == null) {
      _errorMessage =
      'Please login again.';
      notifyListeners();
      return false;
    }

    if (_selectedInterestIds.isEmpty) {
      _errorMessage =
      'Please select at least one interest.';
      notifyListeners();
      return false;
    }

    try {
      _isSavingInterests = true;
      _errorMessage = null;
      notifyListeners();

      final selectedNames =
      <String, String>{};

      final initialScores =
      <String, double>{};

      for (final category in _categories) {
        if (_selectedInterestIds
            .contains(category.id)) {
          selectedNames[category.id] =
              category.name;

          // Initial onboarding preference remains the strongest
          // starting signal for a new user.
          initialScores[category.id] =
          10.0;
        }
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'onboardingCompleted': true,
          'selectedInterests':
          _selectedInterestIds.toList(),
          'selectedInterestNames':
          selectedNames,
          'preferenceScores':
          initialScores,
          'locationScores':
          <String, double>{},
          'travelStyleScores':
          <String, double>{},
          'interestUpdatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _preferenceScores =
      Map<String, double>.from(
        initialScores,
      );

      return true;
    } catch (e) {
      _errorMessage =
      'Unable to save your interests.';

      debugPrint(
        'Save initial interests error: $e',
      );

      return false;
    } finally {
      _isSavingInterests = false;
      notifyListeners();
    }
  }

  // ============================================================
  // LOAD HOME RECOMMENDATIONS
  // ============================================================

  Future<void> loadRecommendations() async {
    final user = _auth.currentUser;

    try {
      _isLoadingRecommendations = true;
      _errorMessage = null;
      notifyListeners();

      final attractionSnapshot =
      await _firestore
          .collection('attractions')
          .get();

      _allActiveAttractions
        ..clear()
        ..addAll(
          attractionSnapshot.docs
              .map(
            AttractionModel.fromFirestore,
          )
              .where(
                (item) =>
            item.status
                .trim()
                .toLowerCase() ==
                'active',
          ),
        );

      _preferenceScores = {};
      _locationScores = {};
      _travelStyleScores = {};

      if (user != null) {
        final userDoc =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        final data = userDoc.data();

        if (data != null) {
          _preferenceScores =
              _readDoubleMap(
                data['preferenceScores'],
              );

          _locationScores =
              _readDoubleMap(
                data['locationScores'],
              );

          _travelStyleScores =
              _readDoubleMap(
                data['travelStyleScores'],
              );
        }
      }

      _buildRecommendations();
    } catch (e) {
      _errorMessage =
      'Unable to load recommendations.';

      debugPrint(
        'Load recommendation error: $e',
      );
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecommendations() async {
    await loadRecommendations();
  }

  // ============================================================
  // HOME RECOMMENDATION RANKING
  // ============================================================

  void _buildRecommendations() {
    final scored = _allActiveAttractions
        .map(
          (attraction) => _ScoredAttraction(
        attraction: attraction,
        score:
        _scoreAttraction(attraction),
      ),
    )
        .toList();

    scored.sort((a, b) {
      final scoreCompare =
      b.score.compareTo(a.score);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return b.attraction.createdAt
          .compareTo(
        a.attraction.createdAt,
      );
    });

    /*
     * Keep recommendation diversity.
     *
     * We determine a "dominant category" for each attraction using
     * the user's strongest matching category score. This is better
     * than always using only attraction.categoryId because attractions
     * can now have multiple category tags.
     */
    final result =
    <AttractionModel>[];

    final usedIds =
    <String>{};

    final categoryCounts =
    <String, int>{};

    for (final item in scored) {
      if (result.length >= 12) {
        break;
      }

      final diversityKey =
      _dominantCategoryId(
        item.attraction,
      );

      final count =
          categoryCounts[diversityKey] ?? 0;

      if (count < 4 ||
          result.length < 4) {
        result.add(
          item.attraction,
        );

        usedIds.add(
          item.attraction.id,
        );

        categoryCounts[diversityKey] =
            count + 1;
      }
    }

    if (result.length <
        min(12, scored.length)) {
      for (final item in scored) {
        if (result.length >= 12) {
          break;
        }

        if (usedIds.add(
          item.attraction.id,
        )) {
          result.add(
            item.attraction,
          );
        }
      }
    }

    _recommendedAttractions
      ..clear()
      ..addAll(result);
  }

  double _scoreAttraction(
      AttractionModel attraction,
      ) {
    final categoryScore =
    _categoryRecommendationComponent(
      attraction,
    );

    final locationScore =
    _locationRecommendationComponent(
      attraction,
    );

    final styleScore =
    _travelStyleRecommendationComponent(
      attraction,
    );

    final qualityScore =
    _qualityRecommendationComponent(
      attraction,
    );

    return categoryScore +
        locationScore +
        styleScore +
        qualityScore;
  }

  // ============================================================
  // 55% CATEGORY PREFERENCE
  // ============================================================

  double _categoryRecommendationComponent(
      AttractionModel attraction,
      ) {
    final categoryIds =
    _categoryIds(attraction);

    if (categoryIds.isEmpty ||
        _preferenceScores.isEmpty) {
      return 0;
    }

    final maxUserScore =
    _maximumMapScore(
      _preferenceScores,
    );

    if (maxUserScore <= 0) {
      return 0;
    }

    final matchedScores =
    categoryIds
        .map(
          (id) =>
      _preferenceScores[id] ??
          0,
    )
        .toList();

    /*
     * Average rather than sum.
     *
     * This prevents an attraction with 5 tags from automatically
     * beating an attraction with 1 highly relevant tag.
     */
    final average =
        matchedScores.fold<double>(
          0,
              (total, value) =>
          total + value,
        ) /
            matchedScores.length;

    final normalized =
    (average / maxUserScore)
        .clamp(0.0, 1.0);

    return normalized *
        _categoryComponentMax;
  }

  // ============================================================
  // 20% LOCATION PREFERENCE
  // ============================================================

  double _locationRecommendationComponent(
      AttractionModel attraction,
      ) {
    final state =
    attraction.state.trim();

    if (state.isEmpty ||
        _locationScores.isEmpty) {
      return 0;
    }

    final maxLocationScore =
    _maximumMapScore(
      _locationScores,
    );

    if (maxLocationScore <= 0) {
      return 0;
    }

    final userScore =
    _scoreForCaseInsensitiveKey(
      _locationScores,
      state,
    );

    return (userScore /
        maxLocationScore)
        .clamp(0.0, 1.0) *
        _locationComponentMax;
  }

  // ============================================================
  // 15% HISTORICAL TRAVEL STYLE
  // ============================================================

  double _travelStyleRecommendationComponent(
      AttractionModel attraction,
      ) {
    if (_travelStyleScores.isEmpty) {
      return 0;
    }

    final maxStyleScore =
    _maximumMapScore(
      _travelStyleScores,
    );

    if (maxStyleScore <= 0) {
      return 0;
    }

    double bestMatchedStyleScore = 0;

    for (final entry
    in _travelStyleScores.entries) {
      if (_attractionMatchesTravelStyle(
        attraction,
        entry.key,
      )) {
        bestMatchedStyleScore =
            max(
              bestMatchedStyleScore,
              entry.value,
            );
      }
    }

    return (bestMatchedStyleScore /
        maxStyleScore)
        .clamp(0.0, 1.0) *
        _travelStyleComponentMax;
  }

  bool _attractionMatchesTravelStyle(
      AttractionModel attraction,
      String travelStyle,
      ) {
    List<String>? keywords;

    for (final entry
    in _travelStyleKeywords.entries) {
      if (entry.key
          .trim()
          .toLowerCase() ==
          travelStyle
              .trim()
              .toLowerCase()) {
        keywords =
            entry.value;
        break;
      }
    }

    if (keywords == null ||
        keywords.isEmpty) {
      return false;
    }

    final categoryText = [
      attraction.categoryName,
      ...attraction.categoryNames,
    ].join(' ').toLowerCase();

    final fallbackText = [
      attraction.name,
      attraction.description,
      attraction.area,
      ...attraction.highlights,
      ...attraction.facilities,
    ].join(' ').toLowerCase();

    for (final keyword in keywords) {
      final clean =
      keyword.toLowerCase();

      if (categoryText.contains(clean) ||
          fallbackText.contains(clean)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // 10% ATTRACTION QUALITY
  // ============================================================

  double _qualityRecommendationComponent(
      AttractionModel attraction,
      ) {
    double raw = 0;

    if (attraction.coverImageUrl
        .trim()
        .isNotEmpty ||
        attraction.imageUrls.isNotEmpty) {
      raw += 3;
    }

    if (attraction.description
        .trim()
        .isNotEmpty) {
      raw += 2;
    }

    if (attraction.highlights
        .isNotEmpty) {
      raw += 1.5;
    }

    if (attraction.openingHours
        .isNotEmpty ||
        attraction.isOpen24Hours ||
        (attraction.openingTime
            .trim()
            .isNotEmpty &&
            attraction.closingTime
                .trim()
                .isNotEmpty)) {
      raw += 1.5;
    }

    if (attraction.latitude != 0 &&
        attraction.longitude != 0) {
      raw += 1;
    }

    if (attraction.recommendedDuration
        .trim()
        .isNotEmpty) {
      raw += 1;
    }

    return raw
        .clamp(
      0,
      _qualityComponentMax,
    )
        .toDouble();
  }

  // ============================================================
  // EXISTING SIGNAL 1: VIEW ATTRACTION
  // ============================================================

  Future<void> recordView(
      AttractionModel attraction,
      ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    await _recordPersonalizationSignal(
      categoryWeights:
      _weightsForAllCategories(
        attraction,
        _viewCategoryWeight,
      ),
      locationWeights:
      _locationWeightForAttraction(
        attraction,
        _viewLocationWeight,
      ),
      travelStyleWeights:
      const {},
      interactionType:
      'view',
      extraData: {
        'attractionId':
        attraction.id,
        'attractionName':
        attraction.name,
        'categoryIds':
        _categoryIds(attraction),
        'categoryNames':
        _categoryNames(attraction),
        'state':
        attraction.state,
        'area':
        attraction.area,
      },
    );
  }

  // ============================================================
  // EXISTING SIGNAL 2: SEARCH
  // ============================================================

  Future<void> recordSearch({
    required String query,
    required List<AttractionModel>
    matchedAttractions,
  }) async {
    final user = _auth.currentUser;

    final cleanQuery =
    query.trim();

    if (user == null ||
        cleanQuery.isEmpty) {
      return;
    }

    final categoryWeights =
    <String, double>{};

    final locationWeights =
    <String, double>{};

    /*
     * Count each unique category/state once per submitted search.
     *
     * Example:
     * User repeatedly searches KL attractions:
     * Kuala Lumpur locationScores keeps increasing.
     */
    for (final attraction
    in matchedAttractions) {
      for (final categoryId
      in _categoryIds(attraction)) {
        categoryWeights[categoryId] =
            _searchCategoryWeight;
      }

      final state =
      attraction.state.trim();

      if (state.isNotEmpty) {
        locationWeights[state] =
            _searchLocationWeight;
      }
    }

    if (categoryWeights.isEmpty &&
        locationWeights.isEmpty) {
      await _recordInteractionOnly(
        interactionType:
        'search',
        extraData: {
          'query':
          cleanQuery,
          'matchedCategoryIds':
          <String>[],
          'matchedStates':
          <String>[],
        },
      );

      return;
    }

    await _recordPersonalizationSignal(
      categoryWeights:
      categoryWeights,
      locationWeights:
      locationWeights,
      travelStyleWeights:
      const {},
      interactionType:
      'search',
      extraData: {
        'query':
        cleanQuery,
        'matchedCategoryIds':
        categoryWeights.keys.toList(),
        'matchedStates':
        locationWeights.keys.toList(),
      },
    );
  }

  // ============================================================
  // EXISTING SIGNAL 3: WISHLIST / SAVE
  // ============================================================

  Future<void> recordWishlist(
      AttractionModel attraction,
      ) async {
    await _recordPersonalizationSignal(
      categoryWeights:
      _weightsForAllCategories(
        attraction,
        _wishlistCategoryWeight,
      ),
      locationWeights:
      _locationWeightForAttraction(
        attraction,
        _wishlistLocationWeight,
      ),
      travelStyleWeights:
      const {},
      interactionType:
      'wishlist',
      extraData: {
        'attractionId':
        attraction.id,
        'attractionName':
        attraction.name,
        'categoryIds':
        _categoryIds(attraction),
        'categoryNames':
        _categoryNames(attraction),
        'state':
        attraction.state,
        'area':
        attraction.area,
      },
    );
  }

  // ============================================================
  // EXISTING SIGNAL 4: ADD ATTRACTION TO TRIP
  // ============================================================

  Future<void> recordTripAdd(
      AttractionModel attraction,
      ) async {
    await _recordPersonalizationSignal(
      categoryWeights:
      _weightsForAllCategories(
        attraction,
        _tripAddCategoryWeight,
      ),
      locationWeights:
      _locationWeightForAttraction(
        attraction,
        _tripAddLocationWeight,
      ),
      travelStyleWeights:
      const {},
      interactionType:
      'trip_add',
      extraData: {
        'attractionId':
        attraction.id,
        'attractionName':
        attraction.name,
        'categoryIds':
        _categoryIds(attraction),
        'categoryNames':
        _categoryNames(attraction),
        'state':
        attraction.state,
        'area':
        attraction.area,
      },
    );
  }

  // ============================================================
  // NEW SIGNAL: AI GENERATED TRIP PREFERENCES
  // ============================================================
  //
  // Important:
  // Travel style receives only +1 because "Foodie" or "Culture Seeker"
  // may describe this one trip rather than the user's permanent identity.
  //
  // Destination gets +3 because actually generating a trip for KL/Penang
  // is a strong current-location-interest signal.
  //
  Future<void> recordGeneratedTripPreferences({
    required String? selectedState,
    required List<String> travelStyles,
  }) async {
    final cleanState =
        selectedState?.trim() ?? '';

    final locationWeights =
    <String, double>{};

    if (cleanState.isNotEmpty) {
      locationWeights[cleanState] =
          _generatedTripLocationWeight;
    }

    final travelStyleWeights =
    <String, double>{};

    for (final style in travelStyles) {
      final cleanStyle =
      style.trim();

      if (cleanStyle.isNotEmpty) {
        travelStyleWeights[cleanStyle] =
            _generatedTravelStyleWeight;
      }
    }

    if (locationWeights.isEmpty &&
        travelStyleWeights.isEmpty) {
      return;
    }

    await _recordPersonalizationSignal(
      categoryWeights:
      const {},
      locationWeights:
      locationWeights,
      travelStyleWeights:
      travelStyleWeights,
      interactionType:
      'generated_trip_preferences',
      extraData: {
        'selectedState':
        cleanState,
        'travelStyles':
        travelStyleWeights.keys.toList(),
      },
    );
  }

  // ============================================================
  // FIRESTORE UPDATE
  // ============================================================

  Future<void> _recordPersonalizationSignal({
    required Map<String, double>
    categoryWeights,
    required Map<String, double>
    locationWeights,
    required Map<String, double>
    travelStyleWeights,
    required String interactionType,
    required Map<String, dynamic>
    extraData,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final userRef =
    _firestore
        .collection('users')
        .doc(user.uid);

    try {
      await _firestore.runTransaction(
            (transaction) async {
          final snapshot =
          await transaction.get(
            userRef,
          );

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final currentCategoryScores =
          _readDoubleMap(
            data['preferenceScores'],
          );

          final currentLocationScores =
          _readDoubleMap(
            data['locationScores'],
          );

          final currentTravelStyleScores =
          _readDoubleMap(
            data['travelStyleScores'],
          );

          _applyWeights(
            currentCategoryScores,
            categoryWeights,
          );

          _applyWeights(
            currentLocationScores,
            locationWeights,
          );

          _applyWeights(
            currentTravelStyleScores,
            travelStyleWeights,
          );

          transaction.set(
            userRef,
            {
              'preferenceScores':
              currentCategoryScores,
              'locationScores':
              currentLocationScores,
              'travelStyleScores':
              currentTravelStyleScores,
              'recommendationUpdatedAt':
              FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        },
      );

      await userRef
          .collection('interactions')
          .add(
        {
          'type':
          interactionType,
          ...extraData,
          'categoryWeights':
          categoryWeights,
          'locationWeights':
          locationWeights,
          'travelStyleWeights':
          travelStyleWeights,
          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );

      /*
       * Update this controller instance immediately so Home does not
       * need to wait for a full app restart when this same controller
       * records a view/search/wishlist/trip-add action.
       */
      _applyWeights(
        _preferenceScores,
        categoryWeights,
      );

      _applyWeights(
        _locationScores,
        locationWeights,
      );

      _applyWeights(
        _travelStyleScores,
        travelStyleWeights,
      );

      _buildRecommendations();
      notifyListeners();
    } catch (e) {
      debugPrint(
        'Record personalization signal error: $e',
      );
    }
  }

  Future<void> _recordInteractionOnly({
    required String interactionType,
    required Map<String, dynamic>
    extraData,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('interactions')
          .add(
        {
          'type':
          interactionType,
          ...extraData,
          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      debugPrint(
        'Record interaction error: $e',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, double> _readDoubleMap(
      dynamic rawValue,
      ) {
    if (rawValue is! Map) {
      return {};
    }

    final raw =
    Map<String, dynamic>.from(
      rawValue,
    );

    return raw.map(
          (key, value) => MapEntry(
        key,
        value is num
            ? value.toDouble()
            : double.tryParse(
          value.toString(),
        ) ??
            0,
      ),
    );
  }

  void _applyWeights(
      Map<String, double> destination,
      Map<String, double> weights,
      ) {
    for (final entry in weights.entries) {
      destination[entry.key] =
          (destination[entry.key] ?? 0) +
              entry.value;
    }
  }

  List<String> _categoryIds(
      AttractionModel attraction,
      ) {
    final ids = <String>{
      ...attraction.categoryIds
          .map((value) => value.trim())
          .where(
            (value) => value.isNotEmpty,
      ),
      if (attraction.categoryId
          .trim()
          .isNotEmpty)
        attraction.categoryId.trim(),
    };

    return ids.toList();
  }

  List<String> _categoryNames(
      AttractionModel attraction,
      ) {
    final names = <String>{
      ...attraction.categoryNames
          .map((value) => value.trim())
          .where(
            (value) => value.isNotEmpty,
      ),
      if (attraction.categoryName
          .trim()
          .isNotEmpty)
        attraction.categoryName.trim(),
    };

    return names.toList();
  }

  Map<String, double> _weightsForAllCategories(
      AttractionModel attraction,
      double weight,
      ) {
    final result =
    <String, double>{};

    for (final id
    in _categoryIds(attraction)) {
      result[id] = weight;
    }

    return result;
  }

  Map<String, double>
  _locationWeightForAttraction(
      AttractionModel attraction,
      double weight,
      ) {
    final state =
    attraction.state.trim();

    if (state.isEmpty) {
      return {};
    }

    return {
      state: weight,
    };
  }

  double _maximumMapScore(
      Map<String, double> scores,
      ) {
    if (scores.isEmpty) {
      return 0;
    }

    double maximum = 0;

    for (final value in scores.values) {
      maximum =
          max(
            maximum,
            value,
          );
    }

    return maximum;
  }

  double _scoreForCaseInsensitiveKey(
      Map<String, double> source,
      String wantedKey,
      ) {
    final normalizedWanted =
    wantedKey
        .trim()
        .toLowerCase();

    for (final entry
    in source.entries) {
      if (entry.key
          .trim()
          .toLowerCase() ==
          normalizedWanted) {
        return entry.value;
      }
    }

    return 0;
  }

  String _dominantCategoryId(
      AttractionModel attraction,
      ) {
    final ids =
    _categoryIds(attraction);

    if (ids.isEmpty) {
      return 'uncategorized';
    }

    String bestId =
        ids.first;

    double bestScore =
        _preferenceScores[bestId] ?? 0;

    for (final id in ids.skip(1)) {
      final value =
          _preferenceScores[id] ?? 0;

      if (value > bestScore) {
        bestId = id;
        bestScore = value;
      }
    }

    return bestId;
  }
}

class _ScoredAttraction {
  final AttractionModel attraction;
  final double score;

  const _ScoredAttraction({
    required this.attraction,
    required this.score,
  });
}
