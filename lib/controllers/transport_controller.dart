import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/transport_data.dart';
import '../models/delay_estimate.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../models/saved_trip_plan.dart';
import '../models/transport_mode.dart';
import '../services/location_service.dart';
import '../services/planned_trip_transport_store.dart';
import '../services/route_recommender_service.dart';
import '../services/saved_trips_storage_service.dart';
import '../services/transit_hop_finder.dart';
import '../services/transport_service.dart';
import '../services/travel_preferences_service.dart';
import '../services/weather_service.dart';

class TransportController {
  TransportController({
    LocationService? locationService,
    SavedTripsStore? savedTripsStore,
    WeatherService? weatherService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PlannedTripTransportStore? plannedTransportStore,
    TravelPreferencesService? travelPreferencesService,
  }) : _locationService = locationService ?? const LocationService(),
       _savedTripsStore = savedTripsStore ?? SavedTripsStore.instance,
       _weatherService = weatherService ?? const WeatherService(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _travelPreferencesService =
           travelPreferencesService ?? TravelPreferencesService.instance,
       _plannedTransportStore =
           plannedTransportStore ?? PlannedTripTransportStore.instance;

  final LocationService _locationService;
  final SavedTripsStore _savedTripsStore;
  final WeatherService _weatherService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final TravelPreferencesService _travelPreferencesService;
  final PlannedTripTransportStore _plannedTransportStore;

  /// Detects the user's current position (asks for permission if needed)
  /// and reverse-geocodes it into a named [LocationPoint].
  Future<LocationLookupResult> detectCurrentLocation() {
    return _locationService.detectCurrentLocation();
  }

  static const _maxDisplayedOptions = 8;

  Future<RouteSearchResult> searchRides({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    final result = await TransportService.instance.search(
      from: from,
      to: to,
      departAt: departAt,
    );

    var options = result.options;
    var isRaining = false;
    var isHazy = false;
    var isExtremeHeat = false;
    try {
      final weather = await _weatherService.checkConditions(from);
      isRaining = weather.known && weather.isRaining;
      isHazy = weather.known && weather.isHazy;
      isExtremeHeat = weather.known && weather.isExtremeHeat;
      if (isRaining) {
        options = _flagRainyBikeOptions(options);
      }
      if (isHazy) {
        options = _flagOutdoorExposureOptions(options, kHazeOutdoorTag);
      }
      if (isExtremeHeat) {
        options = _flagOutdoorExposureOptions(options, kExtremeHeatTag);
      }
    } catch (error) {
      debugPrint('[TransportController] weather check failed: $error');
    }
    options = _withDelayEstimates(options, isRaining: isRaining);

    var preferences = const TravelPreferences();
    var weights = const PreferenceWeights();
    try {
      preferences = await _travelPreferencesService.load();
      weights = await _travelPreferencesService.weightsFor(preferences);
      final budgetCapRm = preferences.budgetCapRm;
      if (budgetCapRm != null) {
        options = _flagOverBudgetOptions(options, budgetCapRm);
      }
      final maxDurationMinutes = preferences.maxDurationMinutes;
      if (maxDurationMinutes != null) {
        options = _flagOverDurationOptions(options, maxDurationMinutes);
      }
    } catch (error) {
      debugPrint('[TransportController] preferences load failed: $error');
    }

    final scored = RouteRecommender.score(
      options,
      durationWeight: weights.durationWeight,
      costWeight: weights.costWeight,
      co2Weight: weights.co2Weight,
      transfersWeight: weights.transfersWeight,
    );
    const softDeprioritizePenalty = 1000.0;
    final adjusted = [
      for (final entry in scored)
        MapEntry(
          entry.key,
          entry.value -
              (_hasSoftDeprioritizeReason(entry.key)
                  ? softDeprioritizePenalty
                  : 0.0),
        ),
    ];
    final reordered = List<MapEntry<RideOption, double>>.of(adjusted)
      ..sort((a, b) => b.value.compareTo(a.value));
    var topRankedScored = reordered.take(_maxDisplayedOptions).toList();
    topRankedScored = _ensureImportantOptionsSurvive(
      topRankedScored,
      reordered,
    );
    var topRanked = [for (final entry in topRankedScored) entry.key];
    if (isHazy || isExtremeHeat) {
      topRanked = _withShelteredPick(topRanked);
    }
    final badged = _withRecommendedBadge(topRanked);
    return RouteSearchResult(options: badged, isLive: result.isLive);
  }

  List<MapEntry<RideOption, double>> _ensureImportantOptionsSurvive(
    List<MapEntry<RideOption, double>> topRanked,
    List<MapEntry<RideOption, double>> reordered,
  ) {
    final result = List<MapEntry<RideOption, double>>.of(topRanked);
    final protectedIds = <String>{};

    void ensure(bool Function(RideOption) matches) {
      if (result.length < _maxDisplayedOptions) return;
      final alreadyIn = result.indexWhere((entry) => matches(entry.key));
      if (alreadyIn != -1) {
        protectedIds.add(result[alreadyIn].key.id);
        return;
      }
      final sourceIndex = reordered.indexWhere((entry) => matches(entry.key));
      if (sourceIndex == -1) return;
      for (var i = result.length - 1; i >= 0; i--) {
        if (protectedIds.contains(result[i].key.id)) continue;
        result[i] = reordered[sourceIndex];
        protectedIds.add(reordered[sourceIndex].key.id);
        result.sort((a, b) => b.value.compareTo(a.value));
        return;
      }
    }

    ensure(_hasSoftDeprioritizeReason);
    ensure(_hasBikeLeg);
    return result;
  }

  bool _hasBikeLeg(RideOption option) =>
      option.legs.any((leg) => leg.mode == TransportMode.bike);

  bool _hasSoftDeprioritizeReason(RideOption option) =>
      option.tags.contains(kRainBikeTag) ||
      option.tags.contains(kHazeOutdoorTag) ||
      option.tags.contains(kExtremeHeatTag) ||
      option.tags.contains(kOverBudgetTag) ||
      option.tags.contains(kOverDurationTag);

  static const _significantOutdoorWalkMinutes = 10;

  bool _hasSignificantOutdoorExposure(RideOption option) {
    final hasBike = option.legs.any(
      (leg) => leg.mode == TransportMode.bike,
    );
    if (hasBike) return true;
    final walkMinutes = option.legs
        .where((leg) => leg.mode == TransportMode.walk)
        .fold<int>(0, (sum, leg) => sum + leg.duration.inMinutes);
    return walkMinutes >= _significantOutdoorWalkMinutes;
  }

  List<RideOption> _flagOutdoorExposureOptions(
    List<RideOption> options,
    String tag,
  ) {
    return [
      for (final option in options)
        if (option.tags.contains(tag) ||
            !_hasSignificantOutdoorExposure(option))
          option
        else
          RideOption(
            id: option.id,
            title: option.title,
            legs: option.legs,
            estCostRm: option.estCostRm,
            co2Kg: option.co2Kg,
            tags: [tag, ...option.tags],
            isLiveData: option.isLiveData,
            path: option.path,
            searchDepartAt: option.searchDepartAt,
            delayEstimate: option.delayEstimate,
          ),
    ];
  }

  List<RideOption> _flagOverBudgetOptions(
    List<RideOption> options,
    double budgetCapRm,
  ) {
    return [
      for (final option in options)
        if (option.tags.contains(kOverBudgetTag) ||
            option.estCostRm <= budgetCapRm)
          option
        else
          RideOption(
            id: option.id,
            title: option.title,
            legs: option.legs,
            estCostRm: option.estCostRm,
            co2Kg: option.co2Kg,
            tags: [kOverBudgetTag, ...option.tags],
            isLiveData: option.isLiveData,
            path: option.path,
            searchDepartAt: option.searchDepartAt,
            delayEstimate: option.delayEstimate,
          ),
    ];
  }

  List<RideOption> _flagOverDurationOptions(
    List<RideOption> options,
    int maxDurationMinutes,
  ) {
    return [
      for (final option in options)
        if (option.tags.contains(kOverDurationTag) ||
            option.totalElapsedFromSearch.inMinutes <= maxDurationMinutes)
          option
        else
          RideOption(
            id: option.id,
            title: option.title,
            legs: option.legs,
            estCostRm: option.estCostRm,
            co2Kg: option.co2Kg,
            tags: [kOverDurationTag, ...option.tags],
            isLiveData: option.isLiveData,
            path: option.path,
            searchDepartAt: option.searchDepartAt,
            delayEstimate: option.delayEstimate,
          ),
    ];
  }

  List<RideOption> _withShelteredPick(List<RideOption> ranked) {
    final index = ranked.indexWhere(
      (option) => !_hasSignificantOutdoorExposure(option),
    );
    if (index == -1) return ranked;
    final pick = ranked[index];
    if (pick.tags.contains(kShelteredPickTag)) return ranked;
    final tagged = RideOption(
      id: pick.id,
      title: pick.title,
      legs: pick.legs,
      estCostRm: pick.estCostRm,
      co2Kg: pick.co2Kg,
      tags: [kShelteredPickTag, ...pick.tags],
      isLiveData: pick.isLiveData,
      path: pick.path,
      searchDepartAt: pick.searchDepartAt,
      delayEstimate: pick.delayEstimate,
    );
    return [
      for (var i = 0; i < ranked.length; i++)
        if (i == index) tagged else ranked[i],
    ];
  }

  List<RideOption> _flagRainyBikeOptions(List<RideOption> options) {
    return [
      for (final option in options)
        if (option.tags.contains(kRainBikeTag) ||
            !option.legs.any((leg) => leg.mode == TransportMode.bike))
          option
        else
          RideOption(
            id: option.id,
            title: option.title,
            legs: option.legs,
            estCostRm: option.estCostRm,
            co2Kg: option.co2Kg,
            tags: [kRainBikeTag, ...option.tags],
            isLiveData: option.isLiveData,
            path: option.path,
            searchDepartAt: option.searchDepartAt,
            delayEstimate: option.delayEstimate,
          ),
    ];
  }

  List<RideOption> _withDelayEstimates(
    List<RideOption> options, {
    required bool isRaining,
  }) {
    final result = <RideOption>[];
    for (final option in options) {
      final estimate = DelayEstimate.evaluate(
        option.legs,
        isRaining: isRaining,
      );
      if (estimate == null) {
        result.add(option);
        continue;
      }
      result.add(
        RideOption(
          id: option.id,
          title: option.title,
          legs: option.legs,
          estCostRm: option.estCostRm,
          co2Kg: option.co2Kg,
          tags: option.tags,
          isLiveData: option.isLiveData,
          path: option.path,
          searchDepartAt: option.searchDepartAt,
          delayEstimate: estimate,
        ),
      );
    }
    return result;
  }

  List<RideOption> _withRecommendedBadge(List<RideOption> ranked) {
    if (ranked.isEmpty) return ranked;
    final top = ranked.first;
    final badged = RideOption(
      id: top.id,
      title: top.title,
      legs: top.legs,
      estCostRm: top.estCostRm,
      co2Kg: top.co2Kg,
      tags: ['AI Recommended', ...top.tags],
      isLiveData: top.isLiveData,
      path: top.path,
      searchDepartAt: top.searchDepartAt,
      delayEstimate: top.delayEstimate,
    );
    return [badged, ...ranked.skip(1)];
  }

  static TodaysTransportStatus? _todaysStatusCache;
  static DateTime? _todaysStatusCachedAt;
  static LocationPoint? _todaysStatusCachedFrom;

  static const _todaysStatusCacheTtl = Duration(minutes: 5);

  static const _todaysStatusCacheMoveKm = 5.0;

  Future<TodaysTransportStatus?> todaysTransportStatus(
    LocationPoint from,
  ) async {
    final cachedAt = _todaysStatusCachedAt;
    final cachedFrom = _todaysStatusCachedFrom;
    if (cachedAt != null &&
        cachedFrom != null &&
        DateTime.now().difference(cachedAt) < _todaysStatusCacheTtl &&
        from.distanceKm(cachedFrom) <= _todaysStatusCacheMoveKm) {
      return _todaysStatusCache;
    }
    final status = await _computeTodaysTransportStatus(from);
    _todaysStatusCache = status;
    _todaysStatusCachedAt = DateTime.now();
    _todaysStatusCachedFrom = from;
    return status;
  }

  Future<TodaysTransportStatus?> _computeTodaysTransportStatus(
    LocationPoint from,
  ) async {
    _TodaysPick? pick;
    try {
      pick = await _nextDestinationFromSavedPlan();
    } catch (error) {
      debugPrint('[TransportController] saved-plan lookup failed: $error');
    }
    if (pick == null) return null;

    List<PlannedPlanLeg>? savedLegs;
    try {
      savedLegs = await getSavedTransportPlan(pick.planId);
    } catch (error) {
      debugPrint(
        '[TransportController] saved-transport-plan lookup failed: $error',
      );
    }

    if (savedLegs != null && savedLegs.isNotEmpty) {
      final todaysLeg = savedLegs.firstWhere(
        (leg) => leg.day == pick!.dayIndex,
        orElse: () => savedLegs!.first,
      );
      return TodaysTransportStatus.alreadyPlanned(todaysLeg);
    }

    try {
      final result = await searchRides(
        from: from,
        to: pick.point,
        departAt: DateTime.now(),
      );
      if (result.options.isEmpty) return null;
      final option = _withTag(result.options.first, 'From Your Trip Plan');
      return TodaysTransportStatus.suggestion(
        RecommendedRide(to: pick.point, option: option),
      );
    } catch (error) {
      debugPrint(
        '[TransportController] todaysTransportStatus search failed: $error',
      );
      return null;
    }
  }

  Future<_TodaysPick?> _nextDestinationFromSavedPlan() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('saved_trip_plans')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'saved')
        .get();
    if (snapshot.docs.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final startTimestamp = data['startDate'];
      final endTimestamp = data['endDate'];
      if (startTimestamp is! Timestamp || endTimestamp is! Timestamp) {
        continue;
      }

      final start = startTimestamp.toDate();
      final end = endTimestamp.toDate();
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      if (today.isBefore(startDate) || today.isAfter(endDate)) continue;

      final attractions = data['attractions'];
      if (attractions is! List || attractions.isEmpty) continue;

      final todayDayIndex = today.difference(startDate).inDays + 1;
      Map<String, dynamic>? pick;
      for (final raw in attractions) {
        if (raw is! Map) continue;
        final attraction = Map<String, dynamic>.from(raw);
        if (attraction['day'] == todayDayIndex) {
          pick = attraction;
          break;
        }
      }
      pick ??= Map<String, dynamic>.from(attractions.first as Map);

      final point = await _geocodeSavedPlanAttraction(pick);
      if (point != null) {
        return _TodaysPick(planId: doc.id, dayIndex: todayDayIndex, point: point);
      }
    }
    return null;
  }

