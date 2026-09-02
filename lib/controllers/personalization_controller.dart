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

  final List<InterestCategory> _categories = [];
  final List<AttractionModel> _allActiveAttractions = [];
  final List<AttractionModel> _recommendedAttractions = [];
  final Set<String> _selectedInterestIds = {};

  Map<String, double> _preferenceScores = {};

  bool _isLoadingCategories = false;
  bool _isLoadingRecommendations = false;
  bool _isSavingInterests = false;

  String? _errorMessage;

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

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isSavingInterests => _isSavingInterests;
  String? get errorMessage => _errorMessage;

  User? get currentUser => _auth.currentUser;

  bool isSelected(String categoryId) =>
      _selectedInterestIds.contains(categoryId);

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

      final data = snapshot.data() ?? <String, dynamic>{};

      return data['onboardingCompleted'] != true;
    } catch (e) {
      debugPrint('Check onboarding error: $e');

      // Safer UX for first setup: show interests if profile state
      // cannot be confirmed.
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
                return (data['status'] ?? 'Active').toString() == 'Active';
              })
              .map(
                (doc) => InterestCategory(
                  id: doc.id,
                  name: (doc.data()['name'] ?? '').toString().trim(),
                ),
              )
              .where((item) => item.name.isNotEmpty),
        );

      _categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      final user = _auth.currentUser;

      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        final data = userDoc.data();

        if (data != null && data['selectedInterests'] is List) {
          _selectedInterestIds
            ..clear()
            ..addAll(
              (data['selectedInterests'] as List)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty),
            );
        }
      }
    } catch (e) {
      _errorMessage = 'Unable to load interests.';
      debugPrint('Load interest categories error: $e');
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
      _errorMessage = 'Please login again.';
      notifyListeners();
      return false;
    }

    if (_selectedInterestIds.isEmpty) {
      _errorMessage = 'Please select at least one interest.';
      notifyListeners();
      return false;
    }

    try {
      _isSavingInterests = true;
      _errorMessage = null;
      notifyListeners();

      final selectedNames = <String, String>{};
      final initialScores = <String, double>{};

      for (final category in _categories) {
        if (_selectedInterestIds.contains(category.id)) {
          selectedNames[category.id] = category.name;
          initialScores[category.id] = 10.0;
        }
      }

      await _firestore.collection('users').doc(user.uid).set(
        {
          'onboardingCompleted': true,
          'selectedInterests': _selectedInterestIds.toList(),
          'selectedInterestNames': selectedNames,
          'preferenceScores': initialScores,
          'interestUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      _errorMessage = 'Unable to save your interests.';
      debugPrint('Save initial interests error: $e');
      return false;
    } finally {
      _isSavingInterests = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendations() async {
    final user = _auth.currentUser;

    try {
      _isLoadingRecommendations = true;
      _errorMessage = null;
      notifyListeners();

      final attractionSnapshot =
          await _firestore.collection('attractions').get();

      _allActiveAttractions
        ..clear()
        ..addAll(
          attractionSnapshot.docs
              .map(AttractionModel.fromFirestore)
              .where((item) => item.status == 'Active'),
        );

      _preferenceScores = {};

      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        final data = userDoc.data();

        if (data != null && data['preferenceScores'] is Map) {
          final raw =
              Map<String, dynamic>.from(data['preferenceScores'] as Map);

          _preferenceScores = raw.map(
            (key, value) => MapEntry(
              key,
              value is num
                  ? value.toDouble()
                  : double.tryParse(value.toString()) ?? 0,
            ),
          );
        }
      }

      _buildRecommendations();
    } catch (e) {
      _errorMessage = 'Unable to load recommendations.';
      debugPrint('Load recommendation error: $e');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecommendations() async {
    await loadRecommendations();
  }

  void _buildRecommendations() {
    final scored = _allActiveAttractions
        .map(
          (attraction) => _ScoredAttraction(
            attraction: attraction,
            score: _scoreAttraction(attraction),
          ),
        )
        .toList();

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return b.attraction.createdAt.compareTo(a.attraction.createdAt);
    });

    // Keep recommendations personalized without making the list
    // 100% one-category. First take the strongest items, then add
    // diversity from other categories.
    final result = <AttractionModel>[];
    final usedIds = <String>{};
    final categoryCounts = <String, int>{};

    for (final item in scored) {
      if (result.length >= 12) {
        break;
      }

      final categoryId = item.attraction.categoryId;
      final count = categoryCounts[categoryId] ?? 0;

      if (count < 4 || result.length < 4) {
        result.add(item.attraction);
        usedIds.add(item.attraction.id);
        categoryCounts[categoryId] = count + 1;
      }
    }

    if (result.length < min(12, scored.length)) {
      for (final item in scored) {
        if (result.length >= 12) {
          break;
        }

        if (usedIds.add(item.attraction.id)) {
          result.add(item.attraction);
        }
      }
    }

    _recommendedAttractions
      ..clear()
      ..addAll(result);
  }

  double _scoreAttraction(AttractionModel attraction) {
    double score = 0;

    score += _preferenceScores[attraction.categoryId] ?? 0;

    // Small quality bonuses prevent ties from looking random.
    if (attraction.coverImageUrl.trim().isNotEmpty ||
        attraction.imageUrls.isNotEmpty) {
      score += 0.30;
    }

    if (attraction.description.trim().isNotEmpty) {
      score += 0.20;
    }

    if (attraction.highlights.isNotEmpty) {
      score += 0.15;
    }

    return score;
  }

  Future<void> recordView(AttractionModel attraction) async {
    final user = _auth.currentUser;

    if (user == null || attraction.categoryId.trim().isEmpty) {
      return;
    }

    await _recordPreferenceSignal(
      categoryWeights: {
        attraction.categoryId: 1.0,
      },
      interactionType: 'view',
      extraData: {
        'attractionId': attraction.id,
        'attractionName': attraction.name,
        'categoryId': attraction.categoryId,
        'categoryName': attraction.categoryName,
      },
    );
  }

  Future<void> recordSearch({
    required String query,
    required List<AttractionModel> matchedAttractions,
  }) async {
    final user = _auth.currentUser;
    final cleanQuery = query.trim();

    if (user == null || cleanQuery.isEmpty) {
      return;
    }

    final categoryWeights = <String, double>{};

    for (final attraction in matchedAttractions) {
      final categoryId = attraction.categoryId.trim();

      if (categoryId.isEmpty) {
        continue;
      }

      // One search can strengthen several relevant categories,
      // but each category is counted only once.
      categoryWeights[categoryId] = 2.0;
    }

    if (categoryWeights.isEmpty) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('interactions')
          .add(
        {
          'type': 'search',
          'query': cleanQuery,
          'matchedCategoryIds': <String>[],
          'weight': 0,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      return;
    }

    await _recordPreferenceSignal(
      categoryWeights: categoryWeights,
      interactionType: 'search',
      extraData: {
        'query': cleanQuery,
        'matchedCategoryIds': categoryWeights.keys.toList(),
      },
    );
  }

  Future<void> recordWishlist(AttractionModel attraction) async {
    if (attraction.categoryId.trim().isEmpty) {
      return;
    }

    await _recordPreferenceSignal(
      categoryWeights: {
        attraction.categoryId: 3.0,
      },
      interactionType: 'wishlist',
      extraData: {
        'attractionId': attraction.id,
        'attractionName': attraction.name,
        'categoryId': attraction.categoryId,
        'categoryName': attraction.categoryName,
      },
    );
  }

  Future<void> recordTripAdd(AttractionModel attraction) async {
    if (attraction.categoryId.trim().isEmpty) {
      return;
    }

    await _recordPreferenceSignal(
      categoryWeights: {
        attraction.categoryId: 4.0,
      },
      interactionType: 'trip_add',
      extraData: {
        'attractionId': attraction.id,
        'attractionName': attraction.name,
        'categoryId': attraction.categoryId,
        'categoryName': attraction.categoryName,
      },
    );
  }

  Future<void> _recordPreferenceSignal({
    required Map<String, double> categoryWeights,
    required String interactionType,
    required Map<String, dynamic> extraData,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final userRef =
        _firestore.collection('users').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? <String, dynamic>{};

        final currentScores = <String, double>{};

        if (data['preferenceScores'] is Map) {
          final raw =
              Map<String, dynamic>.from(data['preferenceScores'] as Map);

          for (final entry in raw.entries) {
            currentScores[entry.key] = entry.value is num
                ? (entry.value as num).toDouble()
                : double.tryParse(entry.value.toString()) ?? 0;
          }
        }

        for (final entry in categoryWeights.entries) {
          currentScores[entry.key] =
              (currentScores[entry.key] ?? 0) + entry.value;
        }

        transaction.set(
          userRef,
          {
            'preferenceScores': currentScores,
            'recommendationUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      await userRef.collection('interactions').add(
        {
          'type': interactionType,
          ...extraData,
          'categoryWeights': categoryWeights,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      for (final entry in categoryWeights.entries) {
        _preferenceScores[entry.key] =
            (_preferenceScores[entry.key] ?? 0) + entry.value;
      }

      _buildRecommendations();
      notifyListeners();
    } catch (e) {
      debugPrint('Record personalization signal error: $e');
    }
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
