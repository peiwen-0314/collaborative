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

  // ===========================================================
  // WATCH CURRENT USER GAMIFICATION SUMMARY
  // ===========================================================

  Stream<GamificationSummary> watchCurrentUserSummary() async* {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please sign in to view your gamification progress.',
      );
    }

    // =========================================================
    // GET USER NAME
    // =========================================================

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userName =
    userSnapshot.data()?['name']?.toString().trim();

    final resolvedName =
    userName != null && userName.isNotEmpty
        ? userName
        : (user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Traveller');

    final summaryRef =
    _firestore.collection('gamification').doc(user.uid);

    // =========================================================
    // WATCH GAMIFICATION ROOT
    // =========================================================

    yield* summaryRef.snapshots().asyncMap(
          (snapshot) async {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw StateError(
            'Gamification record not found for this account.',
          );
        }

        // =====================================================
        // TREE MIGRATION / CONTINUOUS TREE LOGIC
        // =====================================================
        //
        // Old system:
        // treeGrowth stopped permanently at 1.0.
        //
        // New system:
        // 100% completed tree
        //      ↓
        // next tree starts automatically at 0%.
        //
        // =====================================================

        final rawTreeGrowth =
            (data['treeGrowth'] as num?)?.toDouble() ?? 0.0;

        var currentTreeLevel =
            (data['treeLevel'] as num?)?.toInt() ?? 1;

        if (currentTreeLevel <= 0) {
          currentTreeLevel = 1;
        }

        var migratedTreeGrowth = rawTreeGrowth;
        var migratedTreeLevel = currentTreeLevel;

        if (rawTreeGrowth >= 1.0) {
          final completedTrees = rawTreeGrowth.floor();

          migratedTreeLevel =
              currentTreeLevel + completedTrees;

          migratedTreeGrowth =
              rawTreeGrowth - completedTrees;

          await summaryRef.update({
            'treeLevel': migratedTreeLevel,
            'treeGrowth': migratedTreeGrowth,
            'lastTreeCompletedAt':
            FieldValue.serverTimestamp(),
          });
        } else if (!data.containsKey('treeLevel')) {
          // Existing users who have not completed a tree yet.
          // Add treeLevel without changing their current progress.
          await summaryRef.update({
            'treeLevel': currentTreeLevel,
          });
        }

        // =====================================================
        // USER COLLECTED STAMPS
        // =====================================================

        final stampSnapshot =
        await summaryRef.collection('stamps').get();

        // =====================================================
        // CURRENT AVAILABLE ADMIN STAMPS
        // =====================================================
        //
        // Only heritage attractions with stampImageUrl
        // count as collectible stamps.
        //
        // Both IDs are accepted:
        //
        // - heritage_attractions document ID
        // - attractionId
        //
        // This keeps old collected stamp data compatible.
        //
        // =====================================================

        final heritageSnapshot =
        await _firestore
            .collection('heritage_attractions')
            .get();

        final availableStampIds = <String>{};

        int totalAvailableStamps = 0;

        for (final doc in heritageSnapshot.docs) {
          final heritageData = doc.data();

          final stampImageUrl =
              heritageData['stampImageUrl']
                  ?.toString()
                  .trim() ??
                  '';

          // No image = Admin has not created this stamp.
          if (stampImageUrl.isEmpty) {
            continue;
          }

          // Count this stamp exactly once.
          totalAvailableStamps++;

          // Heritage document ID.
          availableStampIds.add(
            doc.id.trim(),
          );

          // Canonical Attraction ID.
          final attractionId =
              heritageData['attractionId']
                  ?.toString()
                  .trim() ??
                  '';

          if (attractionId.isNotEmpty) {
            availableStampIds.add(
              attractionId,
            );
          }
        }

        // =====================================================
        // VALID COLLECTED STAMPS
        // =====================================================

        final collectedStampKeys = <String>{};

        for (final doc in stampSnapshot.docs) {
          final stampData = doc.data();

          final attractionId =
              stampData['attractionId']
                  ?.toString()
                  .trim() ??
                  '';

          // -----------------------------------------------
          // Normal / new collected stamp
          // -----------------------------------------------

          if (attractionId.isNotEmpty &&
              availableStampIds.contains(
                attractionId,
              )) {
            collectedStampKeys.add(
              doc.id,
            );

            continue;
          }

          // -----------------------------------------------
          // Old collected stamp compatibility
          // -----------------------------------------------

          if (availableStampIds.contains(
            doc.id,
          )) {
            collectedStampKeys.add(
              doc.id,
            );
          }
        }

        final validCollectedStamps =
            collectedStampKeys.length;

        // =====================================================
        // COMPLETED CHALLENGES
        // =====================================================

        final challengeProgressSnapshot =
        await summaryRef
            .collection('challengeProgress')
            .where(
          'rewarded',
          isEqualTo: true,
        )
            .get();

        // =====================================================
        // TOTAL CHALLENGES
        // =====================================================

        final totalChallengeSnapshot =
        await _firestore
            .collection('challenges')
            .get();

        // =====================================================
        // LIVE GAMIFICATION SUMMARY
        // =====================================================

        final liveData = <String, dynamic>{
          ...data,

          'treeLevel':
          migratedTreeLevel,

          'treeGrowth':
          migratedTreeGrowth,

          'collectedStamps':
          validCollectedStamps,

          'totalStamps':
          totalAvailableStamps,

          'completedChallenges':
          challengeProgressSnapshot
              .docs
              .length,

          'totalChallenges':
          totalChallengeSnapshot
              .docs
              .length,
        };

        return GamificationSummary.fromMap(
          liveData,
          userName: resolvedName,
        );
      },
    );
  }

  // ===========================================================
  // PROCESS LEVEL UP
  // ===========================================================

  Future<LevelUpResult?> processPendingLevelUp(
      GamificationSummary summary,
      ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    if (summary.requiredXp <= 0) {
      return null;
    }

    if (summary.currentXp <
        summary.requiredXp) {
      return null;
    }

    // =========================================================
    // CURRENT LEVEL CONFIG
    // =========================================================

    final currentConfig =
    await _firestore
        .collection('level_configs')
        .doc(
      'level_${summary.level}',
    )
        .get();

    if (!currentConfig.exists) {
      return null;
    }

    final currentData =
    currentConfig.data()!;

    final requiredXp =
        (currentData['xpRequired'] as num?)
            ?.toInt() ??
            summary.requiredXp;

    final nextLevel =
        (currentData['nextLevel'] as num?)
            ?.toInt() ??
            summary.level + 1;

    if (requiredXp <= 0) {
      return null;
    }

    if (summary.currentXp <
        requiredXp) {
      return null;
    }

    // =========================================================
    // NEXT LEVEL CONFIG
    // =========================================================

    final nextConfig =
    await _firestore
        .collection('level_configs')
        .doc(
      'level_$nextLevel',
    )
        .get();

    if (!nextConfig.exists) {
      return null;
    }

    final nextData =
    nextConfig.data()!;

    final nextTitle =
        nextData['title']
            ?.toString()
            .trim() ??
            'Eco Champion';

    final nextRequiredXp =
        (nextData['xpRequired'] as num?)
            ?.toInt() ??
            requiredXp;

    final rewardPoints =
        (currentData['rewardPoints'] as num?)
            ?.toInt() ??
            0;

    // =========================================================
    // REFERENCES
    // =========================================================

    final summaryRef =
    _firestore
        .collection('gamification')
        .doc(user.uid);

    final pointTransactionRef =
    summaryRef
        .collection('pointTransactions')
        .doc();

    // =========================================================
    // LEVEL-UP TRANSACTION
    // =========================================================

    return _firestore.runTransaction(
          (transaction) async {
        final latest =
        await transaction.get(
          summaryRef,
        );

        final latestData =
        latest.data();

        if (!latest.exists ||
            latestData == null) {
          return null;
        }

        final latestLevel =
            (latestData['level'] as num?)
                ?.toInt() ??
                0;

        final latestXp =
            (latestData['currentXp'] as num?)
                ?.toInt() ??
                0;

        // Another process may have already handled it.
        if (latestLevel !=
            summary.level ||
            latestXp <
                requiredXp) {
          return null;
        }

        // =====================================================
        // UPDATE SUMMARY
        // =====================================================

        transaction.update(
          summaryRef,
          {
            'level':
            nextLevel,

            'levelTitle':
            nextTitle,

            'currentXp':
            latestXp -
                requiredXp,

            'requiredXp':
            nextRequiredXp,

            'totalPoints':
            FieldValue.increment(
              rewardPoints,
            ),

            'lastLevelUpAt':
            FieldValue.serverTimestamp(),
          },
        );

        // =====================================================
        // LEVEL UP POINT HISTORY
        // =====================================================

        if (rewardPoints > 0) {
          transaction.set(
            pointTransactionRef,
            {
              'type':
              'level_up',

              'title':
              'Level Up Reward',

              'description':
              'Reached Level $nextLevel - $nextTitle',

              'points':
              rewardPoints,

              'createdAt':
              FieldValue.serverTimestamp(),

              'referenceId':
              'level_$nextLevel',
            },
          );
        }

        return LevelUpResult(
          previousLevel:
          summary.level,

          newLevel:
          nextLevel,

          newTitle:
          nextTitle,

          rewardPoints:
          rewardPoints,
        );
      },
    );
  }
}