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

  Stream<List<PassportStamp>> watchRecentStamps({int limit = 3}) {
    return _watchStamps(limit: limit);
  }

  Stream<List<PassportStamp>> watchAllStamps() {
    return _watchStamps();
  }

  Stream<List<PassportStamp>> _watchStamps({int? limit}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError('Please sign in to view your digital passport.'),
      );
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('gamification')
        .doc(user.uid)
        .collection('stamps')
        .orderBy('collectedAt', descending: true);
    if (limit != null) query = query.limit(limit);

    return query.snapshots()
        .asyncMap((snapshot) async {
      final stamps = snapshot.docs
          .map(PassportStamp.fromFirestore)
          .toList();

      return Future.wait(stamps.map((stamp) async {
        if (stamp.attractionId.isEmpty) return stamp;

        final attraction = await _heritageService.getById(stamp.attractionId);
        if (attraction == null) return stamp;

        return stamp.withAttraction(
          name: attraction.name,
          latitude: attraction.latitude,
          longitude: attraction.longitude,
        );
      }));
    });
  }
}
