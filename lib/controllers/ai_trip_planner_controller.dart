import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/trip_plan.dart';
import '../models/trip_schedule_item.dart';
import '../models/here_route_info.dart';
import '../models/here_matrix_result.dart';
import '../services/here_routing_service.dart';
import '../services/here_matrix_routing_service.dart';

class AiTripPlannerController extends ChangeNotifier {
  static const List<String> travelStyles = [
    'Sustainable Explorer',
    'Culture Seeker',
    'Nature Lover',
    'Relax & Unwind',
    'Adventure Enthusiast',
    'Foodie',
  ];

  static const int maxTravelStyles = 3;

  /// Travel styles are user-friendly personas, while attraction categories
  /// are database tags. We map each style to category/tag keywords instead
  /// of forcing travel style names to be identical to category names.
  ///
  /// The matching is case-insensitive and works with multiple categoryNames.
  static const Map<String, Map<String, double>>
  travelStyleCategoryWeights = {
    'Sustainable Explorer': {
      'eco': 3.0,
      'sustainable': 3.0,
      'green': 2.8,
      'nature': 2.5,
      'conservation': 2.8,
      'environment': 2.5,
      'community': 1.6,
      'local': 1.3,
    },
    'Culture Seeker': {
      'culture': 3.0,
      'cultural': 3.0,
      'heritage': 3.0,
      'history': 2.6,
      'historical': 2.6,
      'museum': 2.5,
      'religious': 2.0,
      'temple': 2.0,
      'architecture': 2.0,
      'traditional': 1.8,
    },
    'Nature Lover': {
      'nature': 3.0,
      'forest': 2.7,
      'park': 2.4,
      'garden': 2.2,
      'waterfall': 2.7,
      'island': 2.3,
      'beach': 2.5,
      'mountain': 2.7,
      'wildlife': 2.6,
      'scenic': 1.8,
    },
    'Relax & Unwind': {
      'beach': 3.0,
      'garden': 2.2,
      'spa': 3.0,
      'relax': 3.0,
      'leisure': 2.7,
      'scenic': 2.4,
      'lake': 2.2,
      'resort': 2.5,
      'view': 1.8,
    },
    'Adventure Enthusiast': {
      'adventure': 3.0,
      'hiking': 3.0,
      'trail': 2.8,
      'trekking': 2.8,
      'climb': 2.7,
      'cycling': 2.6,
      'kayak': 2.7,
      'water sport': 2.7,
      'outdoor': 2.5,
      'extreme': 2.2,
    },
    'Foodie': {
      'food': 3.0,
      'market': 2.7,
      'cuisine': 2.8,
      'restaurant': 2.5,
      'street food': 3.0,
      'local food': 3.0,
      'cafe': 2.2,
      'culinary': 2.7,
      'dining': 2.2,
    },
  };


  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final HereRoutingService _hereRoutingService;
  final HereMatrixRoutingService _hereMatrixRoutingService;

  AiTripPlannerController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    HereRoutingService? hereRoutingService,
    HereMatrixRoutingService? hereMatrixRoutingService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _hereRoutingService =
            hereRoutingService ?? HereRoutingService(),
        _hereMatrixRoutingService =
            hereMatrixRoutingService ??
                HereMatrixRoutingService();

  final TripPlanPreferences preferences = TripPlanPreferences();

  bool _isLoading = false;
  String? _errorMessage;

  List<AttractionModel> _allAttractions = [];
  List<AttractionModel> _generatedAttractions = [];
  List<TripScheduleItem> _generatedSchedule = [];

  Map<String, double> _userPreferenceScores = {};

  final Map<String, HereRouteInfo> _routeCache = {};

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

  bool isTravelStyleSelected(String value) {
    return preferences.travelStyles.contains(value);
  }

  /// Toggle one travel style.
  /// Returns false only when the user tries to select more than 3 styles.
  bool toggleTravelStyle(String value) {
    if (preferences.travelStyles.contains(value)) {
      preferences.travelStyles.remove(value);
      notifyListeners();
      return true;
    }

    if (preferences.travelStyles.length >= maxTravelStyles) {
      return false;
    }

    preferences.travelStyles.add(value);
    notifyListeners();
    return true;
  }

