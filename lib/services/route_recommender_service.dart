import '../models/ride_option.dart';

/// Ranks a set of already-fetched [RideOption]s - regardless of whether
/// they came from the live HERE API, the OSM bike-share lookup, or the
/// offline mock generator, this doesn't care - by a *learned* notion of
/// "best", instead of just keeping whatever order the data source happened
/// to return them in.
///
/// The four weights below aren't hand-picked. They're the coefficients of
/// a small pairwise logistic regression model, trained with scikit-learn
/// on synthetic simulated-traveler preference data - see
/// `train_route_recommender.py` at the project root for the full training
/// methodology, why the training data is synthetic (this is a brand-new
/// app with no real "which option did the user actually tap" history yet
/// to train on), and the model's train/test accuracy. That script is the
/// *training* step; this class is just the trained model's forward pass,
/// hardcoded as plain arithmetic - small enough (4 numbers) that shipping
/// it needs zero ML runtime or extra Flutter plugin dependency.
///
/// Retraining/upgrading later: once the app has real usage logs, swap the
/// synthetic dataset in that Python script for real interaction data and
/// rerun it - only the four constants below would need to change, nothing
/// about how this class works.
class RouteRecommender {
  const RouteRecommender._();

  // Feature order: [duration, cost, co2, transfers]. Every coefficient
  // came out negative during training, which makes sense given how the
  // inputs are defined: each one is a "badness" score, normalised 0 (the
  // best option in this specific search's results) to 1 (the worst) - so
  // a bigger badness difference should always make an option *less*
  // likely to be preferred, and a negative coefficient captures exactly
  // that relationship. CO2 having the largest magnitude (-2.66, versus
  // -2.26 for duration, -1.35 for cost, -1.11 for transfers) wasn't
  // hand-tuned either - it fell out of training on a persona population
  // deliberately skewed a bit more eco-conscious on average, which is a
  // reasonable assumption for who'd actually use a *green* travel app.
  static const _wDuration = -2.25764211;
  static const _wCost = -1.35093553;
  static const _wCo2 = -2.66143231;
  static const _wTransfers = -1.10584092;

  /// Returns [options] sorted best (most recommended) first. Only
  /// meaningful to call on the results of a single completed search -
  /// every feature is normalised *within this exact list*, never against
  /// some fixed global scale, because a 3km trip's options and a 300km
  /// trip's options aren't remotely comparable in absolute terms.
  static List<RideOption> rank(List<RideOption> options) {
    if (options.length <= 1) return List.of(options);

    // totalElapsedFromSearch, NOT totalDuration: the latter only measures
    // an option's own timeline once it starts, so a real scheduled service
    // that doesn't leave for hours (a bus searched outside its busy
    // period, say) would otherwise score as if it were just as fast as
    // something you could start on immediately. See
    // RideOption.searchDepartAt's doc for the full explanation.
    final durations = [
      for (final o in options) o.totalElapsedFromSearch.inMinutes.toDouble(),
    ];
    final costs = [for (final o in options) o.estCostRm];
    final co2s = [for (final o in options) o.co2Kg];
    final transfers = [for (final o in options) o.transferCount.toDouble()];

    double norm(double value, List<double> all) {
      final lo = all.reduce((a, b) => a < b ? a : b);
      final hi = all.reduce((a, b) => a > b ? a : b);
      // All options tie on this feature - it can't have swung the
      // decision either way, so it contributes a neutral 0.5 rather than
      // a division-by-zero.
      return (hi - lo).abs() < 1e-9 ? 0.5 : (value - lo) / (hi - lo);
    }

    final scored = <MapEntry<RideOption, double>>[
      for (var i = 0; i < options.length; i++)
        MapEntry(
          options[i],
          _wDuration * norm(durations[i], durations) +
              _wCost * norm(costs[i], costs) +
              _wCo2 * norm(co2s[i], co2s) +
              _wTransfers * norm(transfers[i], transfers),
        ),
    ];

    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in scored) entry.key];
  }
}