  Future<LocationPoint?> _geocodeSavedPlanAttraction(
    Map<String, dynamic> attraction,
  ) async {
    final name = (attraction['name'] as String?)?.trim() ?? '';
    final address = (attraction['address'] as String?)?.trim() ?? '';
    final area = (attraction['area'] as String?)?.trim() ?? '';

    final candidates = <String>[
      if (name.isNotEmpty && address.isNotEmpty) '$name, $address',
      if (address.isNotEmpty) address,
      if (name.isNotEmpty && area.isNotEmpty) '$name, $area',
      if (name.isNotEmpty) name,
      if (area.isNotEmpty) area,
    ];

    final tried = <String>{};
    for (final query in candidates) {
      if (!tried.add(query)) continue; // an exact repeat - skip it
      try {
        final point = await _locationService.searchPlace(query);
        if (point != null) return point;
      } catch (error) {
        debugPrint(
          '[TransportController] geocode attempt failed for "$query": '
          '$error',
        );
      }
    }
    return null;
  }

  Future<TravelPreferences> loadTravelPreferences() =>
      _travelPreferencesService.load();

  /// Saves [preferences] for future searchRides calls to pick up - see
  /// TravelPreferencesSheet's Save button. Also clears the cached
  /// "today's recommendation" (see _todaysStatusCache /
  /// todaysTransportStatus) - without this, RecommendedPanel could keep
  /// showing a suggestion computed under the OLD preferences for up to
  /// _todaysStatusCacheTtl, ignoring the filter the person just applied.
  Future<void> saveTravelPreferences(TravelPreferences preferences) async {
    await _travelPreferencesService.save(preferences);
    _todaysStatusCache = null;
    _todaysStatusCachedAt = null;
    _todaysStatusCachedFrom = null;
  }

