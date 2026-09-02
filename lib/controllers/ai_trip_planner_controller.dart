import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/trip_plan.dart';
import '../models/trip_schedule_item.dart';

class AiTripPlannerController extends ChangeNotifier {
  static const List<String> travelStyles = [
    'Sustainable Explorer',
    'Culture Seeker',
    'Nature Lover',
    'Relax & Unwind',
    'Adventure Enthusiast',
    'Foodie',
  ];

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AiTripPlannerController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final TripPlanPreferences preferences = TripPlanPreferences();

  bool _isLoading = false;
  String? _errorMessage;

  List<AttractionModel> _allAttractions = [];
  List<AttractionModel> _generatedAttractions = [];
  List<TripScheduleItem> _generatedSchedule = [];

  Map<String, double> _userPreferenceScores = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AttractionModel> get allAttractions =>
      List.unmodifiable(_allAttractions);

  List<AttractionModel> get generatedAttractions =>
      List.unmodifiable(_generatedAttractions);

  List<TripScheduleItem> get generatedSchedule =>
      List.unmodifiable(_generatedSchedule);

  Map<String, double> get userPreferenceScores =>
      Map.unmodifiable(_userPreferenceScores);

  List<String> get availableStates {
    final states = _allAttractions
        .where((attraction) {
      return attraction.status.trim().toLowerCase() == 'active';
    })
        .map((attraction) => attraction.state.trim())
        .where((state) => state.isNotEmpty)
        .toSet()
        .toList();

    states.sort();
    return states;
  }

  Future<void> loadAttractions() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot =
      await _firestore.collection('attractions').get();

