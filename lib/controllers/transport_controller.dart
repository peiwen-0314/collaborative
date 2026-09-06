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
import '../services/weather_service.dart';

/// Orchestrates the transportation module's screens (RideHomePage,
/// SavedListPage, TripDetailsPage) against the underlying services/data
/// layer - the same role AuthController plays for the auth screens and
/// AuthService: screens call this, this calls the services, and any
/// cross-service logic (ranking results, badging the top pick, choosing a
/// destination to suggest, etc.) lives here instead of inside a View's
/// State class.
class TransportController {
  TransportController({
    LocationService? locationService,
    SavedTripsStore? savedTripsStore,
    WeatherService? weatherService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PlannedTripTransportStore? plannedTransportStore,
  }) : _locationService = locationService ?? const LocationService(),
       _savedTripsStore = savedTripsStore ?? SavedTripsStore.instance,
       _weatherService = weatherService ?? const WeatherService(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _plannedTransportStore =
           plannedTransportStore ?? PlannedTripTransportStore.instance;

  final LocationService _locationService;
  final SavedTripsStore _savedTripsStore;
  final WeatherService _weatherService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PlannedTripTransportStore _plannedTransportStore;

  // ============================================================
  // LOCATION
  // ============================================================

  /// Detects the user's current position (asks for permission if needed)
  /// and reverse-geocodes it into a named [LocationPoint].
  Future<LocationLookupResult> detectCurrentLocation() {
    return _locationService.detectCurrentLocation();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  /// The offline generator now systematically calculates every realistic
  /// mode combination for a given distance (see
  /// `MockTransportRepository._templatesFor`) rather than picking from a
  /// short fixed list, so a single search can easily produce 6-9+ options.
  /// Showing literally all of them would clutter the results list, so
  /// only the top-ranked handful actually reach the UI.
  static const _maxDisplayedOptions = 5;

  /// Searches for rides between [from] and [to], then ranks the results
  /// with the trained [RouteRecommender] model (instead of trusting
  /// whatever order HERE/OSM/the mock generator returned), keeps only the
  /// top [_maxDisplayedOptions] of that ranking, and tags whichever one
  /// ends up first with an "AI Recommended" badge so the model's pick is
  /// visible in the UI, not just an invisible reorder.
  ///
  /// Also does a real, best-effort rain check at [from] (see
  /// WeatherService) - if it's genuinely raining right now, any option
  /// that rides a real bike leg gets tagged [kRainBikeTag] (shown as an
  /// orange warning chip - see RideCard's MiniChip) and pushed after
  /// every non-bike option, so a rainy-day search still shows the bike
  /// option (it's still a real, valid choice - the same "never silently
  /// discard a real option" principle as findTransitHop) but doesn't
  /// lead with it. A failed weather check just means no tag/reorder this
  /// time, same as every other best-effort real-data call in this app.
  ///
  /// That same rain check is also reused (no second WeatherService call)
  /// to attach a [DelayEstimate] to any option with a scheduled bus leg
  /// that's either searched during a weekday peak hour or affected by
  /// that same rain - see _withDelayEstimates. This is a heuristic
  /// estimate, never a live delay feed (no public API this module can
  /// reach exposes real bus-delay data for Malaysian operators - see
  /// DelayEstimate's own doc comment), so it's always labelled
  /// "estimated"/"possible" wherever it's shown.
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
    try {
      final weather = await _weatherService.checkRain(from);
      isRaining = weather.known && weather.isRaining;
      if (isRaining) {
        options = _flagRainyBikeOptions(options);
      }
    } catch (error) {
      debugPrint('[TransportController] rain check failed: $error');
    }
    options = _withDelayEstimates(options, isRaining: isRaining);

    final ranked = RouteRecommender.rank(options);
    // Keep the model's own ordering, but move every rain-flagged option
    // after every option that isn't - a "soft" deprioritization rather
    // than hiding them, and one that can genuinely drop a rain-flagged
    // option out of the top _maxDisplayedOptions entirely if enough
    // non-bike alternatives exist.
    final reordered = [
      ...ranked.where((option) => !option.tags.contains(kRainBikeTag)),
      ...ranked.where((option) => option.tags.contains(kRainBikeTag)),
    ];
    final topRanked = reordered.take(_maxDisplayedOptions).toList();
    final badged = _withRecommendedBadge(topRanked);
    return RouteSearchResult(options: badged, isLive: result.isLive);
  }

  /// Rebuilds every option in [options] that rides a real bike leg with
  /// [kRainBikeTag] added - see searchRides' doc comment. Leaves every
  /// other option, and any option that already carries the tag,
  /// untouched.
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

  /// Attaches a [DelayEstimate] to every option that has a scheduled bus
  /// leg and at least one real risk factor present (reuses the rain
  /// check [searchRides] already made via [isRaining], instead of asking
  /// WeatherService a second time) - see searchRides' doc comment and
  /// DelayEstimate.evaluate. Leaves every other option untouched
  /// (`delayEstimate` stays null).
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

  /// [RideOption] has no `copyWith` - this just rebuilds the one changed
  /// option (the top-ranked one) with every other field carried over
  /// unchanged, plus the extra "AI Recommended" tag.
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

  /// What RideHomePage should show about "today's" saved-trip-plan
  /// destination - shown while no destination has been chosen yet (and
  /// reachable again after a search via a compact pinned card - see
  /// RideHomePage's _TodaysPlanCard/RecommendedPanel usage).
  ///
  /// Based purely on the signed-in user's own active saved trip plan
  /// (Firestore `saved_trip_plans`, written by the AI Trip Planner
  /// module's GeneratedTripPage - see _nextDestinationFromSavedPlan) -
  /// no invented/offline placeholder destination anymore. Returns null
  /// - and the panel simply doesn't show, rather than displaying a guess
  /// - whenever there's no signed-in user, no saved plan actually
  /// running today (today between its startDate/endDate), the plan has
  /// no attraction recorded for today, or that attraction's address
  /// couldn't be geocoded into real coordinates.
  ///
  /// Which of [TodaysTransportStatus]'s two shapes comes back depends on
  /// whether that plan's transportation has already been planned and
  /// saved (see PlanTransportPage's Save action /
  /// [getSavedTransportPlan]):
  ///  - Not planned yet: runs a real search to the picked destination
  ///    via [searchRides] and tags the result 'From Your Trip Plan', so
  ///    RideHomePage can nudge the person to plan it - this is the
  ///    original "recommendation" behaviour.
  ///  - Already planned: no new search happens at all - the real leg
  ///    for today is read straight back out of what was already saved,
  ///    so RideHomePage can instead tell the person their ride for
  ///    today is already sorted, rather than suggesting something
  ///    they've already handled.
  Future<TodaysTransportStatus?> todaysTransportStatus(
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

  /// Looks for today's destination in the signed-in user's own active
  /// saved trip plan - see [todaysTransportStatus]'s doc comment. Only
  /// ever looks at plans this exact user saved (`userId` ==
  /// FirebaseAuth's current uid) with `status == 'saved'` (a plan that
  /// was since un-saved is simply deleted, per
  /// GeneratedTripPage._toggleSavePlan - this check is just
  /// future-proofing against a soft-delete status being added later)
  /// whose [startDate, endDate] window (inclusive) covers today - a plan
  /// for a trip that hasn't started yet or has already ended isn't
  /// "next", it's irrelevant right now.
  ///
  /// Within a matching plan, picks the attraction recorded for TODAY's
  /// own day-index (`day` - 1-indexed from the plan's startDate, see
  /// GeneratedTripPage._getAttractionDay, the only place that writes
  /// it), falling back to the plan's very first attraction if today's
  /// exact day somehow has none (e.g. a plan saved with an uneven
  /// attractions-per-day split). Returns null (never throws) if there's
  /// no signed-in user, no matching plan, or the picked attraction's
  /// address can't be geocoded into real coordinates - this module
  /// doesn't import the planning module's own models, it only reads the
  /// raw fields GeneratedTripPage itself writes, so a shape it doesn't
  /// recognise is skipped rather than crashing this whole panel.
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
      // This plan's pick didn't geocode - keep checking any other
      // active plan (rare: overlapping saved plans) rather than giving
      // up on the very first match.
    }
    return null;
  }

