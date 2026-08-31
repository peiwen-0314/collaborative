import '../data/known_locations_data.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../services/location_service.dart';
import '../services/route_recommender_service.dart';
import '../services/saved_trips_storage_service.dart';
import '../services/transport_service.dart';

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
  }) : _locationService = locationService ?? const LocationService(),
       _savedTripsStore = savedTripsStore ?? SavedTripsStore.instance;

  final LocationService _locationService;
  final SavedTripsStore _savedTripsStore;

  // ============================================================
  // LOCATION
  // ============================================================

  /// Detects the user's current position (asks for permission if needed)
  /// and reverse-geocodes it into a named [LocationPoint].
  Future<LocationLookupResult> detectCurrentLocation() {
    return _locationService.detectCurrentLocation();
  }

  /// Sensible offline fallback starting point for when detection fails
  /// with an unexpected error (as opposed to a deliberate permission/
  /// service denial, which should leave "From" blank for the user to fill
  /// in themselves instead of guessing).
  LocationPoint get defaultFallbackLocation => kKnownLocations.firstWhere(
    (place) => place.name == 'KL Sentral, Kuala Lumpur',
    orElse: () => kKnownLocations.first,
  );

  // ============================================================
  // SEARCH
  // ============================================================

  /// Searches for rides between [from] and [to], then ranks the results
  /// with the trained [RouteRecommender] model (instead of trusting
  /// whatever order HERE/OSM/the mock generator returned) and tags the
  /// top-ranked option with an "AI Recommended" badge so the model's pick
  /// is visible in the UI, not just an invisible reorder.
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

    final ranked = _withRecommendedBadge(RouteRecommender.rank(result.options));
    return RouteSearchResult(options: ranked, isLive: result.isLive);
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

  // ============================================================
  // "RECOMMENDED FOR YOU" (placeholder pick shown before a destination
  // has been chosen yet - stand-in until the travel-plan module can
  // supply a real recommendation)
  // ============================================================

  /// Picks a destination to suggest: the most recent saved trip's
  /// destination that isn't [from] itself, otherwise a well-known nearby
  /// place. Returns null if nothing sensible is available (e.g. every
  /// known place happens to equal [from]).
  LocationPoint? pickRecommendedDestination({
    required LocationPoint from,
    required List<SavedTrip> savedTrips,
  }) {
    LocationPoint? destination;
    for (final trip in savedTrips) {
      if (trip.to != from) {
        destination = trip.to;
        break;
      }
    }
    destination ??= kKnownLocations.firstWhere(
      (place) => place != from,
      orElse: () => from,
    );
    return destination == from ? null : destination;
  }

  /// Generates a single offline route from [from] to [destination], purely
  /// for display in "Recommended For You". Deliberately reuses the same
  /// offline generator the rest of the app falls back to, rather than
  /// calling the live API for a suggestion nobody asked for yet.
  Future<RideOption?> recommendedRideTo({
    required LocationPoint from,
    required LocationPoint destination,
  }) async {
    final options = await const MockTransportRepository().search(
      from: from,
      to: destination,
      departAt: DateTime.now(),
    );
    return options.isNotEmpty ? options.first : null;
  }

  // ============================================================
  // SAVED TRIPS
  // ============================================================

  Future<List<SavedTrip>> getSavedTrips() => _savedTripsStore.getAll();

  Future<bool> isTripSaved(String tripId) => _savedTripsStore.isSaved(tripId);

  /// Flips the saved state of [trip]. Returns the new state (`true` if it
  /// is now saved, `false` if it was just removed).
  Future<bool> toggleSavedTrip(SavedTrip trip) => _savedTripsStore.toggle(trip);

  Future<void> removeSavedTrip(String tripId) => _savedTripsStore.remove(tripId);
}
