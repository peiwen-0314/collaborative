import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_trip.dart';

/// On-device persistence for the "Saved List" feature, backed by
/// [SharedPreferences] so saved trips survive an app restart.
class SavedTripsStore {
  SavedTripsStore._internal();

  static final SavedTripsStore instance = SavedTripsStore._internal();

  static const _prefsKey = 'saved_trips_v1';

  Future<List<SavedTrip>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    final trips = <SavedTrip>[];
    for (final entry in raw) {
      try {
        trips.add(SavedTrip.fromJson(jsonDecode(entry) as Map<String, dynamic>));
      } catch (_) {
        // Skip anything that fails to decode (e.g. from a future app
        // version's saved-trip shape) instead of crashing the list.
      }
    }
    trips.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return trips;
  }

  Future<bool> isSaved(String id) async {
    final all = await getAll();
    return all.any((trip) => trip.id == id);
  }

  Future<void> save(SavedTrip trip) async {
    final all = await getAll();
    all.removeWhere((existing) => existing.id == trip.id);
    all.add(trip);
    await _writeAll(all);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((existing) => existing.id == id);
    await _writeAll(all);
  }

  /// Flips the saved state of [trip]. Returns the new state (`true` if it
  /// is now saved, `false` if it was just removed).
  Future<bool> toggle(SavedTrip trip) async {
    final alreadySaved = await isSaved(trip.id);
    if (alreadySaved) {
      await remove(trip.id);
      return false;
    }
    await save(trip);
    return true;
  }

  Future<void> _writeAll(List<SavedTrip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      trips.map((trip) => jsonEncode(trip.toJson())).toList(),
    );
  }
}