  /// Resolves a saved-plan attraction's real coordinates. The planning
  /// module's own AttractionModel has no latitude/longitude of its own
  /// (only a text address/area/state - see attraction.dart), so this
  /// goes through the exact same real geocoding path a manually typed
  /// "To" field uses (LocationService.searchPlace, HERE Autosuggest with
  /// a free Nominatim fallback) rather than needing a second data
  /// source. Tries the full street address first (most specific), then
  /// falls back to "name, area" if that doesn't resolve - some
  /// attractions only have a short/informal address on file.
  /// Geocodes one saved-plan attraction for real transportation
  /// planning, trying progressively broader real queries before giving
  /// up entirely - the same idea DestinationPhotoService already uses
  /// for header photos (street -> area -> city -> ... before it falls
  /// back to a plain map pin): a plan's own saved `address` string is
  /// often incomplete or oddly formatted for a general-purpose
  /// geocoder, but combining it with the attraction's own name, or
  /// falling back to the name/area on their own, regularly resolves a
  /// real point where the bare address alone doesn't. Every candidate
  /// is a genuine geocoder lookup - never a guessed/interpolated
  /// coordinate - so a real result here is exactly as trustworthy as
  /// before, there's just more real chances taken before this reports
  /// "couldn't find this attraction's location at all" (see
  /// planTransportationForPlan/retryPlanLeg's own handling of a null
  /// result).
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

