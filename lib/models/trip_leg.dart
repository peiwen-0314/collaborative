import 'location_point.dart';
import 'transport_mode.dart';

/// One segment of a journey timeline, e.g. "KTM Komuter (Rawang -> KL
/// Sentral)" or a transfer/wait between two vehicles.
class TripLeg {
  const TripLeg({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    this.isTransfer = false,
    this.distanceKm,
    this.startPoint,
    this.endPoint,
  });

  final TransportMode mode;
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final bool isTransfer;

  /// This leg's real distance in km, when it's known - set from HERE's
  /// own `travelSummary.length` for a leg that came from a live API
  /// response, left null for a leg the offline/calculated generator built
  /// (see MockTransportRepository), which has no real distance to report,
  /// only an estimate baked into the whole option's totals. Exists so
  /// TransportService can splice together new combination options out of
  /// real single-mode legs (e.g. a real "Bus" leg + the real "Taxi" leg)
  /// using each leg's own real distance for its cost/CO2 share, instead of
  /// re-deriving distance from an assumed speed constant.
  final double? distanceKm;

  /// Real section endpoints when the provider returned them. These let the
  /// native navigator guide a road-capable first/last mile without pretending
  /// that a bus or train section is a drivable route.
  final LocationPoint? startPoint;
  final LocationPoint? endPoint;

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'title': title,
    'subtitle': subtitle,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'isTransfer': isTransfer,
    'distanceKm': distanceKm,
    'startPoint': startPoint?.toJson(),
    'endPoint': endPoint?.toJson(),
  };

  factory TripLeg.fromJson(Map<String, dynamic> json) => TripLeg(
    mode: TransportMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => TransportMode.other,
    ),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    isTransfer: json['isTransfer'] as bool? ?? false,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    startPoint: json['startPoint'] is Map<String, dynamic>
        ? LocationPoint.fromJson(json['startPoint'] as Map<String, dynamic>)
        : null,
    endPoint: json['endPoint'] is Map<String, dynamic>
        ? LocationPoint.fromJson(json['endPoint'] as Map<String, dynamic>)
        : null,
  );
}