  void clearTravelStyles() {
    preferences.travelStyles.clear();
    notifyListeners();
  }

  bool get canGenerate {
    return preferences.selectedState != null &&
        preferences.selectedState!.trim().isNotEmpty &&
        preferences.startDate != null &&
        preferences.endDate != null &&
        preferences.totalTravelers > 0 &&
        preferences.travelStyles.isNotEmpty;
  }

  Future<bool> generateTrip() async {
    if (!canGenerate) {
      _errorMessage =
      'Please complete destination, dates, travelers and at least one travel style.';

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

      await _buildLogicalSchedule(recommendationPool);

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
     * 1. Existing personalization / behaviour: maximum 35.
     *
     * An attraction may have multiple category IDs, therefore we consider
     * ALL its category IDs instead of only categoryId.
     */
    final userPreferenceScore =
    _userPreferenceScoreForAttraction(attraction);

    score += userPreferenceScore.clamp(0, 35).toDouble();

    /*
     * 2. Current trip travel styles: maximum 55.
     *
     * Multiple selected styles can contribute. Matching uses the attraction's
     * multiple category tags first, with description/highlights as a fallback.
     */
    score += _travelStyleScore(attraction);

    /*
     * 3. Attraction data quality: maximum 10.
     *
     * Accessibility scoring was removed because the current attraction data
     * does not reliably store wheelchair/stroller/service-animal suitability.
     */
    score += _qualityScore(attraction);

    return score.clamp(0, 100).toDouble();
  }

  double _userPreferenceScoreForAttraction(
      AttractionModel attraction,
      ) {
    final categoryIds = <String>{
      ...attraction.categoryIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty),
      if (attraction.categoryId.trim().isNotEmpty)
        attraction.categoryId.trim(),
    };

    if (categoryIds.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final categoryId in categoryIds) {
      total += _userPreferenceScores[categoryId] ?? 0;
    }

    // Averaging prevents attractions with many category tags from receiving
    // an unfairly large personalization score solely because they have more tags.
    return total / categoryIds.length;
  }