  // ============================================================
  // TRIP PLANS (whole-plan transportation)
  // ============================================================

  /// Every saved trip plan (Firestore `saved_trip_plans`, written by the
  /// AI Trip Planner module's GeneratedTripPage) the signed-in user has
  /// that hasn't ended yet (today <= endDate) - unlike
  /// _nextDestinationFromSavedPlan's stricter "running today" test, this
  /// deliberately also includes a plan that hasn't started yet, since
  /// TripPlansPage's whole point is showing every upcoming/ongoing trip
  /// worth planning transportation for, not just today's single pick.
  /// Sorted soonest-starting first.
  ///
  /// Throws (rather than returning an empty list) when there's no
  /// signed-in user, so TripPlansPage can show "please log in" instead
  /// of a misleading "you have no trip plans".
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

  /// Plans a real transportation leg for every attraction in [plan], day
  /// by day - "plan transportation for the whole trip", not just one
  /// destination (see PlanTransportPage, the only caller). Each day
  /// starts fresh from [startingFrom] (the person's own current
  /// location - this assumes a day-trip pattern, going out from and
  /// back to the same base each day, not staying overnight AT an
  /// attraction).
  ///
  /// This works BACKWARDS from a deadline, not forwards from a guess:
  /// the itinerary the person already committed to (day starts 9am,
  /// each attraction visited for its own real recommended duration,
  /// gap between stops per the travel-style buffer - the exact same
  /// shape as the AI Trip Planner module's own
  /// _buildLogicalSchedule/_bufferMinutes, using the SAME saved data
  /// that module wrote: see SavedTripPlanAttraction) fixes each
  /// attraction's own "must be there by" deadline FIRST - see
  /// [_estimateTravelMinutes], a rough straight-line-distance estimate
  /// that only ever feeds this target schedule, mirroring the role
  /// AiTripPlannerController.estimateTransportMinutes plays in that
  /// module. Only THEN does this method go looking for the real
  /// transportation to hit that deadline (see
  /// [_planLegToMeetDeadline]): first a real [searchRides] departing as
  /// soon as the person is free, and if that real schedule would
  /// actually arrive too late, real searches at progressively earlier
  /// departure times, keeping the latest real service that still makes
  /// it - i.e. reverse-engineering roughly when transport needs to
  /// happen from the required arrival time, exactly as asked, rather
  /// than letting a live search result silently reshape the plan the
  /// person already made. If no real service can make the deadline
  /// after a few tries, the closest real option found is still shown
  /// (never a fabricated one - see TransportService's own doc comment)
  /// but [PlannedPlanLeg.warning] says so plainly instead of hiding it.
  ///
  /// Runs one search at a time, not in parallel: each attraction's
  /// search needs the previous one's real arrival point first, and a
  /// whole trip is a handful of searches at most - not worth the
  /// added complexity/rate-limit risk of firing them all at once.
  /// Never throws: a single attraction that can't be geocoded or
  /// doesn't return a real route just gets a [PlannedPlanLeg] with a
  /// null [PlannedPlanLeg.option] so the rest of the plan still comes
  /// back, and the person can see exactly which day/attraction needs a
  /// manual look instead of the whole plan silently failing.
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

