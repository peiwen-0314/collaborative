import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_option.dart';

enum RoutePriority { balanced, eco, cost, speed }

/// Display strings for [RoutePriority] - kept next to the enum itself
/// rather than scattered across whichever widget happens to render it.
extension RoutePriorityLabel on RoutePriority {
  String get label {
    switch (this) {
      case RoutePriority.balanced:
        return 'Balanced';
      case RoutePriority.eco:
        return 'Eco-first';
      case RoutePriority.cost:
        return 'Cost-first';
      case RoutePriority.speed:
        return 'Speed-first';
    }
  }

  String get description {
    switch (this) {
      case RoutePriority.balanced:
        return "Use the AI model's own trained ranking as-is.";
      case RoutePriority.eco:
        return 'Favour the lowest-CO2 option more strongly.';
      case RoutePriority.cost:
        return 'Favour the cheapest option more strongly.';
      case RoutePriority.speed:
        return 'Favour the fastest option more strongly.';
    }
  }
}

class TravelPreferences {
  const TravelPreferences({
    this.priority = RoutePriority.balanced,
    this.budgetCapRm,
    this.maxDurationMinutes,
  });

  final RoutePriority priority;

  final double? budgetCapRm;

  final int? maxDurationMinutes;
}

class PreferenceWeights {
  const PreferenceWeights({
    this.durationWeight = 1.0,
    this.costWeight = 1.0,
    this.co2Weight = 1.0,
    this.transfersWeight = 1.0,
  });

  final double durationWeight;
  final double costWeight;
  final double co2Weight;
  final double transfersWeight;
}

class TravelPreferencesService {
  TravelPreferencesService._internal();

  static final TravelPreferencesService instance =
      TravelPreferencesService._internal();

  static const _priorityKey = 'travel_prefs_priority_v1';
  static const _budgetKey = 'travel_prefs_budget_cap_rm_v1';
  static const _maxDurationKey = 'travel_prefs_max_duration_minutes_v1';
  static const _behaviorKey = 'travel_prefs_behavior_counts_v1';

  Future<TravelPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final priorityName = prefs.getString(_priorityKey);
      final priority = RoutePriority.values.firstWhere(
        (value) => value.name == priorityName,
        orElse: () => RoutePriority.balanced,
      );
      final budgetCapRm = prefs.getDouble(_budgetKey);
      final maxDurationMinutes = prefs.getInt(_maxDurationKey);
      return TravelPreferences(
        priority: priority,
        budgetCapRm: budgetCapRm,
        maxDurationMinutes: maxDurationMinutes,
      );
    } catch (error) {
      debugPrint('[TravelPreferencesService] load failed: $error');
      return const TravelPreferences();
    }
  }

  Future<void> save(TravelPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_priorityKey, preferences.priority.name);
      final budgetCapRm = preferences.budgetCapRm;
      if (budgetCapRm == null) {
        await prefs.remove(_budgetKey);
      } else {
        await prefs.setDouble(_budgetKey, budgetCapRm);
      }
      final maxDurationMinutes = preferences.maxDurationMinutes;
      if (maxDurationMinutes == null) {
        await prefs.remove(_maxDurationKey);
      } else {
        await prefs.setInt(_maxDurationKey, maxDurationMinutes);
      }
    } catch (error) {
      debugPrint('[TravelPreferencesService] save failed: $error');
    }
  }

  Future<void> recordSelection(
    RideOption selected,
    List<RideOption> searchResults,
  ) async {
    // Nothing to reveal a preference against with 0-1 options.
    if (searchResults.length <= 1) return;
    try {
      final cheapest = _minBy(searchResults, (o) => o.estCostRm);
      final fastest = _minBy(
        searchResults,
        (o) => o.totalElapsedFromSearch.inMinutes.toDouble(),
      );
      final greenest = _minBy(searchResults, (o) => o.co2Kg);

      final String label;
      if (selected.id == cheapest.id) {
        label = 'cheapest';
      } else if (selected.id == fastest.id) {
        label = 'fastest';
      } else if (selected.id == greenest.id) {
        label = 'greenest';
      } else {
        label = 'other';
      }

      final prefs = await SharedPreferences.getInstance();
      final counts = _decodeCounts(prefs.getString(_behaviorKey));
      counts[label] = (counts[label] ?? 0) + 1;
      await prefs.setString(_behaviorKey, jsonEncode(counts));
    } catch (error) {
      debugPrint('[TravelPreferencesService] recordSelection failed: $error');
    }
  }

  RideOption _minBy(
    List<RideOption> options,
    double Function(RideOption) key,
  ) {
    var best = options.first;
    var bestValue = key(best);
    for (final option in options.skip(1)) {
      final value = key(option);
      if (value < bestValue) {
        best = option;
        bestValue = value;
      }
    }
    return best;
  }

  Map<String, int> _decodeCounts(String? raw) {
    if (raw == null) return <String, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  static const _minSelectionsForNudge = 5;

  static const _maxBehaviorNudge = 0.3;

  Future<PreferenceWeights> weightsFor(TravelPreferences preferences) async {
    var durationWeight = 1.0;
    var costWeight = 1.0;
    var co2Weight = 1.0;
    var transfersWeight = 1.0;

    const boost = 4.5;
    const damp = 0.25;
    switch (preferences.priority) {
      case RoutePriority.balanced:
        break;
      case RoutePriority.eco:
        co2Weight = boost;
        durationWeight = damp;
        costWeight = damp;
        transfersWeight = damp;
        break;
      case RoutePriority.cost:
        costWeight = boost;
        durationWeight = damp;
        co2Weight = damp;
        transfersWeight = damp;
        break;
      case RoutePriority.speed:
        durationWeight = boost;
        costWeight = damp;
        co2Weight = damp;
        transfersWeight = damp;
        break;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = _decodeCounts(prefs.getString(_behaviorKey));
      final total = counts.values.fold<int>(0, (sum, n) => sum + n);
      if (total >= _minSelectionsForNudge) {
        final cheapestShare = (counts['cheapest'] ?? 0) / total;
        final fastestShare = (counts['fastest'] ?? 0) / total;
        final greenestShare = (counts['greenest'] ?? 0) / total;
        costWeight += costWeight * (cheapestShare * _maxBehaviorNudge);
        durationWeight += durationWeight * (fastestShare * _maxBehaviorNudge);
        co2Weight += co2Weight * (greenestShare * _maxBehaviorNudge);
      }
    } catch (error) {
      debugPrint(
        '[TravelPreferencesService] weightsFor behavior nudge failed: $error',
      );
    }

    return PreferenceWeights(
      durationWeight: durationWeight,
      costWeight: costWeight,
      co2Weight: co2Weight,
      transfersWeight: transfersWeight,
    );
  }
}
