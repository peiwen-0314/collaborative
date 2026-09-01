import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/trip_plan.dart';

class AiTripPlannerController extends ChangeNotifier {
  static const List<String> travelStyles = [
    'Sustainable Explorer',
    'Culture Seeker',
    'Nature Lover',
    'Relax & Unwind',
    'Adventure Enthusiast',
    'Foodie',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripPlanPreferences preferences = TripPlanPreferences();

  bool _isLoading = false;
  String? _errorMessage;
  List<AttractionModel> _allAttractions = [];
  List<AttractionModel> _generatedAttractions = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AttractionModel> get allAttractions => List.unmodifiable(_allAttractions);
  List<AttractionModel> get generatedAttractions => List.unmodifiable(_generatedAttractions);

  List<String> get availableStates {
    final result = _allAttractions
        .where((a) => a.status.toLowerCase() == 'active')
        .map((a) => a.state.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  Future<void> loadAttractions() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      final snapshot = await _firestore.collection('attractions').get();
      _allAttractions = snapshot.docs
          .map(AttractionModel.fromFirestore)
          .where((a) => a.status.toLowerCase() == 'active')
          .toList();
    } catch (e) {
      debugPrint('AI Trip Planner load error: $e');
      _errorMessage = 'Unable to load attractions.';
      _allAttractions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStateSelection(String? value) { preferences.selectedState = value; notifyListeners(); }
  void setDates(DateTime start, DateTime end) { preferences.startDate = start; preferences.endDate = end; notifyListeners(); }
  void setAdults(int v) { preferences.adults = v.clamp(0, 20); notifyListeners(); }
  void setChildren(int v) { preferences.children = v.clamp(0, 20); notifyListeners(); }
  void setSeniors(int v) { preferences.seniors = v.clamp(0, 20); notifyListeners(); }
  void setBudget(double v) { preferences.budget = v.clamp(100, 3000); notifyListeners(); }
  void setTravelStyle(String v) { preferences.travelStyle = v; notifyListeners(); }

  void setAccessibility({bool? wheelchair, bool? stroller, bool? serviceAnimal}) {
    if (wheelchair != null) preferences.wheelchairAccessible = wheelchair;
    if (stroller != null) preferences.strollerFriendly = stroller;
    if (serviceAnimal != null) preferences.serviceAnimalFriendly = serviceAnimal;
    notifyListeners();
  }

  bool get canGenerate =>
      preferences.selectedState != null &&
      preferences.startDate != null &&
      preferences.endDate != null &&
      preferences.totalTravelers > 0 &&
      preferences.travelStyle != null;

  Future<bool> generateTrip() async {
    if (!canGenerate) {
      _errorMessage = 'Please complete destination, dates, travelers and travel style.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_allAttractions.isEmpty) {
        final snapshot = await _firestore.collection('attractions').get();
        _allAttractions = snapshot.docs
            .map(AttractionModel.fromFirestore)
            .where((a) => a.status.toLowerCase() == 'active')
            .toList();
      }

      final state = preferences.selectedState!.trim().toLowerCase();
      final candidates = _allAttractions.where((a) => a.state.trim().toLowerCase() == state).toList();
      if (candidates.isEmpty) {
        _generatedAttractions = [];
        _errorMessage = 'No active attractions found for ${preferences.selectedState}.';
        return false;
      }

      final scored = candidates.map((a) => MapEntry(a, _scoreAttraction(a))).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final desired = (preferences.totalDays <= 0 ? 1 : preferences.totalDays) * 3;
      _generatedAttractions = scored.take(desired.clamp(1, scored.length)).map((e) => e.key).toList();
      return _generatedAttractions.isNotEmpty;
    } catch (e) {
      debugPrint('Generate trip error: $e');
      _errorMessage = 'Unable to generate your trip.';
      _generatedAttractions = [];
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double _scoreAttraction(AttractionModel a) {
    double score = 0;
    final style = (preferences.travelStyle ?? '').toLowerCase();
    final haystack = '${a.categoryName} ${a.description} ${a.highlights.join(' ')}'.toLowerCase();
    bool any(List<String> words) => words.any(haystack.contains);

    if (style == 'sustainable explorer' && any(['eco','nature','green','conservation','sustainable','forest'])) score += 5;
    if (style == 'culture seeker' && any(['culture','cultural','heritage','history','historical','museum','temple'])) score += 5;
    if (style == 'nature lover' && any(['nature','forest','park','garden','waterfall','island','beach','mountain'])) score += 5;
    if (style == 'relax & unwind' && any(['beach','garden','spa','relax','scenic','lake','resort'])) score += 5;
    if (style == 'adventure enthusiast' && any(['hiking','trail','adventure','climb','cycling','kayak','water sport'])) score += 5;
    if (style == 'foodie' && any(['food','market','cuisine','restaurant','street food','local food'])) score += 5;

    final facilities = a.facilities.join(' ').toLowerCase();
    if (preferences.wheelchairAccessible && facilities.contains('wheelchair')) score += 2;
    if (preferences.strollerFriendly && facilities.contains('stroller')) score += 2;
    if (preferences.serviceAnimalFriendly && facilities.contains('animal')) score += 2;
    if (estimateAttractionFee(a) <= preferences.budget) score += 2;
    if (a.coverImageUrl.trim().isNotEmpty || a.imageUrls.isNotEmpty) score += 0.5;
    return score;
  }

  double estimateAttractionFee(AttractionModel a) {
    if (a.isFreeEntry) return 0;
    return (preferences.adults * a.malaysianAdultFee) +
        (preferences.children * a.malaysianChildFee) +
        (preferences.seniors * a.malaysianSeniorFee);
  }

  double get estimatedTotalAttractionCost => _generatedAttractions.fold(0, (sum, a) => sum + estimateAttractionFee(a));

  List<AttractionModel> attractionsForDay(int dayIndex) {
    if (_generatedAttractions.isEmpty) return [];
    final days = preferences.totalDays <= 0 ? 1 : preferences.totalDays;
    final perDay = (_generatedAttractions.length / days).ceil();
    final start = dayIndex * perDay;
    if (start >= _generatedAttractions.length) return [];
    final end = (start + perDay).clamp(0, _generatedAttractions.length);
    return _generatedAttractions.sublist(start, end);
  }
}