      // DateTime.utc here (not the plain DateTime(...) this used to
      // use) - not because this day is "in UTC", but because every
      // schedule DateTime this method builds (dayDate/freeFrom/deadline
      // below, and SavedTripPlanAttraction.openingDateTime/
      // closingDateTime) needs to live in the SAME representation as a
      // live search result's own departTime/arriveTime coming back
      // from TransportService: a real HERE result's time, after
      // HereTransitService._parseTime's instantToMalaysiaWallClock fix,
      // is a DateTime that's flagged isUtc but whose year/month/day/
      // hour/minute fields ARE the Malaysia wall-clock numbers - see
      // that function's own doc comment. Building this method's own
      // "9am on this trip day" via plain DateTime(...) instead put it
      // in a completely different representation (a genuine real
      // instant, correct only on a device whose OWN system timezone
      // happens to be Malaysia's) - comparing or subtracting the two
      // (best.arriveTime.isAfter(deadline) below, or
      // idealDepart.difference(best.departTime) in the pure-walk
      // branch) was silently comparing/subtracting two DateTimes that
      // each meant something different, off by however many hours the
      // device's real timezone differs from Malaysia's fixed UTC+8 -
      // exactly how a bus that genuinely arrives hours BEFORE a visit
      // deadline still got flagged as "late" (see this method's
      // deadline-check just below), and how the pure-walk branch's own
      // fix still came out shifted by roughly that same 8 hours. Using
      // DateTime.utc consistently here - the same convention
      // instantToMalaysiaWallClock's output already uses - makes every
      // comparison in this method a same-representation comparison
      // regardless of what timezone any given device is actually set
      // to.
      final dayDate = DateTime.utc(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day + (day - 1),
      );

      var from = startingFrom;
      // The itinerary's own fixed schedule - when the person is free to
      // leave for the NEXT attraction. Never overwritten by a real
      // search result (see this method's doc comment) - only ever
      // advanced by real, known quantities: the previous attraction's
      // own visit length and the travel-style buffer.
      var freeFrom = DateTime.utc(dayDate.year, dayDate.month, dayDate.day, 9);

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

        // The deadline: the itinerary's own target arrival time for
        // this attraction, worked out from a rough travel-time estimate
        // (never a real search) plus this attraction's real opening
        // time - the same "arrive by X" the person already planned.
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

        // visitStart is the REAL time the person is expected to be at
        // this attraction - so once a real option was actually found,
        // use ITS real arrival time (clamped so it's never before the
        // attraction's own real opening time - arriving early doesn't
        // let you start visiting before it opens), not [deadline]
        // (which was only ever a rough target used to decide what time
        // to search transport FOR, not a promise of when transport
        // would actually get you there - see this method's own doc
        // comment on [_estimateTravelMinutes]). A real bus that
        // genuinely gets you there earlier - or, with a warning, later
        // - than the rough target should show up as exactly that
        // arrival time, not the original guess, so the "Visit" window
        // always describes the itinerary this leg's OWN real
        // transportation actually produces. Only falls back to
        // [deadline] when there's no real option at all (couldn't
        // geocode, or no route found - see [_UnplannedLegTile]).
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

