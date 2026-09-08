import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gamification_summary.dart';

class LevelUpResult {
  const LevelUpResult({
    required this.previousLevel,
    required this.newLevel,
    required this.newTitle,
    required this.rewardPoints,
  });

  final int previousLevel;
  final int newLevel;
  final String newTitle;
  final int rewardPoints;
}

class GamificationService {
  GamificationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<GamificationSummary> watchCurrentUserSummary() async* {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to view your gamification progress.');
    }

    final userSnapshot = await _firestore.collection('users').doc(user.uid).get();
    final userName = userSnapshot.data()?['name']?.toString().trim();
    final resolvedName = userName != null && userName.isNotEmpty
        ? userName
        : (user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Traveller');

    yield* _firestore
        .collection('gamification')
        .doc(user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Gamification record not found for this account.');
      }

      final summaryRef =
      _firestore.collection('gamification').doc(user.uid);
      final stampSnapshot = await summaryRef.collection('stamps').get();
      final challengeProgressSnapshot = await summaryRef
          .collection('challengeProgress')
          .where('rewarded', isEqualTo: true)
          .get();
      final totalStampSnapshot =
      await _firestore.collection('heritage_attractions').get();
      final totalChallengeSnapshot =
      await _firestore.collection('challenges').get();

      final liveData = <String, dynamic>{
        ...data,
        'collectedStamps': stampSnapshot.docs.length,
        'totalStamps': totalStampSnapshot.docs.length,
        'completedChallenges': challengeProgressSnapshot.docs.length,
        'totalChallenges': totalChallengeSnapshot.docs.length,
      };
      return GamificationSummary.fromMap(liveData, userName: resolvedName);
    });
  }

  Future<LevelUpResult?> processPendingLevelUp(
      GamificationSummary summary,
      ) async {
    final user = _auth.currentUser;
    if (user == null || summary.requiredXp <= 0) return null;
    if (summary.currentXp < summary.requiredXp) return null;

    final currentConfig = await _firestore
        .collection('level_configs')
        .doc('level_${summary.level}')
        .get();
    if (!currentConfig.exists) return null;

    final currentData = currentConfig.data()!;
    final requiredXp =
        (currentData['xpRequired'] as num?)?.toInt() ?? summary.requiredXp;
    final nextLevel =
        (currentData['nextLevel'] as num?)?.toInt() ?? summary.level + 1;
    if (requiredXp <= 0 || summary.currentXp < requiredXp) return null;

    final nextConfig = await _firestore
        .collection('level_configs')
        .doc('level_$nextLevel')
        .get();
    if (!nextConfig.exists) return null;

    final nextData = nextConfig.data()!;
    final nextTitle =
        nextData['title']?.toString().trim() ?? 'Eco Champion';
    final nextRequiredXp =
        (nextData['xpRequired'] as num?)?.toInt() ?? requiredXp;
    final rewardPoints =
        (currentData['rewardPoints'] as num?)?.toInt() ?? 0;
    final summaryRef = _firestore.collection('gamification').doc(user.uid);
    final pointTransactionRef =
    summaryRef.collection('pointTransactions').doc();

    return _firestore.runTransaction((transaction) async {
      final latest = await transaction.get(summaryRef);
      final data = latest.data();
      if (!latest.exists || data == null) return null;

      final latestLevel = (data['level'] as num?)?.toInt() ?? 0;
      final latestXp = (data['currentXp'] as num?)?.toInt() ?? 0;
      if (latestLevel != summary.level || latestXp < requiredXp) return null;

      transaction.update(summaryRef, {
        'level': nextLevel,
        'levelTitle': nextTitle,
        'currentXp': latestXp - requiredXp,
        'requiredXp': nextRequiredXp,
        'totalPoints': FieldValue.increment(rewardPoints),
        'lastLevelUpAt': FieldValue.serverTimestamp(),
      });
      if (rewardPoints > 0) {
        transaction.set(pointTransactionRef, {
          'type': 'level_up',
          'title': 'Level Up Reward',
          'description': 'Reached Level $nextLevel - $nextTitle',
          'points': rewardPoints,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': 'level_$nextLevel',
        });
      }

      return LevelUpResult(
        previousLevel: summary.level,
        newLevel: nextLevel,
        newTitle: nextTitle,
        rewardPoints: rewardPoints,
      );
    });
  }
}
