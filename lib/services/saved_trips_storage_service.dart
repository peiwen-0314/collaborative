import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_trip.dart';

class SavedTripsStore {
  SavedTripsStore._internal();

  static final SavedTripsStore instance = SavedTripsStore._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'No signed-in Firebase user - saved trips need someone logged '
        'in first. Make sure a user is signed in (via the real login '
        "flow, or main.dart's temporary dev sign-in) before this screen "
        'is reached.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_trips');
  }

  String _docId(String tripId) => tripId.replaceAll('/', '-');

  Future<List<SavedTrip>> getAll() async {
    final snapshot = await _collection().get();
    final trips = <SavedTrip>[];
    for (final doc in snapshot.docs) {
      try {
        trips.add(SavedTrip.fromJson(doc.data()));
      } catch (_) {
        // Skip anything that fails to decode (e.g. from a future app
        // version's saved-trip shape) instead of crashing the list.
      }
    }
    trips.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return trips;
  }

  Future<bool> isSaved(String id) async {
    final doc = await _collection().doc(_docId(id)).get();
    return doc.exists;
  }

  Future<void> save(SavedTrip trip) async {
    final docRef = _collection().doc(_docId(trip.id));
    await docRef.set(trip.toJson());
    debugPrint('[SavedTripsStore] saved to ${docRef.path}');
  }

  Future<void> remove(String id) async {
    await _collection().doc(_docId(id)).delete();
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
}