        // Chain the NEXT attraction in this same day from here, so a
        // multi-stop day reads as a real point-to-point itinerary
        // rather than every stop routing from the morning starting
        // point again.
        if (to != null) from = to;
        freeFrom = visitEnd.add(Duration(minutes: bufferMinutes));
      }
    }

    return legs;
  }

  /// Retries planning ONE leg that previously failed - see
  /// PlanTransportPage's Retry / "Change starting point" actions on an
  /// unplanned leg, the only caller. Re-geocodes [attraction] (in case
  /// the original failure was there), then searches for a real route
  /// from [from] to it, targeting [visitStart] as the deadline the same
  /// way the original whole-day pass did (see _planLegToMeetDeadline) -
  /// [from] can be the leg's original starting point (a plain retry,
  /// for a transient failure) or one the person just corrected (when
  /// the real problem was a bad starting point, not the attraction
  /// itself). [day]/[visitStart]/[visitEnd] are carried over unchanged
  /// from the leg being retried, since only where the search starts
  /// from - not the plan's own itinerary - is what's being redone
  /// here.
  ///
  /// Never throws - a failed retry just comes back as the same kind of
  /// "couldn't find a route" [PlannedPlanLeg] as before (with
  /// [PlannedPlanLeg.warning] explaining why), not an error the person
  /// has to handle separately from the ones planTransportationForPlan
  /// itself can already produce.
  Future<PlannedPlanLeg> retryPlanLeg({
    required LocationPoint from,
    required SavedTripPlanAttraction attraction,
    required int day,
    required DateTime visitStart,
    required DateTime visitEnd,
  }) async {
    // The visit LENGTH is the one thing worth preserving unchanged from
    // the leg being retried (this attraction's own recommended visit
    // duration) - [visitStart] itself gets recomputed below from
    // whatever real option this retry actually finds, same reasoning
    // as planTransportationForPlan's own visitStart (see that leg's
    // doc comment).
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
      earliestDepart: visitStart.subtract(const Duration(hours: 3)),
      deadline: visitStart,
    );

    // Same DateTime.utc convention as planTransportationForPlan's own
    // dayDate (see that method's doc comment) - built from [visitStart]
    // itself since a retry doesn't have the day's own dayDate handy,
    // just this one leg's already-resolved DateTimes.
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

  // ============================================================
  // WHOLE-PLAN TRANSPORTATION - PERSISTENCE
  // ============================================================

  /// The transportation plan already saved for [planId] (see
  /// [saveTransportPlan]), or null if this trip plan hasn't had its
  /// transportation planned/saved yet. PlanTransportPage checks this
  /// first so reopening an already-planned trip doesn't re-run every
  /// search; TransportController.todaysTransportStatus checks it so
  /// RideHomePage can tell the difference between "please plan this"
  /// and "you already did".
  Future<List<PlannedPlanLeg>?> getSavedTransportPlan(String planId) async {
    final rawLegs = await _plannedTransportStore.get(planId);
    if (rawLegs == null) return null;
    return rawLegs.map(PlannedPlanLeg.fromJson).toList();
  }

  /// Persists [legs] (the result of [planTransportationForPlan]) as
  /// [planId]'s saved transportation plan - see PlanTransportPage's Save
  /// action, the only caller. Overwrites whatever was saved before, so
  /// "re-plan" is just calling this again with a freshly computed list.
  Future<void> saveTransportPlan(
    String planId,
    List<PlannedPlanLeg> legs,
  ) {
    return _plannedTransportStore.save(
      planId,
      legs.map((leg) => leg.toJson()).toList(),
    );
  }

  /// Removes [planId]'s saved transportation plan entirely, so it goes
  /// back to showing as "not planned yet" (see [plannedTransportPlanIds]
  /// / TripPlansPage's badge).
  Future<void> deleteTransportPlan(String planId) {
    return _plannedTransportStore.remove(planId);
  }

  /// Which of [planIds] already have a saved transportation plan - used
  /// by TripPlansPage to badge each trip plan "Transport planned" vs
  /// "Not planned yet" without a read per plan.
  Future<Set<String>> plannedTransportPlanIds(Iterable<String> planIds) {
    return _plannedTransportStore.plannedPlanIds(planIds);
  }

  /// Finds the real transportation to reach [to] by [deadline], working
  /// backwards when needed - see planTransportationForPlan's doc
  /// comment for why. First tries departing as soon as the person is
  /// free ([earliestDepart]); if that real schedule already makes the
  /// deadline, that's the answer. If not - the real trip takes longer
  /// than the plan assumed - retries a few real searches at
  /// progressively earlier departure times (never a guess in the other
  /// direction: only ever pulling the search earlier, never later than
  /// [earliestDepart], since the person genuinely isn't free before
  /// then), keeping the latest real option that still makes it. If none
  /// of those do either, the closest real option found is returned
  /// with [_LegProbeResult.warning] set, instead of silently keeping a
  /// late option or hiding the problem.
  ///
  /// Every real result is re-dated onto [deadline]'s own calendar day
  /// (see the local alignToTargetDay helper below) before it's compared against
  /// [deadline] at all, or ever handed back for display - a live search
  /// can come back on a genuinely different real date than the one
  /// asked for (e.g. HERE silently answering "the next real departure
  /// from right now" when the requested time has already passed in the
  /// real world, which happens whenever a plan's fixed 9am-start
  /// assumption for "today" is itself already behind real time), and
  /// comparing/showing that against a deadline on the INTENDED day
  /// produced exactly the nonsense this fixes: a real "Live Route" card
  /// confidently showing an evening departure right next to an 11am
  /// visit window, with no warning at all because the raw comparison
  /// (today's evening vs. some other day's late morning) accidentally
  /// came out "on time". Re-dating first means the deadline check - and
  /// the Departs/Est. Arrival shown on the card - always land on the
  /// same day the itinerary actually means, so a real mismatch like
  /// that shows up as a genuine miss (and the honest warning below)
  /// instead of a false pass.
  /// True when every real (non-transfer) leg of [option] is a walk -
  /// i.e. there's no real bus/train/taxi/bike alternative at all, only
  /// walking. Same check as TransportService._isPureWalk (kept as its
  /// own private copy here rather than a shared import, same reasoning
  /// as every other small per-file helper in this module) - used by
  /// [_planLegToMeetDeadline] to skip its schedule-retry loop for a
  /// walk, which has no real schedule to retry against.
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
    // DateTime.utc, not DateTime(...) - see planTransportationForPlan's
    // dayDate/freeFrom doc comment: deadline/option.departTime are both
    // already in that same "isUtc but fields are Malaysia wall clock"
    // representation, so targetDay/optionDay need to be built in it too
    // for dayShift below to come out as a clean whole-day difference
    // instead of being skewed by whatever the device's real timezone
    // happens to be.
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

    try {
      final firstTry = await searchRides(from: from, to: to, departAt: earliestDepart);
      if (firstTry.options.isEmpty) return const _LegProbeResult();

      var best = alignToTargetDay(firstTry.options.first);
      if (!best.arriveTime.isAfter(deadline)) {
        return _LegProbeResult(option: best);
      }

      // A pure walk (no real bus/train/taxi/bike alternative at all -
      // see _isPureWalkOption) has no real schedule to retry against:
      // walking the same real distance takes the same real duration no
      // matter what time of day you start, so the retry loop below
      // (built for a SCHEDULED service that might genuinely run again
      // earlier) can never find anything different for a walk - it
      // would just keep pushing attemptDepart backwards by roughly the
      // same "overage" every time, wrapping through however many
      // calendar days it takes to close a gap a walk's own fixed
      // duration can never close, and alignToTargetDay would then
      // re-date whatever wall-clock hour that lands on back onto
      // today - producing exactly a "Walk departs 9:49pm" next to an
      // 11am visit window. Instead, work out directly when the walk
      // SHOULD start: as late as possible while still meeting the
      // deadline, but never before the person is actually free to
      // leave ([earliestDepart]) - if even leaving the moment they're
      // free still wouldn't make it, that's a genuine, honestly
      // reported miss (the warning below), not something retrying a
      // walk can ever fix.
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
        // Never try - or accept - a departure at or before
        // [earliestDepart] itself: that's the earliest real moment the
        // person is actually free to leave (see this method's own
        // parameter doc comment), so a "real" service found by
        // searching further back than that is a genuine, correctly
        // scheduled bus/train the person simply CANNOT catch - not a
        // usable answer, no matter how good it looks on paper (this
        // used to only cap the search a full day before earliestDepart,
        // which is how a bus that genuinely runs at 5:30am could get
        // returned as "the plan" for someone who isn't even free to
        // leave until 9am). [firstTry] already searched exactly at
        // earliestDepart, so once subtracting would put us at or
        // before it, there's nothing further back worth trying - stop
        // and fall through to the honest "couldn't make it in time"
        // warning below instead of a technically-on-time-but-actually-
        // uncatchable option.
        if (!attemptDepart.isAfter(earliestDepart)) {
          break;
        }

        final retry = await searchRides(from: from, to: to, departAt: attemptDepart);
        if (retry.options.isEmpty) break;

        best = alignToTargetDay(retry.options.first);
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

  /// A rough straight-line-distance estimate of travel time between two
  /// points, in minutes - used ONLY to build the day's fixed target
  /// schedule (see planTransportationForPlan), the same role
  /// AiTripPlannerController.estimateTransportMinutes plays in that
  /// module's own schedule. Never used as if it were a real transit
  /// time itself - the real time always comes from a genuine
  /// [searchRides] call in [_planLegToMeetDeadline].
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
    // ~25 km/h average, accounting for transfers/walking/local roads -
    // deliberately conservative since this only sets the TARGET
    // deadline, never a real search result.
    const assumedKmPerHour = 25.0;
    final minutes = (distanceKm / assumedKmPerHour * 60).round();
    return minutes.clamp(5, 240);
  }

  /// Same buffer-between-stops rule as
  /// AiTripPlannerController._bufferMinutes, mirrored here for the same
  /// reason as SavedTripPlanAttraction's own mirrored parsing helpers -
  /// see planTransportationForPlan's doc comment.
  int _bufferMinutesForStyle(String? travelStyle) {
    final style = (travelStyle ?? '').toLowerCase();
    if (style.contains('relax')) return 20;
    if (style.contains('adventure')) return 8;
    return 12;
  }

  /// [RideOption] has no `copyWith` - this just rebuilds [option] with
  /// [tag] prepended to its tags, every other field carried over
  /// unchanged. Shared by todaysTransportStatus (tags a saved-trip-plan
  /// pick so RideCard shows why it was suggested, the same way "AI
  /// Recommended" already explains searchRides' top pick).
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

  /// Every real HERE alternative for one specific leg of an already-
  /// chosen [RideOption] - see TransportService.findLegAlternatives for
  /// why this exists (TripDetailsPage's per-leg Edit feature) and why it
  /// deliberately returns every real alternative instead of picking one.
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

  /// Every real HERE alternative for one specific leg of an already-
  /// chosen [RideOption] - see TransportService.findAutomaticLegReplacement
  /// for why this exists (SavedListPage's rain-triggered auto-swap,
  /// where nobody is present to pick from a list) and why it never picks
  /// a pure-walk result.
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

  // ============================================================
  // SAVED TRIPS
  // ============================================================

  Future<List<SavedTrip>> getSavedTrips() => _savedTripsStore.getAll();

  Future<bool> isTripSaved(String tripId) => _savedTripsStore.isSaved(tripId);

  /// Flips the saved state of [trip]. Returns the new state (`true` if it
  /// is now saved, `false` if it was just removed).
  Future<bool> toggleSavedTrip(SavedTrip trip) => _savedTripsStore.toggle(trip);

  /// Unconditionally saves [trip] - unlike [toggleSavedTrip], never
  /// removes an existing save. Used by TripDetailsPage's "you changed
  /// this trip, save it?" prompt after an Edit: the person is answering
  /// a yes/no save question, not toggling a heart icon, so a plain save
  /// (not a toggle that could instead un-save something) is what "yes"
  /// should actually mean.
  Future<void> saveTrip(SavedTrip trip) => _savedTripsStore.save(trip);

  Future<void> removeSavedTrip(String tripId) =>
      _savedTripsStore.remove(tripId);

  /// Real, best-effort rain check (see WeatherService) for every trip in
  /// [trips] that has a real bike leg - checked at that leg's own real
  /// pickup-station location (not [from]/[to] the way searchRides checks
  /// the search origin), since that's the actual point where someone
  /// would be standing in the rain unlocking a bike. Returns one
  /// [RainyBikeAlert] per trip that's both bike-legged AND currently
  /// raining there - SavedListPage prompts about these one at a time.
  /// Never throws: a trip whose weather check fails is simply skipped,
  /// same as every other best-effort real-data call in this app.
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
        final weather = await _weatherService.checkRain(point);
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

  /// Swaps [alert]'s bike leg for a real, automatically-picked
  /// alternative (see findAutomaticLegReplacement) and persists the
  /// result - since the swap changes RideOption.id (see
  /// withLegReplaced), and SavedTrip.id embeds that, this necessarily
  /// means removing the old saved document and saving a new one rather
  /// than updating one in place. Returns the new SavedTrip on success,
  /// or null if no real replacement could be found (nothing is removed
  /// in that case - the original saved trip is left exactly as it was)
  /// or the leg's real endpoints aren't known.
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

