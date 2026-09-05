import 'transport_mode.dart';
import 'trip_leg.dart';

/// A rough, explicitly-labelled ESTIMATE of how long a scheduled ground
/// transit leg (bus) might run behind its timetable - built from two real
/// signals this app already has: whether it's raining at the search
/// origin (WeatherService - ground traffic slows down in the rain) and
/// whether the option's own first bus leg starts during a weekday peak
/// hour (heavier road traffic). See
/// TransportController.searchRides/_withDelayEstimates, which computes
/// this alongside its existing rain-bike tag, reusing the same rain
/// check instead of asking WeatherService twice.
///
/// This is deliberately NOT presented as live tracking. No public API
/// this module can reach - HERE, Malaysia's official GTFS-Realtime
/// open-data feed, or even Google Maps Platform's own Routes/Directions
/// developer APIs - currently exposes real bus-delay data for Malaysian
/// operators to third-party apps; that data is limited to a private
/// Prasarana/Google partnership behind the consumer Google Maps app.
/// Every place this surfaces (RideCard, TripDetailsPage) says
/// "estimated"/"possible" and only ever shows a range, never a single
/// fake-precise number, so it can't be mistaken for a real live-delay
/// feed.
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

  /// Short chip label for RideCard - kept to a handful of words so it
  /// doesn't reintroduce the "too much text" problem the results list
  /// already had once (see ride_home_page.dart's edit history).
  String get chipLabel => 'Possible Delay ($reasonLabel)';

  /// Builds an estimate from [legs], or null when neither risk factor
  /// applies, or there's no scheduled ground-transit (bus) leg to begin
  /// with - MRT/train run on a dedicated track and aren't in scope, and
  /// walk/bike/taxi have no timetable to run late against.
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

  /// Weekday-only 7-9am / 5-7pm - the two windows road traffic (and so
  /// bus schedules) are most reliably heavier in this module's service
  /// area (Penang/the Klang Valley).
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
