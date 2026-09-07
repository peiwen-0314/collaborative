import 'transport_mode.dart';
import 'trip_leg.dart';

class DelayEstimate {
  const DelayEstimate({
    required this.minMinutes,
    required this.maxMinutes,
    required this.reasons,
  });

  final int minMinutes;
  final int maxMinutes;

  /// Human-readable reasons behind this estimate, e.g. ['rain', 'peak
  /// hour'] - always non-empty, see [evaluate].
  final List<String> reasons;

  String get rangeLabel => '$minMinutes-$maxMinutes min';

  String get reasonLabel => reasons.join(' + ');

  String get chipLabel => 'Possible Delay ($reasonLabel)';

  static DelayEstimate? evaluate(
    List<TripLeg> legs, {
    required bool isRaining,
  }) {
    final busLegs = legs.where((leg) => leg.mode == TransportMode.bus);
    if (busLegs.isEmpty) return null;

    final isPeakHour = _isPeakHour(busLegs.first.start);
    if (!isRaining && !isPeakHour) return null;

    final both = isRaining && isPeakHour;
    return DelayEstimate(
      minMinutes: both ? 10 : 5,
      maxMinutes: both ? 15 : 10,
      reasons: [
        if (isRaining) 'rain',
        if (isPeakHour) 'peak hour',
      ],
    );
  }

  static bool _isPeakHour(DateTime time) {
    if (time.weekday >= DateTime.saturday) return false;
    final hour = time.hour;
    return (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19);
  }

  Map<String, dynamic> toJson() => {
    'minMinutes': minMinutes,
    'maxMinutes': maxMinutes,
    'reasons': reasons,
  };

  factory DelayEstimate.fromJson(Map<String, dynamic> json) => DelayEstimate(
    minMinutes: (json['minMinutes'] as num).toInt(),
    maxMinutes: (json['maxMinutes'] as num).toInt(),
    reasons: (json['reasons'] as List).map((r) => r as String).toList(),
  );
}
