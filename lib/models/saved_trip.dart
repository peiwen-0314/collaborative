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
