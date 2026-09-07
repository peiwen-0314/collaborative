import '../models/ride_option.dart';

class RouteRecommender {
  const RouteRecommender._();

  static const _wDuration = -2.25764211;
  static const _wCost = -1.35093553;
  static const _wCo2 = -2.66143231;
  static const _wTransfers = -1.10584092;

  static List<MapEntry<RideOption, double>> score(
    List<RideOption> options, {
    double durationWeight = 1.0,
    double costWeight = 1.0,
    double co2Weight = 1.0,
    double transfersWeight = 1.0,
  }) {
    if (options.isEmpty) return const [];
    if (options.length == 1) {
      return [MapEntry(options.first, 0.0)];
    }

    final durations = [
      for (final o in options) o.totalElapsedFromSearch.inMinutes.toDouble(),
    ];
    final costs = [for (final o in options) o.estCostRm];
    final co2s = [for (final o in options) o.co2Kg];
    final transfers = [for (final o in options) o.transferCount.toDouble()];

    double norm(double value, List<double> all) {
      final lo = all.reduce((a, b) => a < b ? a : b);
      final hi = all.reduce((a, b) => a > b ? a : b);
      return (hi - lo).abs() < 1e-9 ? 0.5 : (value - lo) / (hi - lo);
    }

    return [
      for (var i = 0; i < options.length; i++)
        MapEntry(
          options[i],
          _wDuration * durationWeight * norm(durations[i], durations) +
              _wCost * costWeight * norm(costs[i], costs) +
              _wCo2 * co2Weight * norm(co2s[i], co2s) +
              _wTransfers * transfersWeight * norm(transfers[i], transfers),
        ),
    ];
  }

  static List<RideOption> rank(
    List<RideOption> options, {
    double durationWeight = 1.0,
    double costWeight = 1.0,
    double co2Weight = 1.0,
    double transfersWeight = 1.0,
  }) {
    if (options.length <= 1) return List.of(options);
    final scored = score(
      options,
      durationWeight: durationWeight,
      costWeight: costWeight,
      co2Weight: co2Weight,
      transfersWeight: transfersWeight,
    );
    final sorted = List<MapEntry<RideOption, double>>.of(scored)
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in sorted) entry.key];
  }
}
