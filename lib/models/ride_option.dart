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

  final DateTime searchDepartAt;

  /// Qualitative badges such as "Low Carbon", "Cost Effective", "On Time".
  final List<String> tags;

  final bool isLiveData;

  final List<LocationPoint> path;

  final DelayEstimate? delayEstimate;

  DateTime get departTime => legs.first.start;

  DateTime get arriveTime => legs.last.end;

  Duration get totalDuration => arriveTime.difference(departTime);

  Duration get waitBeforeDeparture {
    final diff = departTime.difference(searchDepartAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration get totalElapsedFromSearch => arriveTime.difference(searchDepartAt);

  int get transferCount {
    final transitLegCount = legs
        .where((leg) => !leg.isTransfer && leg.mode != TransportMode.walk)
        .length;
    return transitLegCount > 0 ? transitLegCount - 1 : 0;
  }

  String get routeSummary {
    if (!isLiveData || _realModes.length > 1) return title;
    final realLabels = <String>[];
    for (final leg in legs) {
      if (leg.isTransfer || leg.mode == TransportMode.walk) continue;
      final label = leg.title.trim();
      if (label.isEmpty || label == leg.mode.label) continue;
      if (title.contains(label)) continue;
      if (realLabels.isEmpty || realLabels.last != label) {
        realLabels.add(label);
      }
    }
    return realLabels.isEmpty ? title : '$title (${realLabels.join(' + ')})';
  }

  Set<TransportMode> get _realModes => {
    for (final leg in legs)
      if (!leg.isTransfer && leg.mode != TransportMode.walk) leg.mode,
  };

  double? get co2RatePerKm {
    var totalKm = 0.0;
    for (final leg in legs) {
      final km = leg.distanceKm;
      if (km != null) totalKm += km;
    }
    if (totalKm <= 0) return null;
    return co2Kg / totalKm;
  }

  String get co2Level {
    final rate = co2RatePerKm;
    if (rate == null) {
      if (co2Kg <= 0.2) return 'Very Low';
      if (co2Kg <= 0.6) return 'Low';
      if (co2Kg <= 1.5) return 'Medium';
      return 'High';
    }
    if (rate <= 0.03) return 'Very Low';
    if (rate <= 0.07) return 'Low';
    if (rate <= 0.12) return 'Medium';
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
      searchDepartAt: json['searchDepartAt'] != null
          ? DateTime.parse(json['searchDepartAt'] as String)
          : (legs.isNotEmpty ? legs.first.start : DateTime.now()),
      delayEstimate: json['delayEstimate'] is Map<String, dynamic>
          ? DelayEstimate.fromJson(json['delayEstimate'] as Map<String, dynamic>)
          : null,
    );
  }
}