/// See TransportController.todaysTransportStatus/RideHomePage's
/// RecommendedPanel. [option] IS the recommendation - the best real
/// route already found for it - so tapping the panel opens straight
/// into its own detail page (RideHomePage._selectRecommended), not a
/// fresh search that would hand back a whole list to choose from again.
/// [to] is only kept alongside it for whatever still needs the plain
/// destination point on its own (e.g. RecommendedRide.to's own callers
/// before this leg has a detail page open yet).
class RecommendedRide {
  const RecommendedRide({required this.to, required this.option});

  final LocationPoint to;
  final RideOption option;
}

/// What RideHomePage shows about "today's" saved-trip-plan destination -
/// see TransportController.todaysTransportStatus, the only place this
/// is built. Exactly one of [suggestion]/[plannedLeg] is set:
///  - [TodaysTransportStatus.suggestion]: nothing's been planned for
///    today's destination yet - RideHomePage shows the original
///    "Recommended For You" nudge (RecommendedPanel/_TodaysPlanCard),
///    tapping which opens that recommended route's own detail page
///    directly (see RideHomePage._selectRecommended).
///  - [TodaysTransportStatus.alreadyPlanned]: the person already saved
///    a whole-trip transportation plan that covers today (see
///    PlanTransportPage's Save action) - RideHomePage shows a
///    non-actionable-search "you're set for today" card instead,
///    reading the real leg straight back from what was saved rather
///    than re-suggesting a plan already handled.
class TodaysTransportStatus {
  const TodaysTransportStatus.suggestion(this.suggestion) : plannedLeg = null;

