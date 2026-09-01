import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';

class MobileHomeController extends ChangeNotifier {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  List<AttractionModel> _recommendedAttractions = [];

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  List<AttractionModel> get recommendedAttractions =>
      List.unmodifiable(_recommendedAttractions);

  // ============================================================
  // LOAD HOME DATA
  // ============================================================

  Future<void> loadHomeData() async {
    await loadRecommendedAttractions();
  }

  // ============================================================
  // LOAD RECOMMENDED ATTRACTIONS
  // ============================================================

  Future<void> loadRecommendedAttractions() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('attractions')
          .get();

      final attractions = snapshot.docs
          .map(
            (doc) => AttractionModel.fromFirestore(doc),
      )
          .where(
            (attraction) =>
        attraction.status.toLowerCase() == 'active',
      )
          .toList();

      // Newer attractions first.
      attractions.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      _recommendedAttractions =
          attractions.take(8).toList();
    } catch (e) {
      debugPrint(
        'Load recommended attractions error: $e',
      );

      _errorMessage =
      'Unable to load recommendations.';

      _recommendedAttractions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    await loadHomeData();
  }
}