      _allAttractions = snapshot.docs
          .map(AttractionModel.fromFirestore)
          .where((attraction) {
        return attraction.status.trim().toLowerCase() == 'active';
      })
          .toList();
    } catch (e) {
      debugPrint('AI Trip Planner load attractions error: $e');

      _errorMessage = 'Unable to load attractions.';
      _allAttractions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStateSelection(String? value) {
    preferences.selectedState = value;
    notifyListeners();
  }

  void setDates(DateTime start, DateTime end) {
    preferences.startDate = start;
    preferences.endDate = end;
    notifyListeners();
  }

  void setAdults(int value) {
    preferences.adults = value.clamp(0, 20);
    notifyListeners();
  }

  void setChildren(int value) {
    preferences.children = value.clamp(0, 20);
    notifyListeners();
  }

  void setSeniors(int value) {
    preferences.seniors = value.clamp(0, 20);
    notifyListeners();
  }

  void setBudget(double value) {
    preferences.budget = value.clamp(100, 3000);
    notifyListeners();
  }

  void setTravelStyle(String value) {
    preferences.travelStyle = value;
    notifyListeners();
  }

  void setAccessibility({
    bool? wheelchair,
    bool? stroller,
    bool? serviceAnimal,
  }) {
    if (wheelchair != null) {
      preferences.wheelchairAccessible = wheelchair;
    }

    if (stroller != null) {
      preferences.strollerFriendly = stroller;
    }

    if (serviceAnimal != null) {
      preferences.serviceAnimalFriendly = serviceAnimal;
    }

    notifyListeners();
  }

  bool get canGenerate {
    return preferences.selectedState != null &&
        preferences.selectedState!.trim().isNotEmpty &&
        preferences.startDate != null &&
        preferences.endDate != null &&
        preferences.totalTravelers > 0 &&
        preferences.travelStyle != null &&
        preferences.travelStyle!.trim().isNotEmpty;
  }

  Future<bool> generateTrip() async {
    if (!canGenerate) {
      _errorMessage =
      'Please complete destination, dates, travelers and travel style.';

      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;

      _generatedAttractions = [];
      _generatedSchedule = [];

      notifyListeners();

      await _ensureAttractionsLoaded();
      await _loadUserPreferenceScores();

      final selectedState =
      preferences.selectedState!.trim().toLowerCase();

      final candidates = _allAttractions.where((attraction) {
        return attraction.status.trim().toLowerCase() == 'active' &&
            attraction.state.trim().toLowerCase() == selectedState;
      }).toList();

      if (candidates.isEmpty) {
        _errorMessage =
        'No active attractions found for ${preferences.selectedState}.';

        return false;
      }

      /*
       * Stage 1:
       * Rank every attraction based on user preference.
       *
       * Distance is NOT used here.
       * Therefore, a farther attraction can still receive a high score.
       */
      final rankedCandidates = candidates.map((attraction) {
        return _ScoredAttraction(
          attraction: attraction,
          score: _calculateRecommendationScore(attraction),
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      /*
       * We take more candidates than the final required number.
       *
       * Example:
       * final plan needs 6 places
       * candidate pool contains around 18 places
       *
       * This allows scheduling to consider opening hours,
       * budget and location without losing personalization.
       */
      final totalDays =
      preferences.totalDays <= 0 ? 1 : preferences.totalDays;

      final targetPlaces =
          totalDays * _maximumPlacesPerDay();

      final poolSize = math.min(
        rankedCandidates.length,
        math.max(targetPlaces * 3, targetPlaces),
      );

      final recommendationPool =
      rankedCandidates.take(poolSize).toList();

      _buildLogicalSchedule(recommendationPool);

      _generatedAttractions = _generatedSchedule
          .map((item) => item.attraction)
          .toList();

      if (_generatedAttractions.isEmpty) {
        _errorMessage =
        'No suitable attractions fit your budget and selected dates.';

        return false;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('Generate trip error: $e');
      debugPrint('$stackTrace');

      _errorMessage = 'Unable to generate your trip.';
      _generatedAttractions = [];
      _generatedSchedule = [];

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureAttractionsLoaded() async {
    if (_allAttractions.isNotEmpty) {
      return;
    }

    final snapshot =
    await _firestore.collection('attractions').get();

    _allAttractions = snapshot.docs
        .map(AttractionModel.fromFirestore)
        .where((attraction) {
      return attraction.status.trim().toLowerCase() == 'active';
    })
        .toList();
  }

  /*
   * Loads:
   *
   * users/{uid}.preferenceScores
   *
   * These scores already include:
   * - first-login selected interests
   * - views
   * - searches
   * - wishlist actions
   * - trip-add actions
   */
  Future<void> _loadUserPreferenceScores() async {
    _userPreferenceScores = {};

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final snapshot =
      await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data();

      if (data == null || data['preferenceScores'] is! Map) {
        return;
      }

      final rawScores =
      Map<String, dynamic>.from(data['preferenceScores'] as Map);

      _userPreferenceScores = rawScores.map(
            (categoryId, value) {
          final score = value is num
              ? value.toDouble()
              : double.tryParse(value.toString()) ?? 0;

          return MapEntry(categoryId, score);
        },
      );
    } catch (e) {
      /*
       * User preference is optional.
       * Trip generation can continue using travel style.
       */
      debugPrint('Load trip preference scores error: $e');
      _userPreferenceScores = {};
    }
  }

  double _calculateRecommendationScore(
      AttractionModel attraction,
      ) {
    double score = 0;

    /*
     * 1. First-login interest and user behaviour: maximum 35.
     *
     * The raw score can continue increasing in Firebase,
     * but its trip-planner contribution is capped.
     */
    final rawUserPreference =
        _userPreferenceScores[attraction.categoryId] ?? 0;

    score += rawUserPreference.clamp(0, 35).toDouble();

    /*
     * 2. Current travel style: maximum 45.
     *
     * Current trip selection receives the highest single weight.
     */
    if (_matchesTravelStyle(attraction)) {
      score += 45;
    }

    /*
     * 3. Accessibility suitability: maximum 10.
     */
    score += _accessibilityScore(attraction);

    /*
     * 4. Attraction data quality: maximum 10.
     */
    score += _qualityScore(attraction);

    return score.clamp(0, 100).toDouble();
  }

  bool _matchesTravelStyle(AttractionModel attraction) {
    final style =
    (preferences.travelStyle ?? '').trim().toLowerCase();

    final haystack = [
      attraction.name,
      attraction.categoryName,
      attraction.description,
      attraction.area,
      ...attraction.highlights,
    ].join(' ').toLowerCase();

    bool containsAny(List<String> words) {
      return words.any((word) => haystack.contains(word));
    }

    switch (style) {
      case 'sustainable explorer':
        return containsAny([
          'eco',
          'nature',
          'green',
          'conservation',
          'sustainable',
          'forest',
          'environment',
        ]);

      case 'culture seeker':
        return containsAny([
          'culture',
          'cultural',
          'heritage',
          'history',
          'historical',
          'museum',
          'temple',
          'traditional',
        ]);

      case 'nature lover':
        return containsAny([
          'nature',
          'forest',
          'park',
          'garden',
          'waterfall',
          'island',
          'beach',
          'mountain',
          'wildlife',
        ]);

      case 'relax & unwind':
        return containsAny([
          'beach',
          'garden',
          'spa',
          'relax',
          'scenic',
          'lake',
          'resort',
          'view',
        ]);

      case 'adventure enthusiast':
        return containsAny([
          'hiking',
          'trail',
          'adventure',
          'climb',
          'cycling',
          'kayak',
          'water sport',
          'outdoor',
        ]);

      case 'foodie':
        return containsAny([
          'food',
          'market',
          'cuisine',
          'restaurant',
          'street food',
          'local food',
          'cafe',
        ]);

      default:
        return false;
    }
  }

  double _accessibilityScore(AttractionModel attraction) {
    final facilities =
    attraction.facilities.join(' ').toLowerCase();

    double score = 0;
    int requested = 0;
    int matched = 0;

    if (preferences.wheelchairAccessible) {
      requested++;

      if (facilities.contains('wheelchair')) {
        matched++;
      }
    }

    if (preferences.strollerFriendly) {
      requested++;

      if (facilities.contains('stroller')) {
        matched++;
      }
    }

    if (preferences.serviceAnimalFriendly) {
      requested++;

      if (facilities.contains('service animal') ||
          facilities.contains('animal friendly') ||
          facilities.contains('pet friendly')) {
        matched++;
      }
    }

    if (requested == 0) {
      return 5;
    }

    score = (matched / requested) * 10;
    return score.clamp(0, 10).toDouble();
  }

  double _qualityScore(AttractionModel attraction) {
    double score = 0;

    if (attraction.coverImageUrl.trim().isNotEmpty ||
        attraction.imageUrls.isNotEmpty) {
      score += 2.5;
    }

    if (attraction.description.trim().isNotEmpty) {
      score += 2;
    }

    if (attraction.highlights.isNotEmpty) {
      score += 1.5;
    }

    if (attraction.openingTime.trim().isNotEmpty &&
        attraction.closingTime.trim().isNotEmpty) {
      score += 1.5;
    }

    if (attraction.recommendedDuration.trim().isNotEmpty) {
      score += 1.5;
    }

    if (attraction.latitude != 0 &&
        attraction.longitude != 0) {
      score += 1;
    }

    return score.clamp(0, 10).toDouble();
  }

  void _buildLogicalSchedule(
      List<_ScoredAttraction> recommendationPool,
      ) {
    _generatedSchedule = [];

    final remaining =
    List<_ScoredAttraction>.from(recommendationPool);

    final totalDays =
    preferences.totalDays <= 0 ? 1 : preferences.totalDays;

    double usedBudget = 0;

    for (int dayIndex = 0;
    dayIndex < totalDays;
    dayIndex++) {
      DateTime currentTime =
      _dateForDay(dayIndex, 9, 0);

      final dayEnd =
      _dateForDay(dayIndex, 18, 0);

      AttractionModel? previousAttraction;
      int placesToday = 0;
      bool lunchAdded = false;

      while (remaining.isNotEmpty &&
          placesToday < _maximumPlacesPerDay()) {
        final selection = _chooseNextAttraction(
          remaining: remaining,
          previousAttraction: previousAttraction,
          currentTime: currentTime,
          dayEnd: dayEnd,
          dayIndex: dayIndex,
          lunchAdded: lunchAdded,
          usedBudget: usedBudget,
        );

        if (selection == null) {
          break;
        }

        final selected =
        remaining.removeAt(selection.index);

        final attraction = selected.attraction;

        final transportMinutes =
        previousAttraction == null
            ? 0
            : estimateTransportMinutes(
          previousAttraction,
          attraction,
        );

        currentTime = currentTime.add(
          Duration(minutes: transportMinutes),
        );

        /*
         * Reserve one-hour lunch between 12 PM and 2 PM.
         */
        if (!lunchAdded &&
            currentTime.hour >= 12 &&
            currentTime.hour < 14) {
          currentTime = currentTime.add(
            const Duration(hours: 1),
          );

          lunchAdded = true;
        }

        final openingTime =
        _openingDateTime(attraction, dayIndex);

        final closingTime =
        _closingDateTime(attraction, dayIndex);

        if (currentTime.isBefore(openingTime)) {
          currentTime = openingTime;
        }

        final visitMinutes =
        _recommendedVisitMinutes(attraction);

        final visitEnd = currentTime.add(
          Duration(minutes: visitMinutes),
        );

        if (visitEnd.isAfter(closingTime) ||
            visitEnd.isAfter(dayEnd)) {
          /*
           * This attraction may fit on another day.
           */
          remaining.add(selected);
          break;
        }

        final fee = estimateAttractionFee(attraction);

        _generatedSchedule.add(
          TripScheduleItem(
            attraction: attraction,
            dayIndex: dayIndex,
            startTime: currentTime,
            endTime: visitEnd,
            visitMinutes: visitMinutes,
            transportMinutesBefore: transportMinutes,
            estimatedFee: fee,
            recommendationScore: selected.score,
          ),
        );

        usedBudget += fee;
        placesToday++;
        previousAttraction = attraction;

        currentTime = visitEnd.add(
          Duration(minutes: _bufferMinutes()),
        );
      }
    }
  }

  /*
   * Interest is more important than distance.
   *
   * 80% = recommendation/personalization
   * 20% = nearby convenience
   *
   * Therefore:
   * - nearby places get a small advantage
   * - a far but highly relevant attraction can still be selected
   */
  _CandidateSelection? _chooseNextAttraction({
    required List<_ScoredAttraction> remaining,
    required AttractionModel? previousAttraction,
    required DateTime currentTime,
    required DateTime dayEnd,
    required int dayIndex,
    required bool lunchAdded,
    required double usedBudget,
  }) {
    int bestIndex = -1;
    double bestCombinedScore = -double.infinity;

    for (int index = 0;
    index < remaining.length;
    index++) {
      final candidate = remaining[index];
      final attraction = candidate.attraction;
      final fee = estimateAttractionFee(attraction);

      if (preferences.budget > 0 &&
          usedBudget + fee > preferences.budget) {
        continue;
      }

      final transportMinutes =
      previousAttraction == null
          ? 0
          : estimateTransportMinutes(
        previousAttraction,
        attraction,
      );

      DateTime possibleStart = currentTime.add(
        Duration(minutes: transportMinutes),
      );

      if (!lunchAdded &&
          possibleStart.hour >= 12 &&
          possibleStart.hour < 14) {
        possibleStart = possibleStart.add(
          const Duration(hours: 1),
        );
      }

      final opening =
      _openingDateTime(attraction, dayIndex);

      final closing =
      _closingDateTime(attraction, dayIndex);

      if (possibleStart.isBefore(opening)) {
        possibleStart = opening;
      }

      final possibleEnd = possibleStart.add(
        Duration(
          minutes: _recommendedVisitMinutes(attraction),
        ),
      );

      if (possibleEnd.isAfter(closing) ||
          possibleEnd.isAfter(dayEnd)) {
        continue;
      }

      /*
       * Convert recommendation score from 0–100 to 0–80.
       */
      final interestPart =
          candidate.score * 0.80;

      /*
       * Convert transport time to a 0–20 proximity bonus.
       *
       * 0 minutes  = 20
       * 20 minutes = around 15
       * 40 minutes = around 10
       * 80 minutes = 0
       */
      final proximityPart = previousAttraction == null
          ? 10.0
          : (20 - transportMinutes / 4)
          .clamp(0, 20)
          .toDouble();

      final combinedScore =
          interestPart + proximityPart;

      if (combinedScore > bestCombinedScore) {
        bestCombinedScore = combinedScore;
        bestIndex = index;
      }
    }

    if (bestIndex == -1) {
      return null;
    }

    return _CandidateSelection(
      index: bestIndex,
      combinedScore: bestCombinedScore,
    );
  }

  double estimateAttractionFee(
      AttractionModel attraction,
      ) {
    if (attraction.isFreeEntry) {
      return 0;
    }

    return (preferences.adults *
        attraction.malaysianAdultFee) +
        (preferences.children *
            attraction.malaysianChildFee) +
        (preferences.seniors *
            attraction.malaysianSeniorFee);
  }

  double get estimatedTotalAttractionCost {
    return _generatedSchedule.fold(
      0,
          (total, item) => total + item.estimatedFee,
    );
  }

  List<AttractionModel> attractionsForDay(
      int dayIndex,
      ) {
    return scheduleForDay(dayIndex)
        .map((item) => item.attraction)
        .toList();
  }

  List<TripScheduleItem> scheduleForDay(
      int dayIndex,
      ) {
    final result = _generatedSchedule
        .where((item) => item.dayIndex == dayIndex)
        .toList();

    result.sort(
          (a, b) => a.startTime.compareTo(b.startTime),
    );

    return result;
  }

  /*
   * No route API.
   *
   * Uses straight-line distance to estimate transport time.
   */
  int estimateTransportMinutes(
      AttractionModel from,
      AttractionModel to,
      ) {
    if (from.latitude == 0 ||
        from.longitude == 0 ||
        to.latitude == 0 ||
        to.longitude == 0) {
      /*
       * Fallback if geocoding has not completed.
       */
      if (from.area.trim().toLowerCase() ==
          to.area.trim().toLowerCase()) {
        return 15;
      }

      return 30;
    }

    final distanceKm = _distanceInKm(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (distanceKm <= 1) return 8;
    if (distanceKm <= 3) return 12;
    if (distanceKm <= 5) return 18;
    if (distanceKm <= 10) return 25;
    if (distanceKm <= 20) return 40;
    if (distanceKm <= 35) return 55;

    return math.min(
      90,
      (distanceKm * 2).ceil(),
    );
  }

  double _distanceInKm(
      double latitude1,
      double longitude1,
      double latitude2,
      double longitude2,
      ) {
    const earthRadiusKm = 6371.0;

    double radians(double degrees) {
      return degrees * math.pi / 180;
    }

    final latitudeDifference =
    radians(latitude2 - latitude1);

    final longitudeDifference =
    radians(longitude2 - longitude1);

    final value =
        math.sin(latitudeDifference / 2) *
            math.sin(latitudeDifference / 2) +
            math.cos(radians(latitude1)) *
                math.cos(radians(latitude2)) *
                math.sin(longitudeDifference / 2) *
                math.sin(longitudeDifference / 2);

    final angle = 2 *
        math.atan2(
          math.sqrt(value),
          math.sqrt(1 - value),
        );

    return earthRadiusKm * angle;
  }

  int _recommendedVisitMinutes(
      AttractionModel attraction,
      ) {
    final value = attraction.recommendedDuration
        .trim()
        .toLowerCase();

    if (value.isEmpty) {
      return 90;
    }

    final match = RegExp(
      r'[0-9]+(?:\.[0-9]+)?',
    ).firstMatch(value);

    if (match == null) {
      return 90;
    }

    final number =
    double.tryParse(match.group(0) ?? '');

    if (number == null) {
      return 90;
    }

    if (value.contains('hour') ||
        value.contains('hr')) {
      return (number * 60)
          .round()
          .clamp(30, 360);
    }

    return number
        .round()
        .clamp(30, 360);
  }

  DateTime _openingDateTime(
      AttractionModel attraction,
      int dayIndex,
      ) {
    final minutes = _parseTime(
      attraction.openingTime,
      9 * 60,
    );

    return _dateForDay(
      dayIndex,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  DateTime _closingDateTime(
      AttractionModel attraction,
      int dayIndex,
      ) {
    final minutes = _parseTime(
      attraction.closingTime,
      18 * 60,
    );

    return _dateForDay(
      dayIndex,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  int _parseTime(
      String rawValue,
      int fallback,
      ) {
    final value =
    rawValue.trim().toUpperCase();

    if (value.isEmpty) {
      return fallback;
    }

    final match = RegExp(
      r'(\d{1,2})[:.]?(\d{2})?\s*(AM|PM)?',
    ).firstMatch(value);

    if (match == null) {
      return fallback;
    }

    int hour =
        int.tryParse(match.group(1) ?? '') ?? 0;

    final minute =
        int.tryParse(match.group(2) ?? '') ?? 0;

    final period = match.group(3);

    if (period == 'PM' && hour < 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    if (hour > 23 || minute > 59) {
      return fallback;
    }

    return hour * 60 + minute;
  }

  DateTime _dateForDay(
      int dayIndex,
      int hour,
      int minute,
      ) {
    final startDate =
        preferences.startDate ?? DateTime.now();

    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day + dayIndex,
      hour,
      minute,
    );
  }

  int _maximumPlacesPerDay() {
    final style =
    (preferences.travelStyle ?? '')
        .toLowerCase();

    if (style.contains('relax')) {
      return 3;
    }

    if (style.contains('adventure')) {
      return 5;
    }

    return 4;
  }

  int _bufferMinutes() {
    final style =
    (preferences.travelStyle ?? '')
        .toLowerCase();

    if (style.contains('relax')) {
      return 20;
    }

    if (style.contains('adventure')) {
      return 8;
    }

    return 12;
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

class _CandidateSelection {
  final int index;
  final double combinedScore;

  const _CandidateSelection({
    required this.index,
    required this.combinedScore,
  });
}