  const TodaysTransportStatus.alreadyPlanned(this.plannedLeg)
    : suggestion = null;

  final RecommendedRide? suggestion;
  final PlannedPlanLeg? plannedLeg;

  bool get isAlreadyPlanned => plannedLeg != null;
}

/// The signed-in user's own active saved trip plan's pick for today -
/// see TransportController._nextDestinationFromSavedPlan, the only
/// place this is built. Carries the plan's own Firestore document id
/// (so a saved transport plan can be looked up for it - see
/// [TodaysTransportStatus]) alongside today's real day-index and
/// geocoded point.
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

/// One computed leg of a whole-plan itinerary - see
/// TransportController.planTransportationForPlan. [option] (and [to])
/// are null when this specific attraction's address couldn't be
/// geocoded, or no real route could be found for it - PlanTransportPage
/// shows that leg as "couldn't plan this one" rather than silently
/// dropping it, so a person can see exactly which day/attraction needs
/// a manual look.
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

  /// Where this leg's search actually started from - the person's own
  /// current location for the first attraction of a day, or the
  /// previous attraction's own real point for a later one that same day
  /// (see planTransportationForPlan's chaining).
  final LocationPoint from;
  final LocationPoint? to;
  final RideOption? option;

  /// This attraction's own planned visit window - when the person is
  /// actually expected to be AT this attraction, not the ride to get
  /// there. [visitStart] is [option]'s own real arrival time (clamped
  /// to this attraction's real opening time) whenever a real option was
  /// found - see planTransportationForPlan/retryPlanLeg's own doc
  /// comments on why this reflects the actual transportation rather
  /// than the rough target deadline it was searched against - and
  /// falls back to that rough deadline only when there's no real option
  /// at all ([option] null). [visitEnd] is [visitStart] plus this
  /// attraction's own recommended visit length.
  final DateTime visitStart;
  final DateTime visitEnd;

  /// Set when no real transportation could be found that reaches [to]
  /// by [visitStart] - [option] is still the closest real one found
  /// (never a fabricated one), but the person should know the planned
  /// arrival time may not actually be achievable - see
  /// _planLegToMeetDeadline's doc comment.
  final String? warning;

  /// For PlannedTripTransportStore - see
  /// TransportController.saveTransportPlan/getSavedTransportPlan, the
  /// only callers. [option]/[to] round-trip through RideOption/
  /// LocationPoint's own toJson/fromJson (already used by SavedTrip);
  /// [visitStart]/[visitEnd] as ISO-8601 strings.
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

/// A real option found for one [PlannedPlanLeg], and whether it actually
/// meets that leg's deadline - see
/// TransportController._planLegToMeetDeadline, the only place this is
/// built.
class _LegProbeResult {
  const _LegProbeResult({this.option, this.warning});

  final RideOption? option;
  final String? warning;
}
