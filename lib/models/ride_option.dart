import '../models/location_point.dart';
import 'delay_estimate.dart';
import 'transport_mode.dart';
import 'trip_leg.dart';

/// One selectable route between the current From/To search, e.g.
/// "MRT + Walk" or "Train + Bus + Ferry".
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
    this.delayEstimate,
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

  /// A rough, explicitly-labelled ESTIMATE of a possible bus delay (rain
  /// and/or peak-hour road traffic) - see DelayEstimate's own doc
  /// comment for why this is never presented as live tracking. Null for
  /// an option with no scheduled bus leg, or one where neither risk
  /// factor was present at search time - see
  /// TransportController.searchRides, which is the only place that ever
  /// sets this.
  final DelayEstimate? delayEstimate;

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

  /// How many times this option's rider actually changes vehicles.
  ///
  /// Not simply `legs.where((leg) => leg.isTransfer).length`: that flag
  /// also covers filler "Wait for ..." segments inserted before *each*
  /// real leg (including the very first one - see
  /// MockTransportRepository/HereTransitService), so counting it
  /// directly conflates "waiting for a bus" with "changing buses", and
  /// can even miss a real transfer entirely when the provider didn't
  /// return a walking/interchange leg between two consecutive vehicles
  /// (e.g. a same-stop change - see TripDetailsPage's itinerary, which
  /// shows a synthetic "Change here" marker in that case). This instead
  /// counts the real (non-walk) transit legs and subtracts one: two bus
  /// legs joined by one change of vehicle correctly reads as 1, a
  /// single direct leg as 0.
  int get transferCount {
    final transitLegCount = legs
        .where((leg) => !leg.isTransfer && leg.mode != TransportMode.walk)
        .length;
    return transitLegCount > 0 ? transitLegCount - 1 : 0;
  }

  /// A concrete label for the results list card - keeps [title]'s
  /// generic mode grouping ("Bus", "Bus + Train") exactly as-is, but
  /// appends the real route/service number of each vehicle actually
  /// ridden in parentheses, e.g. "Bus (104 + 101)" - so near-identical
  /// "Bus" options (which used to be indistinguishable on the results
  /// list) are still told apart, without losing the familiar mode word.
  /// Only live options have a real service name per leg (see
  /// HereTransitService._parseRoute's `serviceName`) - the offline/mock
  /// generator has no real bus/train numbers to show, so this falls
  /// back to plain [title] for those, and for any live leg HERE itself
  /// couldn't give a more specific name than the generic mode label.
  String get routeSummary {
    if (!isLiveData) return title;
    final realLabels = <String>[];
    for (final leg in legs) {
      if (leg.isTransfer || leg.mode == TransportMode.walk) continue;
      final label = leg.title.trim();
      if (label.isEmpty || label == leg.mode.label) continue;
      // Some titles already spell out their real numbers themselves
      // (e.g. OsmBikeShareService/TransportService building "Bus (104 +
      // 11) + Shared Bike" directly) - appending them again here would
      // just repeat "(104)" a second time.
      if (title.contains(label)) continue;
      if (realLabels.isEmpty || realLabels.last != label) {
        realLabels.add(label);
      }
    }
    return realLabels.isEmpty ? title : '$title (${realLabels.join(' + ')})';
  }

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
    'delayEstimate': delayEstimate?.toJson(),
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
      delayEstimate: json['delayEstimate'] is Map<String, dynamic>
          ? DelayEstimate.fromJson(json['delayEstimate'] as Map<String, dynamic>)
          : null,
    );
  }
}
