import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_trip.dart';

/// Cloud persistence for the "Saved List" feature, backed by Firestore so
/// saved trips survive an app restart *and* follow the same person across
/// devices, instead of living only in one device's local storage (the
/// previous SharedPreferences-backed version).
///
/// Saved trips live at `users/{uid}/saved_trips/{tripId}` - one level
/// under the same per-user document the auth module already writes
/// profiles to (see AuthService.register / signInWithGoogle).
///
/// This class only ever reads `FirebaseAuth.instance.currentUser` - it
/// has no local/guest id fallback of its own. That's deliberate: once
/// the app's real login/register flow is wired up as `main.dart`'s
/// `home:`, whoever is logged in there becomes `currentUser` and this
/// file needs zero changes. Until then, `main.dart` signs a temporary
/// dev/test account in on startup (see the TEMP DEV SIGN-IN block there)
/// purely so a real signed-in user exists for screens like this one to
/// use - delete that block later and this still works unmodified.
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

  /// Firestore document IDs can't contain '/'. [SavedTrip.id] is built
  /// from place names, which could (rarely) contain one, so swap it out
  /// rather than risk an invalid-document-reference crash.
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
    // Printed so a "why can't I find it in the Console" check has an
    // exact path to paste into the Firestore Console's search instead
    // of guessing - this only prints once the .set() future above has
    // actually completed without throwing, i.e. Firestore itself
    // accepted the write.
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
