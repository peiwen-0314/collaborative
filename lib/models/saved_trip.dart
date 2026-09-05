import 'location_point.dart';
import 'ride_option.dart';

/// A ride the user bookmarked from the "Saved List" section.
class SavedTrip {
  const SavedTrip({
    required this.from,
    required this.to,
    required this.option,
    required this.savedAt,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;
  final DateTime savedAt;

  /// Stable identity for a saved trip: same route + same ride option.
  String get id => '${from.name}|${to.name}|${option.id}';

  Map<String, dynamic> toJson() => {
    'from': from.toJson(),
    'to': to.toJson(),
    'option': option.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
    from: LocationPoint.fromJson(json['from'] as Map<String, dynamic>),
    to: LocationPoint.fromJson(json['to'] as Map<String, dynamic>),
    option: RideOption.fromJson(json['option'] as Map<String, dynamic>),
    savedAt: DateTime.parse(json['savedAt'] as String),
  );
}

/// Every [SavedTrip] that shares the same real from/to pair - e.g. three
/// different bus-route combinations someone bookmarked for the same
/// "Well Mart Enterprise -> Jelutong" journey. Lets the Saved List show
/// one from/to header per real journey, with every route option for it
/// listed underneath, instead of repeating the same header once per
/// saved option.
class SavedTripGroup {
  const SavedTripGroup({
    required this.from,
    required this.to,
    required this.trips,
  });

  final LocationPoint from;
  final LocationPoint to;

  /// Never empty - a group only exists because at least one trip put it
  /// there (see [groupSavedTrips]).
  final List<SavedTrip> trips;
}

/// Groups [trips] by identical from/to pair (see [SavedTripGroup]) -
/// [LocationPoint]'s own `==` already compares name+coordinates, so this
/// only merges trips that are genuinely the same real journey, never two
/// different places that just happen to share a display name. Each
/// group's own trips keep their relative order from [trips].
///
/// Group order matches [trips]' own order (by first appearance) unless
/// [currentLocation] is given, in which case groups are sorted by real
/// distance from it to the group's `from` point - nearest first, so the
/// saved trips actually near where the person is right now surface
/// first instead of in whatever order they happened to be saved.
List<SavedTripGroup> groupSavedTrips(
  List<SavedTrip> trips, {
  LocationPoint? currentLocation,
}) {
  final byRoute = <(LocationPoint, LocationPoint), List<SavedTrip>>{};
  for (final trip in trips) {
    byRoute.putIfAbsent((trip.from, trip.to), () => []).add(trip);
  }

  final groups = [
    for (final entry in byRoute.entries)
      SavedTripGroup(from: entry.key.$1, to: entry.key.$2, trips: entry.value),
  ];

  if (currentLocation != null) {
    groups.sort(
      (a, b) => currentLocation
          .distanceKm(a.from)
          .compareTo(currentLocation.distanceKm(b.from)),
    );
  }
  return groups;
}