  Future<void> recordOptionSelection(
    RideOption selected,
    List<RideOption> searchResults,
  ) => _travelPreferencesService.recordSelection(selected, searchResults);

  Future<List<SavedTripPlan>> getActiveSavedPlans() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to see your trip plans.');
    }

    final snapshot = await _firestore
        .collection('saved_trip_plans')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'saved')
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final plans = snapshot.docs
        .map((doc) => SavedTripPlan.fromFirestore(doc.id, doc.data()))
        .where((plan) {
          final end = DateTime(
            plan.endDate.year,
            plan.endDate.month,
            plan.endDate.day,
          );
          return !today.isAfter(end);
        })
        .toList();
    plans.sort((a, b) => a.startDate.compareTo(b.startDate));
    return plans;
  }

  Future<List<PlannedPlanLeg>> planTransportationForPlan(
    SavedTripPlan plan, {
    required LocationPoint startingFrom,
  }) async {
    final legs = <PlannedPlanLeg>[];
    final totalDays = plan.totalDays <= 0 ? 1 : plan.totalDays;
    final bufferMinutes = _bufferMinutesForStyle(plan.travelStyle);

    for (var day = 1; day <= totalDays; day++) {
      final dayAttractions = plan.attractionsForDay(day);
      if (dayAttractions.isEmpty) continue;

      final dayDate = DateTime.utc(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day + (day - 1),
      );

      var from = startingFrom;
      var freeFrom = DateTime.utc(dayDate.year, dayDate.month, dayDate.day, 9);
      final nowWallClock = instantToMalaysiaWallClock(DateTime.now());
      if (freeFrom.isBefore(nowWallClock)) {
        freeFrom = nowWallClock;
      }

      for (final attraction in dayAttractions) {
        LocationPoint? to;
        try {
          to = await _geocodeSavedPlanAttraction({
            'name': attraction.name,
            'address': attraction.address,
            'area': attraction.area,
          });
        } catch (error) {
          debugPrint(
            '[TransportController] geocoding failed for '
            '${attraction.name}: $error',
          );
        }

        var deadline = to != null
            ? freeFrom.add(
                Duration(minutes: _estimateTravelMinutes(from, to)),
              )
            : freeFrom;
        final openingAt = attraction.openingDateTime(dayDate);
        if (deadline.isBefore(openingAt)) deadline = openingAt;

        RideOption? option;
        String? warning;
        if (to != null) {
          final probe = await _planLegToMeetDeadline(
            from: from,
            to: to,
            earliestDepart: freeFrom,
            deadline: deadline,
          );
          option = probe.option;
          warning = probe.warning;
        }

        final visitStart = option != null
            ? (option.arriveTime.isBefore(openingAt)
                  ? openingAt
                  : option.arriveTime)
            : deadline;
        final visitEnd = visitStart.add(
          Duration(minutes: attraction.recommendedVisitMinutes),
        );

        legs.add(
          PlannedPlanLeg(
            day: day,
            attractionName: attraction.name,
            from: from,
            to: to,
            option: option,
            visitStart: visitStart,
            visitEnd: visitEnd,
            warning: warning,
          ),
        );

        if (to != null) from = to;
        freeFrom = visitEnd.add(Duration(minutes: bufferMinutes));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    return legs;
  }

  Future<PlannedPlanLeg> retryPlanLeg({
    required LocationPoint from,
    required SavedTripPlanAttraction attraction,
    required int day,
    required DateTime visitStart,
    required DateTime visitEnd,
    required DateTime earliestDepart,
  }) async {
    final plannedVisitLength = visitEnd.difference(visitStart);

    LocationPoint? to;
    try {
      to = await _geocodeSavedPlanAttraction({
        'name': attraction.name,
        'address': attraction.address,
        'area': attraction.area,
      });
    } catch (error) {
      debugPrint('[TransportController] retry geocoding failed: $error');
    }

    if (to == null) {
      return PlannedPlanLeg(
        day: day,
        attractionName: attraction.name,
        from: from,
        visitStart: visitStart,
        visitEnd: visitEnd,
        warning: "Still couldn't find this attraction's address.",
      );
    }

    final probe = await _planLegToMeetDeadline(
      from: from,
      to: to,
      earliestDepart: earliestDepart,
      deadline: visitStart,
    );

    final dayDate = DateTime.utc(
      visitStart.year,
      visitStart.month,
      visitStart.day,
    );
    final openingAt = attraction.openingDateTime(dayDate);
    final option = probe.option;
    final actualVisitStart = option != null
        ? (option.arriveTime.isBefore(openingAt)
              ? openingAt
              : option.arriveTime)
        : visitStart;

    return PlannedPlanLeg(
      day: day,
      attractionName: attraction.name,
      from: from,
      to: to,
      option: option,
      visitStart: actualVisitStart,
      visitEnd: actualVisitStart.add(plannedVisitLength),
      warning: probe.warning,
    );
  }

  Future<List<PlannedPlanLeg>?> getSavedTransportPlan(String planId) async {
    final rawLegs = await _plannedTransportStore.get(planId);
    if (rawLegs == null) return null;
    return rawLegs.map(PlannedPlanLeg.fromJson).toList();
  }

  Future<void> saveTransportPlan(
    String planId,
    List<PlannedPlanLeg> legs,
  ) {
    return _plannedTransportStore.save(
      planId,
      legs.map((leg) => leg.toJson()).toList(),
    );
  }

  Future<void> deleteTransportPlan(String planId) {
    return _plannedTransportStore.remove(planId);
  }

  Future<Set<String>> plannedTransportPlanIds(Iterable<String> planIds) {
    return _plannedTransportStore.plannedPlanIds(planIds);
  }

  bool _isPureWalkOption(RideOption option) {
    return !option.legs.any(
      (leg) => !leg.isTransfer && leg.mode != TransportMode.walk,
    );
  }

  Future<_LegProbeResult> _planLegToMeetDeadline({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime earliestDepart,
    required DateTime deadline,
  }) async {
    final targetDay = DateTime.utc(
      deadline.year,
      deadline.month,
      deadline.day,
    );

    RideOption alignToTargetDay(RideOption option) {
      final optionDay = DateTime.utc(
        option.departTime.year,
        option.departTime.month,
        option.departTime.day,
      );
      final dayShift = targetDay.difference(optionDay);
      return dayShift == Duration.zero
          ? option
          : withTimeShifted(option, dayShift);
    }

    RideOption clampToEarliestDepart(RideOption option) {
      if (!option.departTime.isBefore(earliestDepart)) return option;
      return withTimeShifted(
        option,
        earliestDepart.difference(option.departTime),
      );
    }

    try {
      final firstTry = await searchRides(from: from, to: to, departAt: earliestDepart);
      if (firstTry.options.isEmpty) return const _LegProbeResult();

      var best = clampToEarliestDepart(alignToTargetDay(firstTry.options.first));
      if (!best.arriveTime.isAfter(deadline)) {
        return _LegProbeResult(option: best);
      }

      if (_isPureWalkOption(best)) {
        final walkDuration = best.arriveTime.difference(best.departTime);
        var idealDepart = deadline.subtract(walkDuration);
        if (idealDepart.isBefore(earliestDepart)) idealDepart = earliestDepart;
        final shifted = withTimeShifted(
          best,
          idealDepart.difference(best.departTime),
        );
        if (!shifted.arriveTime.isAfter(deadline)) {
          return _LegProbeResult(option: shifted);
        }
        return _LegProbeResult(
          option: shifted,
          warning:
              'Real transport to this attraction takes longer than the '
              'planned schedule allows for - you may arrive later than '
              'planned.',
        );
      }

      var attemptDepart = earliestDepart;
      for (var attempt = 0; attempt < 3; attempt++) {
        final overage = best.arriveTime.difference(deadline);
        attemptDepart = attemptDepart.subtract(
          overage + const Duration(minutes: 10),
        );
        if (!attemptDepart.isAfter(earliestDepart)) {
          break;
        }

        final retry = await searchRides(from: from, to: to, departAt: attemptDepart);
        if (retry.options.isEmpty) break;

        best = clampToEarliestDepart(alignToTargetDay(retry.options.first));
        if (!best.arriveTime.isAfter(deadline)) {
          return _LegProbeResult(option: best);
        }
      }

      return _LegProbeResult(
        option: best,
        warning:
            'Real transport to this attraction takes longer than the '
            'planned schedule allows for - you may arrive later than '
            'planned.',
      );
    } catch (error) {
      debugPrint('[TransportController] backward leg planning failed: $error');
      return const _LegProbeResult();
    }
  }

  int _estimateTravelMinutes(LocationPoint from, LocationPoint to) {
    const earthRadiusKm = 6371.0;
    final lat1 = from.lat * (math.pi / 180);
    final lat2 = to.lat * (math.pi / 180);
    final dLat = (to.lat - from.lat) * (math.pi / 180);
    final dLng = (to.lng - from.lng) * (math.pi / 180);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceKm = earthRadiusKm * c;
    const assumedKmPerHour = 25.0;
    final minutes = (distanceKm / assumedKmPerHour * 60).round();
    return minutes.clamp(5, 240);
  }

  int _bufferMinutesForStyle(String? travelStyle) {
    final style = (travelStyle ?? '').toLowerCase();
    if (style.contains('relax')) return 20;
    if (style.contains('adventure')) return 8;
    return 12;
  }

  RideOption _withTag(RideOption option, String tag) {
    return RideOption(
      id: option.id,
      title: option.title,
      legs: option.legs,
      estCostRm: option.estCostRm,
      co2Kg: option.co2Kg,
      tags: [tag, ...option.tags],
      isLiveData: option.isLiveData,
      path: option.path,
      searchDepartAt: option.searchDepartAt,
      delayEstimate: option.delayEstimate,
    );
  }

  Future<List<RideOption>> findLegAlternatives({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) {
    return TransportService.instance.findLegAlternatives(
      from: from,
      to: to,
      departAt: departAt,
    );
  }

  Future<RideOption?> findAutomaticLegReplacement({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required double plainWalkKm,
  }) {
    return TransportService.instance.findAutomaticLegReplacement(
      from: from,
      to: to,
      departAt: departAt,
      plainWalkKm: plainWalkKm,
    );
  }

  Future<List<SavedTrip>> getSavedTrips() => _savedTripsStore.getAll();

  Future<bool> isTripSaved(String tripId) => _savedTripsStore.isSaved(tripId);

  /// Flips the saved state of [trip]. Returns the new state (`true` if it
  /// is now saved, `false` if it was just removed).
  Future<bool> toggleSavedTrip(SavedTrip trip) => _savedTripsStore.toggle(trip);

  Future<void> saveTrip(SavedTrip trip) => _savedTripsStore.save(trip);

  Future<void> removeSavedTrip(String tripId) =>
      _savedTripsStore.remove(tripId);

  Future<List<RainyBikeAlert>> checkSavedTripsForRain(
    List<SavedTrip> trips,
  ) async {
    final alerts = <RainyBikeAlert>[];
    for (final trip in trips) {
      final legIndex = trip.option.legs.indexWhere(
        (leg) => leg.mode == TransportMode.bike,
      );
      if (legIndex == -1) continue;
      final leg = trip.option.legs[legIndex];
      final point = leg.startPoint ?? leg.endPoint;
      if (point == null) continue;
      try {
        final weather = await _weatherService.checkConditions(point);
        if (weather.known && weather.isRaining) {
          alerts.add(RainyBikeAlert(trip: trip, legIndex: legIndex));
        }
      } catch (error) {
        debugPrint(
          '[TransportController] rain check failed for saved trip '
          '${trip.id}: $error',
        );
      }
    }
    return alerts;
  }

  Future<SavedTrip?> swapRainyBikeLeg(RainyBikeAlert alert) async {
    final leg = alert.trip.option.legs[alert.legIndex];
    final from = leg.startPoint;
    final to = leg.endPoint;
    if (from == null || to == null) return null;

    final replacement = await findAutomaticLegReplacement(
      from: from,
      to: to,
      departAt: leg.start,
      plainWalkKm: leg.distanceKm ?? 0,
    );
    if (replacement == null) return null;

    final updatedOption = withLegReplaced(
      alert.trip.option,
      legIndex: alert.legIndex,
      replacement: replacement,
      from: alert.trip.from,
    );
    final updatedTrip = SavedTrip(
      from: alert.trip.from,
      to: alert.trip.to,
      option: updatedOption,
      savedAt: alert.trip.savedAt,
    );
    await _savedTripsStore.remove(alert.trip.id);
    await _savedTripsStore.save(updatedTrip);
    return updatedTrip;
  }
}

class RecommendedRide {
  const RecommendedRide({required this.to, required this.option});

  final LocationPoint to;
  final RideOption option;
}

class TodaysTransportStatus {
  const TodaysTransportStatus.suggestion(this.suggestion) : plannedLeg = null;

  const TodaysTransportStatus.alreadyPlanned(this.plannedLeg)
    : suggestion = null;

  final RecommendedRide? suggestion;
  final PlannedPlanLeg? plannedLeg;

  bool get isAlreadyPlanned => plannedLeg != null;
}

class _TodaysPick {
  const _TodaysPick({
    required this.planId,
    required this.dayIndex,
    required this.point,
  });

  final String planId;
  final int dayIndex;
  final LocationPoint point;
}

/// See TransportController.checkSavedTripsForRain/swapRainyBikeLeg.
class RainyBikeAlert {
  const RainyBikeAlert({required this.trip, required this.legIndex});

  final SavedTrip trip;
  final int legIndex;
}

class PlannedPlanLeg {
  const PlannedPlanLeg({
    required this.day,
    required this.attractionName,
    required this.from,
    this.to,
    this.option,
    required this.visitStart,
    required this.visitEnd,
    this.warning,
  });

  /// 1-indexed day within the plan - see
  /// SavedTripPlanAttraction.day's doc comment.
  final int day;
  final String attractionName;

  final LocationPoint from;
  final LocationPoint? to;
  final RideOption? option;

  final DateTime visitStart;
  final DateTime visitEnd;

  final String? warning;

  PlannedPlanLeg withOption(RideOption option) => PlannedPlanLeg(
    day: day,
    attractionName: attractionName,
    from: from,
    to: to,
    option: option,
    visitStart: visitStart,
    visitEnd: visitEnd,
    warning: warning,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'attractionName': attractionName,
    'from': from.toJson(),
    'to': to?.toJson(),
    'option': option?.toJson(),
    'visitStart': visitStart.toIso8601String(),
    'visitEnd': visitEnd.toIso8601String(),
    'warning': warning,
  };

  factory PlannedPlanLeg.fromJson(Map<String, dynamic> json) {
    final rawTo = json['to'];
    final rawOption = json['option'];
    return PlannedPlanLeg(
      day: (json['day'] as num?)?.toInt() ?? 1,
      attractionName: json['attractionName'] as String? ?? '',
      from: LocationPoint.fromJson(
        Map<String, dynamic>.from(json['from'] as Map),
      ),
      to: rawTo is Map
          ? LocationPoint.fromJson(Map<String, dynamic>.from(rawTo))
          : null,
      option: rawOption is Map
          ? RideOption.fromJson(Map<String, dynamic>.from(rawOption))
          : null,
      visitStart: DateTime.parse(json['visitStart'] as String),
      visitEnd: DateTime.parse(json['visitEnd'] as String),
      warning: json['warning'] as String?,
    );
  }
}

class _LegProbeResult {
  const _LegProbeResult({this.option, this.warning});

  final RideOption? option;
  final String? warning;
}
