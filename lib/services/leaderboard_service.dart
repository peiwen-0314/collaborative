import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<LeaderboardEntry>> watchLeaderboard() {
    return _firestore
        .collection('gamification')
        .orderBy('totalPoints', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final entries = <LeaderboardEntry>[];

      for (final doc in snapshot.docs) {
        final gamificationData = doc.data();

        final userDoc =
        await _firestore.collection('users').doc(doc.id).get();

        final userData = userDoc.data();

        final name = userData?['name']?.toString().trim();

        entries.add(
          LeaderboardEntry(
            userId: doc.id,
            name: name != null && name.isNotEmpty
                ? name
                : 'Traveller',
            totalPoints:
            (gamificationData['totalPoints'] as num?)?.toInt() ?? 0,
            level:
            (gamificationData['level'] as num?)?.toInt() ?? 0,
          ),
        );
      }

      return entries;
    });
  }
}