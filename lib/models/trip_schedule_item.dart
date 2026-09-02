import 'attraction.dart';

class TripScheduleItem {
  final AttractionModel attraction;
  final int dayIndex;
  final DateTime startTime;
  final DateTime endTime;
  final int visitMinutes;
  final int transportMinutesBefore;
  final double estimatedFee;
  final double recommendationScore;

  const TripScheduleItem({
    required this.attraction,
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.visitMinutes,
    required this.transportMinutesBefore,
    required this.estimatedFee,
    required this.recommendationScore,
  });
}