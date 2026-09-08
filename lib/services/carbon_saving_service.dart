import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CarbonSavingService {
  CarbonSavingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const double privateCarCo2PerKm = 0.171;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  double calculateSavedCo2({
    required double distanceKm,
    required double selectedRouteCo2Kg,
  }) {
    final baselineCo2 = distanceKm * privateCarCo2PerKm;
    final saved = baselineCo2 - selectedRouteCo2Kg;

    return saved > 0 ? saved : 0;
  }

  Future<double> recordCarbonSaving({
    required String tripId,
    required double distanceKm,
    required double selectedRouteCo2Kg,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to record carbon savings.');
    }

    final savedCo2 = calculateSavedCo2(
      distanceKm: distanceKm,
      selectedRouteCo2Kg: selectedRouteCo2Kg,
    );

    if (savedCo2 <= 0) return 0;

    final gamificationRef =
    _firestore.collection('gamification').doc(user.uid);

    final carbonRecordRef =
    gamificationRef.collection('carbonSavings').doc(tripId);

    return _firestore.runTransaction((transaction) async {
      final existingRecord = await transaction.get(carbonRecordRef);

      // This trip has already received its CO₂ saving.
      if (existingRecord.exists) {
        return 0.0;
      }

      final gamificationSnapshot =
      await transaction.get(gamificationRef);

      if (!gamificationSnapshot.exists) {
        throw StateError(
          'Gamification record not found for this account.',
        );
      }

      transaction.set(carbonRecordRef, {
        'tripId': tripId,
        'distanceKm': distanceKm,
        'routeCo2Kg': selectedRouteCo2Kg,
        'carbonSavedKg': savedCo2,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(gamificationRef, {
        'carbonSaved': FieldValue.increment(savedCo2),
      });

      return savedCo2;
    });
  }
}