  double _travelStyleScore(
      AttractionModel attraction,
      ) {
    if (preferences.travelStyles.isEmpty) {
      return 0;
    }

    final categoryText = <String>{
      ...attraction.categoryNames,
      attraction.categoryName,
    }
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .join(' | ');

    final fallbackText = [
      attraction.name,
      attraction.description,
      attraction.area,
      ...attraction.highlights,
      ...attraction.facilities,
    ].join(' ').toLowerCase();

    double rawScore = 0;

    for (final selectedStyle in preferences.travelStyles) {
      final weights =
      travelStyleCategoryWeights[selectedStyle];

      if (weights == null) {
        continue;
      }

      double bestMatchForStyle = 0;

      for (final entry in weights.entries) {
        final keyword = entry.key.toLowerCase();

        // Category tag match is the strongest signal.
        if (categoryText.contains(keyword)) {
          bestMatchForStyle =
              math.max(bestMatchForStyle, entry.value);
          continue;
        }

        // Description/highlight/facility match is a weaker fallback.
        if (fallbackText.contains(keyword)) {
          bestMatchForStyle = math.max(
            bestMatchForStyle,
            entry.value * 0.65,
          );
        }
      }

      rawScore += bestMatchForStyle;
    }

    /*
     * Each style contributes up to about 3 raw points.
     * With 3 selected styles, raw score is around 0–9.
     * Scale that to 0–55.
     */
    final maximumRaw =
        preferences.travelStyles.length * 3.0;

    if (maximumRaw <= 0) {
      return 0;
    }

    return ((rawScore / maximumRaw) * 55)
        .clamp(0, 55)
        .toDouble();
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

    if (attraction.isOpen24Hours ||
        attraction.openingHours.isNotEmpty ||
        (attraction.openingTime.trim().isNotEmpty &&
            attraction.closingTime.trim().isNotEmpty)) {
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

  Future<void> _buildLogicalSchedule(
      List<_ScoredAttraction> recommendationPool,
      ) async {
    _generatedSchedule = [];
    _routeCache.clear();

    final remaining =
    List<_ScoredAttraction>.from(
      recommendationPool,
    );

    final totalDays =
    preferences.totalDays <= 0
        ? 1
        : preferences.totalDays;

    double usedBudget = 0;

    for (int dayIndex = 0;
    dayIndex < totalDays;
    dayIndex++) {
      if (remaining.isEmpty) {
        break;
      }

      final dayStart =
      _dateForDay(
        dayIndex,
        9,
        0,
      );

      final dayEnd =
      _dateForDay(
        dayIndex,
        18,
        0,
      );

      /*
       * GLOBAL DAILY OPTIMIZATION
       * -------------------------
       * Take the strongest recommendation candidates for this day,
       * ask HERE Matrix for every A->B travel time/distance in one call,
       * then evaluate complete permutations locally.
       *
       * With max 8 candidates and max 5 places/day:
       * 8P5 = 6,720 possible 5-stop orders, which is still practical.
       */
      final dailyCandidates =
      _dailyCandidateShortlist(
        remaining: remaining,
        dayIndex: dayIndex,
        usedBudget: usedBudget,
      );

      if (dailyCandidates.isEmpty) {
        continue;
      }

      HereMatrixResult? matrix;

      final allHaveCoordinates =
      dailyCandidates.every(
            (candidate) =>
            _hasCoordinates(
              candidate.attraction,
            ),
      );

      if (allHaveCoordinates &&
          dailyCandidates.length >= 2) {
        try {
          matrix =
          await _hereMatrixRoutingService
              .calculateCarMatrix(
            points: dailyCandidates
                .map(
                  (candidate) =>
                  HereMatrixPoint(
                    latitude:
                    candidate
                        .attraction
                        .latitude,
                    longitude:
                    candidate
                        .attraction
                        .longitude,
                  ),
            )
                .toList(),
            departureTime:
            dayStart,
          );
        } catch (e) {
          debugPrint(
            'HERE Matrix unavailable for '
                'day ${dayIndex + 1}: $e',
          );
        }
      }

      final optimized =
      _findBestDailySequence(
        candidates: dailyCandidates,
        matrix: matrix,
        dayIndex: dayIndex,
        dayStart: dayStart,
        dayEnd: dayEnd,
        usedBudgetBeforeDay:
        usedBudget,
      );

      if (optimized == null ||
          optimized.candidateIndexes.isEmpty) {
        continue;
      }

      /*
       * Matrix chooses the global order.
       * Routing API then refines each chosen leg using the actual
       * departure time generated by the previous visit.
       */
      DateTime currentTime =
          dayStart;

      AttractionModel? previousAttraction;
      bool lunchAdded = false;

      final scheduledIds =
      <String>{};

      for (final candidateIndex
      in optimized.candidateIndexes) {
        final selected =
        dailyCandidates[candidateIndex];

        final attraction =
            selected.attraction;

        final fee =
        estimateAttractionFee(
          attraction,
        );

        if (preferences.budget > 0 &&
            usedBudget + fee >
                preferences.budget) {
          continue;
        }

        HereRouteInfo? routeInfo;
        bool usedHereRouting = false;

        if (previousAttraction != null) {
          final routeResult =
          await _routeBetween(
            from:
            previousAttraction,
            to:
            attraction,
            departureTime:
            currentTime,
          );

          routeInfo =
              routeResult.routeInfo;

          usedHereRouting =
              routeResult.usedHereRouting;

          currentTime =
              currentTime.add(
                Duration(
                  minutes:
                  routeInfo.durationMinutes,
                ),
              );
        }

        if (!lunchAdded &&
            currentTime.hour >= 12 &&
            currentTime.hour < 14) {
          currentTime =
              currentTime.add(
                const Duration(hours: 1),
              );

          lunchAdded = true;
        }

        final visitMinutes =
        _recommendedVisitMinutes(
          attraction,
        );

        final visitWindow =
        _fitVisitIntoOpeningHours(
          attraction:
          attraction,
          dayIndex:
          dayIndex,
          earliestArrival:
          currentTime,
          visitMinutes:
          visitMinutes,
          dayEnd:
          dayEnd,
        );

        if (visitWindow == null) {
          // Do not force an attraction into a closed period.
          continue;
        }

        _generatedSchedule.add(
          TripScheduleItem(
            attraction:
            attraction,
            dayIndex:
            dayIndex,
            startTime:
            visitWindow.start,
            endTime:
            visitWindow.end,
            visitMinutes:
            visitMinutes,
            transportMinutesBefore:
            routeInfo
                ?.durationMinutes ??
                0,
            distanceFromPreviousKm:
            routeInfo?.distanceKm ??
                0,
            usedHereRouting:
            previousAttraction ==
                null
                ? false
                : usedHereRouting,
            estimatedFee:
            fee,
            recommendationScore:
            selected.score,
          ),
        );

        usedBudget += fee;
        scheduledIds.add(
          attraction.id,
        );

        previousAttraction =
            attraction;

        currentTime =
            visitWindow.end.add(
              Duration(
                minutes:
                _bufferMinutes(),
              ),
            );
      }

      remaining.removeWhere(
            (candidate) =>
            scheduledIds.contains(
              candidate.attraction.id,
            ),
      );
    }
  }

  List<_ScoredAttraction>
  _dailyCandidateShortlist({
    required List<_ScoredAttraction> remaining,
    required int dayIndex,
    required double usedBudget,
  }) {
    final dayEnd =
    _dateForDay(
      dayIndex,
      18,
      0,
    );

    final dayStart =
    _dateForDay(
      dayIndex,
      9,
      0,
    );

    final filtered =
    remaining.where(
          (candidate) {
        final attraction =
            candidate.attraction;

        final fee =
        estimateAttractionFee(
          attraction,
        );

        if (preferences.budget > 0 &&
            usedBudget + fee >
                preferences.budget) {
          return false;
        }

        // Reject places that cannot fit at all during the selected day.
        return _fitVisitIntoOpeningHours(
          attraction:
          attraction,
          dayIndex:
          dayIndex,
          earliestArrival:
          dayStart,
          visitMinutes:
          _recommendedVisitMinutes(
            attraction,
          ),
          dayEnd:
          dayEnd,
        ) !=
            null;
      },
    ).toList()
      ..sort(
            (a, b) =>
            b.score.compareTo(
              a.score,
            ),
      );

    return filtered
        .take(
      math.min(
        filtered.length,
        8,
      ),
    )
        .toList();
  }

  _OptimizedDaySequence?
  _findBestDailySequence({
    required List<_ScoredAttraction> candidates,
    required HereMatrixResult? matrix,
    required int dayIndex,
    required DateTime dayStart,
    required DateTime dayEnd,
    required double usedBudgetBeforeDay,
  }) {
    if (candidates.isEmpty) {
      return null;
    }

    final maxStops =
    math.min(
      _maximumPlacesPerDay(),
      candidates.length,
    );

    _OptimizedDaySequence? best;

    final used =
    List<bool>.filled(
      candidates.length,
      false,
    );

    void search(
        List<int> sequence,
        DateTime currentTime,
        double usedBudget,
        double recommendationTotal,
        int totalTravelMinutes,
        int totalWaitingMinutes,
        bool lunchAdded,
        ) {
      if (sequence.isNotEmpty) {
        /*
         * Objective:
         * - reward recommendation relevance strongly
         * - reward fitting more useful stops
         * - penalize total road time
         * - slightly penalize waiting for opening time
         *
         * Every complete order is evaluated, so route order is not greedy.
         */
        final objective =
            recommendationTotal +
                (sequence.length * 12) -
                (totalTravelMinutes * 0.22) -
                (totalWaitingMinutes * 0.06);

        if (best == null ||
            objective >
                best!.objective) {
          best =
              _OptimizedDaySequence(
                candidateIndexes:
                List<int>.from(
                  sequence,
                ),
                objective:
                objective,
              );
        }
      }

      if (sequence.length >=
          maxStops) {
        return;
      }

      for (int nextIndex = 0;
      nextIndex <
          candidates.length;
      nextIndex++) {
        if (used[nextIndex]) {
          continue;
        }

        final candidate =
        candidates[nextIndex];

        final attraction =
            candidate.attraction;

        final fee =
        estimateAttractionFee(
          attraction,
        );

        if (preferences.budget > 0 &&
            usedBudget + fee >
                preferences.budget) {
          continue;
        }

        int travelMinutes = 0;

        if (sequence.isNotEmpty) {
          final previousIndex =
              sequence.last;

          if (matrix != null) {
            final matrixMinutes =
            matrix.durationMinutes(
              previousIndex,
              nextIndex,
            );

            if (matrixMinutes ==
                null) {
              continue;
            }

            travelMinutes =
                matrixMinutes;
          } else {
            // If Matrix is temporarily unavailable, keep the optimizer
            // working with the existing local fallback estimate.
            final previous =
                candidates[
                previousIndex]
                    .attraction;

            travelMinutes =
                _fallbackRoute(
                  from:
                  previous,
                  to:
                  attraction,
                  departureTime:
                  currentTime,
                )
                    .routeInfo
                    .durationMinutes;
          }
        }

        DateTime arrival =
        currentTime.add(
          Duration(
            minutes:
            travelMinutes,
          ),
        );

        bool nextLunchAdded =
            lunchAdded;

        if (!nextLunchAdded &&
            arrival.hour >= 12 &&
            arrival.hour < 14) {
          arrival =
              arrival.add(
                const Duration(
                  hours: 1,
                ),
              );

          nextLunchAdded = true;
        }

        final visitMinutes =
        _recommendedVisitMinutes(
          attraction,
        );

        final visitWindow =
        _fitVisitIntoOpeningHours(
          attraction:
          attraction,
          dayIndex:
          dayIndex,
          earliestArrival:
          arrival,
          visitMinutes:
          visitMinutes,
          dayEnd:
          dayEnd,
        );

        if (visitWindow == null) {
          continue;
        }

        final waitingMinutes =
            visitWindow.start
                .difference(
              arrival,
            )
                .inMinutes;

        used[nextIndex] = true;
        sequence.add(
          nextIndex,
        );

        search(
          sequence,
          visitWindow.end.add(
            Duration(
              minutes:
              _bufferMinutes(),
            ),
          ),
          usedBudget + fee,
          recommendationTotal +
              candidate.score,
          totalTravelMinutes +
              travelMinutes,
          totalWaitingMinutes +
              math.max(
                0,
                waitingMinutes,
              ),
          nextLunchAdded,
        );

        sequence.removeLast();
        used[nextIndex] = false;
      }
    }

    search(
      <int>[],
      dayStart,
      usedBudgetBeforeDay,
      0,
      0,
      0,
      false,
    );

    return best;
  }

  Future<_RouteLookupResult> _routeBetween({
    required AttractionModel from,
    required AttractionModel to,
    required DateTime departureTime,
  }) async {
    if (!_hasCoordinates(from) ||
        !_hasCoordinates(to)) {
      return _fallbackRoute(
        from: from,
        to: to,
        departureTime: departureTime,
      );
    }

    final cacheKey =
        '${from.id}|${to.id}|'
        '${departureTime.year}'
        '${departureTime.month}'
        '${departureTime.day}|'
        '${departureTime.hour}:'
        '${departureTime.minute ~/ 30}';

    final cached =
    _routeCache[cacheKey];

    if (cached != null) {
      return _RouteLookupResult(
        routeInfo: cached,
        usedHereRouting: true,
      );
    }

    try {
      final route =
      await _hereRoutingService.getCarRoute(
        originLatitude:
        from.latitude,
        originLongitude:
        from.longitude,
        destinationLatitude:
        to.latitude,
        destinationLongitude:
        to.longitude,
        departureTime:
        departureTime,
      );

      _routeCache[cacheKey] =
          route;

      return _RouteLookupResult(
        routeInfo: route,
        usedHereRouting: true,
      );
    } catch (e) {
      debugPrint(
        'HERE route fallback '
            '${from.name} -> ${to.name}: $e',
      );

      return _fallbackRoute(
        from: from,
        to: to,
        departureTime: departureTime,
      );
    }
  }

  _RouteLookupResult _fallbackRoute({
    required AttractionModel from,
    required AttractionModel to,
    required DateTime departureTime,
  }) {
    final distanceKm =
    _straightLineDistanceKm(
      from,
      to,
    );

    int durationMinutes;

    if (distanceKm <= 0) {
      durationMinutes =
      from.area.trim().toLowerCase() ==
          to.area.trim().toLowerCase()
          ? 15
          : 30;
    } else if (distanceKm <= 1) {
      durationMinutes = 8;
    } else if (distanceKm <= 3) {
      durationMinutes = 12;
    } else if (distanceKm <= 5) {
      durationMinutes = 18;
    } else if (distanceKm <= 10) {
      durationMinutes = 25;
    } else if (distanceKm <= 20) {
      durationMinutes = 40;
    } else if (distanceKm <= 35) {
      durationMinutes = 55;
    } else {
      durationMinutes =
          math.min(
            90,
            (distanceKm * 2).ceil(),
          );
    }

    return _RouteLookupResult(
      routeInfo:
      HereRouteInfo.fallback(
        distanceKm:
        distanceKm,
        durationMinutes:
        durationMinutes,
        departureTime:
        departureTime,
      ),
      usedHereRouting: false,
    );
  }

  bool _hasCoordinates(
      AttractionModel attraction,
      ) {
    return attraction.latitude != 0 &&
        attraction.longitude != 0;
  }

  double _straightLineDistanceKm(
      AttractionModel from,
      AttractionModel to,
      ) {
    if (!_hasCoordinates(from) ||
        !_hasCoordinates(to)) {
      return 0;
    }

    return _distanceInKm(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  _VisitWindow? _fitVisitIntoOpeningHours({
    required AttractionModel attraction,
    required int dayIndex,
    required DateTime earliestArrival,
    required int visitMinutes,
    required DateTime dayEnd,
  }) {
    final periods =
    _openingPeriodsForDay(
      attraction,
      dayIndex,
    );

    if (periods.isEmpty) {
      return null;
    }

    for (final period in periods) {
      DateTime start =
          earliestArrival;

      if (start.isBefore(period.start)) {
        start = period.start;
      }

      final end = start.add(
        Duration(minutes: visitMinutes),
      );

      if (!end.isAfter(period.end) &&
          !end.isAfter(dayEnd)) {
        return _VisitWindow(
          start: start,
          end: end,
        );
      }
    }

    return null;
  }

  List<_OpeningPeriod> _openingPeriodsForDay(
      AttractionModel attraction,
      int dayIndex,
      ) {
    final date =
    _dateForDay(dayIndex, 0, 0);

    if (attraction.isOpen24Hours) {
      return [
        _OpeningPeriod(
          start: DateTime(
            date.year,
            date.month,
            date.day,
            0,
            0,
          ),
          end: DateTime(
            date.year,
            date.month,
            date.day,
            23,
            59,
          ),
        ),
      ];
    }

    final weekdayName =
    _weekdayName(date.weekday);

    if (attraction.openingHours.isNotEmpty) {
      List<String>? rawPeriods;

      for (final entry
      in attraction.openingHours.entries) {
        if (entry.key
            .trim()
            .toLowerCase() ==
            weekdayName) {
          rawPeriods =
              entry.value;
          break;
        }
      }

      if (rawPeriods == null ||
          rawPeriods.isEmpty) {
        return [];
      }

      final parsed =
      <_OpeningPeriod>[];

      for (final raw in rawPeriods) {
        final period =
        _parseOpeningPeriod(
          raw,
          date,
        );

        if (period != null) {
          parsed.add(period);
        }
      }

      parsed.sort(
            (a, b) =>
            a.start.compareTo(
              b.start,
            ),
      );

      return parsed;
    }

    final openingMinutes =
    _parseTime(
      attraction.openingTime,
      -1,
    );

    final closingMinutes =
    _parseTime(
      attraction.closingTime,
      -1,
    );

    if (openingMinutes < 0 ||
        closingMinutes < 0) {
      return [];
    }

    return [
      _OpeningPeriod(
        start: DateTime(
          date.year,
          date.month,
          date.day,
          openingMinutes ~/ 60,
          openingMinutes % 60,
        ),
        end: DateTime(
          date.year,
          date.month,
          date.day,
          closingMinutes ~/ 60,
          closingMinutes % 60,
        ),
      ),
    ];
  }

  _OpeningPeriod? _parseOpeningPeriod(
      String raw,
      DateTime date,
      ) {
    final value =
    raw.trim();

    if (value.isEmpty ||
        value.toLowerCase() == 'closed') {
      return null;
    }

    final parts =
    value.split(
      RegExp(r'\s*[-–—]\s*'),
    );

    if (parts.length < 2) {
      return null;
    }

    final startMinutes =
    _parseTime(
      parts[0],
      -1,
    );

    final endMinutes =
    _parseTime(
      parts[1],
      -1,
    );

    if (startMinutes < 0 ||
        endMinutes < 0 ||
        endMinutes <=
            startMinutes) {
      return null;
    }

    return _OpeningPeriod(
      start: DateTime(
        date.year,
        date.month,
        date.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      ),
      end: DateTime(
        date.year,
        date.month,
        date.day,
        endMinutes ~/ 60,
        endMinutes % 60,
      ),
    );
  }

  String _weekdayName(
      int weekday,
      ) {
    const values =
    <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    return values[
    weekday - 1];
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

  bool get isOverBudget =>
      preferences.budget > 0 &&
          estimatedTotalAttractionCost >
              preferences.budget;

  double get remainingBudget =>
      preferences.budget -
          estimatedTotalAttractionCost;

  double get budgetDifference =>
      (estimatedTotalAttractionCost -
          preferences.budget)
          .abs();


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
    final value =
    attraction.recommendedDuration
        .trim()
        .toLowerCase();

    if (value.isEmpty) {
      return 90;
    }

    final matches = RegExp(
      r'[0-9]+(?:\.[0-9]+)?',
    ).allMatches(value).toList();

    if (matches.isEmpty) {
      return 90;
    }

    final numbers = matches
        .map(
          (match) => double.tryParse(
        match.group(0) ?? '',
      ),
    )
        .whereType<double>()
        .toList();

    if (numbers.isEmpty) {
      return 90;
    }

    // For values such as "2-3 hours", use the midpoint (2.5 hours)
    // as a sensible scheduling reference.
    final reference =
    numbers.length >= 2
        ? (numbers[0] + numbers[1]) / 2
        : numbers[0];

    if (value.contains('hour') ||
        value.contains('hr')) {
      return (reference * 60)
          .round()
          .clamp(30, 360);
    }

    return reference
        .round()
        .clamp(30, 360);
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
    final styles = preferences.travelStyles
        .map((style) => style.toLowerCase())
        .toList();

    // Relaxed trips should remain slower even when another style is selected.
    if (styles.any((style) => style.contains('relax'))) {
      return 3;
    }

    if (styles.any((style) => style.contains('adventure'))) {
      return 5;
    }

    return 4;
  }

  int _bufferMinutes() {
    final styles = preferences.travelStyles
        .map((style) => style.toLowerCase())
        .toList();

    if (styles.any((style) => style.contains('relax'))) {
      return 20;
    }

    if (styles.any((style) => style.contains('adventure'))) {
      return 8;
    }

    return 12;
  }

  @override
  void dispose() {
    _hereRoutingService.dispose();
    _hereMatrixRoutingService.dispose();
    super.dispose();
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

class _OptimizedDaySequence {
  final List<int> candidateIndexes;
  final double objective;

  const _OptimizedDaySequence({
    required this.candidateIndexes,
    required this.objective,
  });
}

class _CandidateSelection {
  final int index;
  final double combinedScore;
  final HereRouteInfo? routeInfo;
  final bool usedHereRouting;

  const _CandidateSelection({
    required this.index,
    required this.combinedScore,
    this.routeInfo,
    required this.usedHereRouting,
  });
}

class _RouteLookupResult {
  final HereRouteInfo routeInfo;
  final bool usedHereRouting;

  const _RouteLookupResult({
    required this.routeInfo,
    required this.usedHereRouting,
  });
}

class _OpeningPeriod {
  final DateTime start;
  final DateTime end;

  const _OpeningPeriod({
    required this.start,
    required this.end,
  });
}

class _VisitWindow {
  final DateTime start;
  final DateTime end;

  const _VisitWindow({
    required this.start,
    required this.end,
  });
}
