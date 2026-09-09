import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/passport_stamp.dart';
import 'heritage_firestore_service.dart';

class PassportService {
  PassportService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    HeritageFirestoreService? heritageService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _heritageService = heritageService ?? HeritageFirestoreService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final HeritageFirestoreService _heritageService;

  // ===========================================================
  // RECENT STAMPS
  // ===========================================================

  Stream<List<PassportStamp>> watchRecentStamps({
    int limit = 3,
  }) {
    return _watchStamps(limit: limit);
  }

  // ===========================================================
  // ALL STAMPS
  // ===========================================================

  Stream<List<PassportStamp>> watchAllStamps() {
    return _watchStamps();
  }

  // ===========================================================
  // INTERNAL STAMP STREAM
  // ===========================================================

  Stream<List<PassportStamp>> _watchStamps({
    int? limit,
  }) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(
        StateError(
          'Please sign in to view your digital passport.',
        ),
      );
    }

    final query = _firestore
        .collection('gamification')
        .doc(user.uid)
        .collection('stamps')
        .orderBy(
      'collectedAt',
      descending: true,
    );

    return query.snapshots().asyncMap(
          (snapshot) async {
        final collectedStamps = snapshot.docs
            .map(PassportStamp.fromFirestore)
            .toList();

        final validStamps = <PassportStamp>[];

        // =====================================================
        // VALIDATE EACH COLLECTED STAMP
        // =====================================================

        for (final stamp in collectedStamps) {
          if (stamp.attractionId.trim().isEmpty) {
            continue;
          }

          final attraction =
          await _heritageService.getById(
            stamp.attractionId,
          );

          // Attraction no longer exists
          if (attraction == null) {
            continue;
          }

          // ===================================================
          // IMPORTANT
          // ===================================================
          // Only attractions that currently have a stamp image
          // configured by Admin are considered valid stamps.
          // ===================================================

          if (attraction.stampImageUrl.trim().isEmpty) {
            continue;
          }

          // ===================================================
          // REFRESH STAMP WITH CURRENT MASTER DATA
          // ===================================================

          final updatedStamp = PassportStamp(
            id: stamp.id,
            attractionId: stamp.attractionId,
            attractionName: attraction.name,
            imageName: stamp.imageName,

            // Always use latest Admin stamp image
            stampImageUrl: attraction.stampImageUrl,

            collectedAt: stamp.collectedAt,
            status: stamp.status,
            latitude: attraction.latitude,
            longitude: attraction.longitude,
          );

          validStamps.add(updatedStamp);
        }

        // =====================================================
        // SORT BY COLLECTION DATE
        // =====================================================

        validStamps.sort(
              (a, b) =>
              b.collectedAt.compareTo(
                a.collectedAt,
              ),
        );

        // =====================================================
        // APPLY LIMIT AFTER FILTERING
        // =====================================================

        if (limit != null &&
            validStamps.length > limit) {
          return validStamps.take(limit).toList();
        }

        return validStamps;
      },
    );
  }
}