import 'package:flutter/foundation.dart' show debugPrint;
import 'package:geolocator/geolocator.dart';

import '../data/heritage_data.dart';
import '../data/transport_data.dart';
import '../models/heritage_attraction.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../models/transport_mode.dart';
import '../services/location_service.dart';
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
  }) : _locationService = locationService ?? const LocationService(),
       _savedTripsStore = savedTripsStore ?? SavedTripsStore.instance,
       _weatherService = weatherService ?? const WeatherService();

  final LocationService _locationService;
  final SavedTripsStore _savedTripsStore;
  final WeatherService _weatherService;

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
    try {
      final weather = await _weatherService.checkRain(from);
      if (weather.known && weather.isRaining) {
        options = _flagRainyBikeOptions(options);
      }
    } catch (error) {
      debugPrint('[TransportController] rain check failed: $error');
    }

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
          ),
    ];
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
    );
    return [badged, ...ranked.skip(1)];
  }

  /// A real "Recommended For You" pick for RideHomePage's panel, shown
  /// while no destination has been chosen yet (and reachable again after
  /// a search via a header shortcut - see RideHomePage._showRecommendedSheet).
  /// Picks the real cultural heritage attraction nearest [from] (the same
  /// HeritageData this app's cultural heritage module already uses - see
  /// HeritageNearbyService for the identical distance-based pattern) and
  /// runs a real search to it via [searchRides], so this is a genuine,
  /// bookable route, not an invented preview. This "nearest real place"
  /// heuristic is a stand-in for genuine personalisation - see the
  /// "Based on your travel plan and preferences" subtitle on the panel
  /// itself - until a real travel-plan/preferences model exists to base
  /// it on. Best-effort only: returns null if there's nowhere to
  /// recommend or the search itself fails, so the panel (and its header
  /// shortcut) just don't show rather than crashing the home page.
  Future<RecommendedRide?> recommendedRideTo(LocationPoint from) async {
    final attraction = _nearestAttraction(from);
    if (attraction == null) return null;

    final to = LocationPoint(
      name: attraction.name,
      lat: attraction.latitude,
      lng: attraction.longitude,
    );
    try {
      final result = await searchRides(
        from: from,
        to: to,
        departAt: DateTime.now(),
      );
      if (result.options.isEmpty) return null;
      return RecommendedRide(to: to, option: result.options.first);
    } catch (error) {
      debugPrint('[TransportController] recommendedRideTo failed: $error');
      return null;
    }
  }

  HeritageAttraction? _nearestAttraction(LocationPoint from) {
    HeritageAttraction? nearest;
    var nearestMeters = double.infinity;
    for (final attraction in HeritageData.attractions) {
      final meters = Geolocator.distanceBetween(
        from.lat,
        from.lng,
        attraction.latitude,
        attraction.longitude,
      );
      if (meters < nearestMeters) {
        nearestMeters = meters;
        nearest = attraction;
      }
    }
    return nearest;
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

/// See TransportController.recommendedRideTo/RideHomePage's
/// RecommendedPanel. [to] is what gets filled into the "To" field once
/// the person taps the panel/sheet - [option] is only the preview ride
/// shown on it (a fresh search still runs on tap, same as picking any
/// other real destination, since [option]'s own times/availability can
/// go stale the longer it sits on screen unpicked).
class RecommendedRide {
  const RecommendedRide({required this.to, required this.option});

  final LocationPoint to;
  final RideOption option;
}

/// See TransportController.checkSavedTripsForRain/swapRainyBikeLeg.
class RainyBikeAlert {
  const RainyBikeAlert({required this.trip, required this.legIndex});

  final SavedTrip trip;
  final int legIndex;
}
