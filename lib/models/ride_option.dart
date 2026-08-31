import '../models/location_point.dart';
import 'trip_leg.dart';

/// One selectable route between the current From/To search, e.g.
/// "MRT + Walk" or "KTM Komuter + Express Bus + Ferry".
class RideOption {
  const RideOption({
    required this.id,
    required this.title,
    required this.legs,
    required this.estCostRm,
    required this.co2Kg,
    required this.tags,
    required this.searchDepartAt,
    this.isLiveData = false,
    this.path = const [],
  });

  final String id;
  final String title;
  final List<TripLeg> legs;
  final double estCostRm;
  final double co2Kg;

  /// The `departAt` time the *search itself* was made for - not this
  /// option's own first-leg start time (that's [departTime] below). A real
  /// scheduled service (a bus, a train) can genuinely not run again for
  /// hours after you search, and HERE correctly reports that real
  /// departure time - but comparing options purely by [totalDuration]
  /// (which only measures this option's own timeline, ignoring how far in
  /// the future it starts) makes an infrequent service that won't leave
  /// for hours look deceptively as fast as something you could start
  /// walking on right now. [waitBeforeDeparture] and
  /// [totalElapsedFromSearch] below exist to make that comparison fair.
  final DateTime searchDepartAt;

  /// Qualitative badges such as "Low Carbon", "Cost Effective", "On Time".
  final List<String> tags;

  /// Whether this option came from the live HERE API (true) or from the
  /// offline mock/cache fallback (false). Surfaced in the UI as a small
  /// "Live" / "Demo data" hint.
  final bool isLiveData;

  /// The real road/rail geometry for this route, decoded from HERE's
  /// response - empty for offline/mock options (there's no real geometry
  /// to follow for a fabricated demo trip) or if decoding the live
  /// response's polyline failed. The navigation map falls back to a
  /// straight line between the origin and destination whenever this is
  /// empty.
  final List<LocationPoint> path;

  DateTime get departTime => legs.first.start;

  DateTime get arriveTime => legs.last.end;

  Duration get totalDuration => arriveTime.difference(departTime);

  /// How long after the search was actually made this option's own
  /// itinerary starts. Zero for the normal case (this option's first leg
  /// starts at or before the search time); positive only for a real
  /// scheduled service whose next real departure is genuinely later than
  /// "now" - e.g. an infrequent bus route searched outside its busy hours.
  Duration get waitBeforeDeparture {
    final diff = departTime.difference(searchDepartAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// The fair, apples-to-apples number for comparing options against each
  /// other: total time from when the search was actually made until
  /// arrival, wait-for-the-next-departure included - not just the ride
  /// itself. This is what ranking/sorting and the UI's duration display
  /// should use instead of [totalDuration] alone, which can make an
  /// infrequent service that won't leave for hours look deceptively
  /// competitive with an option you could start on right now.
  Duration get totalElapsedFromSearch => arriveTime.difference(searchDepartAt);

  int get transferCount => legs.where((leg) => leg.isTransfer).length;

  String get co2Level {
    if (co2Kg <= 0.2) return 'Very Low';
    if (co2Kg <= 0.6) return 'Low';
    if (co2Kg <= 1.5) return 'Medium';
    return 'High';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'legs': legs.map((leg) => leg.toJson()).toList(),
    'estCostRm': estCostRm,
    'co2Kg': co2Kg,
    'tags': tags,
    'isLiveData': isLiveData,
    'path': path.map((p) => p.toJson()).toList(),
    'searchDepartAt': searchDepartAt.toIso8601String(),
  };

  factory RideOption.fromJson(Map<String, dynamic> json) {
    final legs = (json['legs'] as List)
        .map((leg) => TripLeg.fromJson(leg as Map<String, dynamic>))
        .toList();
    return RideOption(
      id: json['id'] as String,
      title: json['title'] as String,
      legs: legs,
      estCostRm: (json['estCostRm'] as num).toDouble(),
      co2Kg: (json['co2Kg'] as num).toDouble(),
      tags: (json['tags'] as List).map((t) => t as String).toList(),
      isLiveData: json['isLiveData'] as bool? ?? false,
      path: (json['path'] as List? ?? const [])
          .map((p) => LocationPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      // Falls back to this option's own first-leg start for a cache entry
      // written before this field existed - that just means
      // waitBeforeDeparture reads as zero for that one stale entry, never
      // a crash. New searches (the cache key was bumped alongside this
      // change) always have the real value.
      searchDepartAt: json['searchDepartAt'] != null
          ? DateTime.parse(json['searchDepartAt'] as String)
          : (legs.isNotEmpty ? legs.first.start : DateTime.now()),
    );
  }
}
