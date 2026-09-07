import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlannedTripTransportStore {
  PlannedTripTransportStore._internal();

  static final PlannedTripTransportStore instance =
      PlannedTripTransportStore._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        "Please log in to save a trip's transportation plan.",
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('planned_trip_transport');
  }

  /// The saved legs for [planId], or null if nothing's been saved for it
  /// yet.
  Future<List<Map<String, dynamic>>?> get(String planId) async {
    final doc = await _collection().doc(planId).get();
    final data = doc.data();
    if (data == null) return null;
    final rawLegs = data['legs'];
    if (rawLegs is! List) return null;
    return rawLegs
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  Future<void> save(String planId, List<Map<String, dynamic>> legs) async {
    await _collection().doc(planId).set({
      'planId': planId,
      'savedAt': FieldValue.serverTimestamp(),
      'legs': legs,
    });
  }

  Future<void> remove(String planId) async {
    await _collection().doc(planId).delete();
  }

  Future<Set<String>> plannedPlanIds(Iterable<String> planIds) async {
    final ids = planIds.toSet();
    if (ids.isEmpty) return {};
    final snapshot = await _collection().get();
    return snapshot.docs.map((doc) => doc.id).where(ids.contains).toSet();
  }
}
