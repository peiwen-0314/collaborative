import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge.dart';

class ChallengeService {
  ChallengeService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<List<UserChallenge>> watchCurrentUserChallenges() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(StateError('Please sign in to view challenges.'));
    }

    late final StreamController<List<UserChallenge>> controller;
    QuerySnapshot<Map<String, dynamic>>? challengeSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? summarySnapshot;
    QuerySnapshot<Map<String, dynamic>>? stampSnapshot;
    StreamSubscription? challengeSubscription;
    StreamSubscription? summarySubscription;
    StreamSubscription? stampSubscription;

    void emit() {
      if (challengeSnapshot == null ||
          summarySnapshot == null ||
          stampSnapshot == null ||
          controller.isClosed) {
        return;
      }

      final now = DateTime.now();
      final summary = summarySnapshot!.data() ?? <String, dynamic>{};
      final carbonSaved = (summary['carbonSaved'] as num?)?.toDouble() ?? 0;
      final collectedIds = stampSnapshot!.docs
          .map((doc) => doc.data()['attractionId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final challenges = challengeSnapshot!.docs
          .map(ChallengeDefinition.fromFirestore)
          .where((challenge) {
        if (!challenge.isActive) return false;
        if (challenge.startAt != null && now.isBefore(challenge.startAt!)) {
          return false;
        }
        if (challenge.endAt != null && now.isAfter(challenge.endAt!)) {
          return false;
        }
        return true;
      })
          .map((challenge) {
        double currentValue;
        switch (challenge.challengeType) {
          case 'visit_specific':
            currentValue = challenge.requiredAttractionIds
                .where(collectedIds.contains)
                .length
                .toDouble();
            break;
          case 'carbon_saved':
            currentValue = carbonSaved;
            break;
          case 'visit_count':
          default:
            currentValue = collectedIds.length.toDouble();
            break;
        }
        return UserChallenge(
          definition: challenge,
          currentValue: currentValue,
          isCompleted: currentValue >= challenge.targetValue,
        );
      })
          .toList()
        ..sort((a, b) => a.definition.displayOrder
            .compareTo(b.definition.displayOrder));

      controller.add(challenges);
      for (final challenge in challenges.where((item) => item.isCompleted)) {
        Future<void> _awardChallengeOnce(
            String userId,
            ChallengeDefinition challenge,
            ) async {
          final summaryRef = _firestore.collection('gamification').doc(userId);

          final progressRef = summaryRef
              .collection('challengeProgress')
              .doc(challenge.id);

          final pointTransactionRef =
          summaryRef.collection('pointTransactions').doc();

          await _firestore.runTransaction((transaction) async {
            final existing = await transaction.get(progressRef);

            if (existing.exists && existing.data()?['rewarded'] == true) return;

            transaction.set(progressRef, {
              'challengeId': challenge.id,
              'completedAt': FieldValue.serverTimestamp(),
              'rewarded': true,
              'rewardPoints': challenge.rewardPoints,
              'rewardXp': challenge.rewardXp,
            });

            transaction.update(summaryRef, {
              'totalPoints': FieldValue.increment(challenge.rewardPoints),
              'currentXp': FieldValue.increment(challenge.rewardXp),
              'completedChallenges': FieldValue.increment(1),
            });

            transaction.set(pointTransactionRef, {
              'type': 'challenge',
              'title': 'Challenge Completed',
              'description': challenge.title,
              'points': challenge.rewardPoints,
              'createdAt': FieldValue.serverTimestamp(),
              'referenceId': challenge.id,
            });
          });
        }
      }
    }

    controller = StreamController<List<UserChallenge>>(
      onListen: () {
        challengeSubscription = _firestore
            .collection('challenges')
            .snapshots()
            .listen((snapshot) {
          challengeSnapshot = snapshot;
          emit();
        }, onError: controller.addError);
        summarySubscription = _firestore
            .collection('gamification')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
          summarySnapshot = snapshot;
          emit();
        }, onError: controller.addError);
        stampSubscription = _firestore
            .collection('gamification')
            .doc(user.uid)
            .collection('stamps')
            .snapshots()
            .listen((snapshot) {
          stampSnapshot = snapshot;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await challengeSubscription?.cancel();
        await summarySubscription?.cancel();
        await stampSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _awardChallengeOnce(
      String userId,
      ChallengeDefinition challenge,
      ) async {
    final summaryRef = _firestore.collection('gamification').doc(userId);
    final progressRef = summaryRef
        .collection('challengeProgress')
        .doc(challenge.id);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(progressRef);
      if (existing.exists && existing.data()?['rewarded'] == true) return;

      transaction.set(progressRef, {
        'challengeId': challenge.id,
        'completedAt': FieldValue.serverTimestamp(),
        'rewarded': true,
        'rewardPoints': challenge.rewardPoints,
        'rewardXp': challenge.rewardXp,
      });
      transaction.update(summaryRef, {
        'totalPoints': FieldValue.increment(challenge.rewardPoints),
        'currentXp': FieldValue.increment(challenge.rewardXp),
        'completedChallenges': FieldValue.increment(1),
      });
    });
  }
}
