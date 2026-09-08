import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge.dart';

class UserBadge {
  const UserBadge({
    required this.challenge,
    required this.isUnlocked,
    this.unlockedAt,
  });

  final ChallengeDefinition challenge;
  final bool isUnlocked;
  final DateTime? unlockedAt;
}

class BadgeService {
  BadgeService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<List<UserBadge>> watchCurrentUserBadges() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(
        StateError('Please sign in to view your badges.'),
      );
    }

    return _firestore
        .collection('challenges')
        .orderBy('displayOrder')
        .snapshots()
        .asyncMap((challengeSnapshot) async {
      final progressSnapshot = await _firestore
          .collection('gamification')
          .doc(user.uid)
          .collection('challengeProgress')
          .get();

      final progressMap = {
        for (final doc in progressSnapshot.docs)
          doc.id: doc.data(),
      };

      final badges = <UserBadge>[];

      for (final challengeDoc in challengeSnapshot.docs) {
        final challenge =
        ChallengeDefinition.fromFirestore(challengeDoc);

        // Only show challenges that actually have a badge.
        if (challenge.badgeName.trim().isEmpty) {
          continue;
        }

        final progress = progressMap[challenge.id];

        final isUnlocked =
            progress != null && progress['rewarded'] == true;

        DateTime? unlockedAt;

        final completedAt = progress?['completedAt'];

        if (completedAt is Timestamp) {
          unlockedAt = completedAt.toDate();
        }

        badges.add(
          UserBadge(
            challenge: challenge,
            isUnlocked: isUnlocked,
            unlockedAt: unlockedAt,
          ),
        );
      }

      return badges;
    });
  }
}