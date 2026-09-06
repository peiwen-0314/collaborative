import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud persistence for a whole saved trip plan's planned transportation
/// - the result TransportController.planTransportationForPlan computes,
/// once the person actually saves it (see PlanTransportPage's Save
/// action, the only writer). Storing it (instead of only ever
/// recomputing it live) is what lets:
///  - PlanTransportPage reopen a plan without re-running every search.
///  - TripPlansPage show which plans already have their transportation
///    planned vs. which still need it (see plannedPlanIds).
///  - RideHomePage tell the person about the ride they already planned
///    for today instead of re-suggesting a plan they've already handled
///    (see TransportController.todaysTransportStatus).
///
/// Lives at `users/{uid}/planned_trip_transport/{planId}` - the same
/// per-user shape SavedTripsStore already uses for the "Saved List"
/// feature, keyed by the `saved_trip_plans` document id so there's
/// exactly one transport plan per trip plan.
///
/// Deliberately stores/returns plain JSON maps, not
/// TransportController's own PlannedPlanLeg class - this file has no
/// model imports at all, so there's no import-direction question
/// between a service and the controller that owns that class. The
/// controller (which already knows both) converts to/from
/// PlannedPlanLeg on its own side - see
/// TransportController.getSavedTransportPlan/saveTransportPlan.
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

  /// Which of [planIds] already have a saved transport plan - one query
  /// for the whole subcollection instead of one read per plan, used by
  /// TripPlansPage to badge its list.
  Future<Set<String>> plannedPlanIds(Iterable<String> planIds) async {
    final ids = planIds.toSet();
    if (ids.isEmpty) return {};
    final snapshot = await _collection().get();
    return snapshot.docs.map((doc) => doc.id).where(ids.contains).toSet();
  }
}
