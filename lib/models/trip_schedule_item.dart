import 'attraction.dart';

class TripScheduleItem {
  final AttractionModel attraction;
  final int dayIndex;
  final DateTime startTime;
  final DateTime endTime;

  /// Visit duration is based on the attraction's recommendedDuration.
  /// It is a scheduling reference, not a guarantee of how long a real
  /// traveler will stay.
  final int visitMinutes;

  /// Travel time from the previous attraction.
  final int transportMinutesBefore;

  /// Road distance from the previous attraction.
  final double distanceFromPreviousKm;

  /// True when HERE Routing successfully supplied the route.
  /// False means the controller had to use a local distance fallback.
  final bool usedHereRouting;

  final double estimatedFee;
  final double recommendationScore;

  const TripScheduleItem({
    required this.attraction,
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.visitMinutes,
    required this.transportMinutesBefore,
    required this.distanceFromPreviousKm,
    required this.usedHereRouting,
    required this.estimatedFee,
    required this.recommendationScore,
  });

  int get dayNumber => dayIndex + 1;

  Duration get visitDuration =>
      Duration(minutes: visitMinutes);

  Duration get transportDuration =>
      Duration(minutes: transportMinutesBefore);
}
