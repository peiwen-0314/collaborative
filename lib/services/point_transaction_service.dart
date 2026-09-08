import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/point_transaction.dart';

class PointTransactionService {
  PointTransactionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<List<PointTransaction>> watchCurrentUserTransactions() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(
        StateError('Please sign in to view your point history.'),
      );
    }

    return _firestore
        .collection('gamification')
        .doc(user.uid)
        .collection('pointTransactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(PointTransaction.fromFirestore)
          .toList(),
    );
  }
}