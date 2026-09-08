import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attraction.dart';

/// Firestore service for saving/removing attractions for the current user.
///
/// Firestore structure:
///
/// users/{uid}/saved_attractions/{attractionId}
///
/// Each document stores a small snapshot of the attraction so the saved list
/// can still show useful information quickly. The Saved Attractions page can
/// still load the latest attraction document from `attractions/{attractionId}`.
class SavedAttractionsService {
  SavedAttractionsService._internal();

  static final SavedAttractionsService instance =
      SavedAttractionsService._internal();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      _auth.currentUser;

  bool get isLoggedIn =>
      currentUser != null;

  // ============================================================
  // COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      _savedCollection() {
    final user = currentUser;

    if (user == null) {
      throw StateError(
        'Please login before saving attractions.',
      );
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_attractions');
  }

  // ============================================================
  // WATCH SAVED IDS
  // ============================================================

  /// Real-time stream used by HomePage so hearts update automatically.
  ///
  /// Example:
  /// {
  ///   "abc123",
  ///   "xyz456",
  /// }
  Stream<Set<String>> watchSavedIds() {
    final user = currentUser;

    if (user == null) {
      return Stream.value(
        <String>{},
      );
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_attractions')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => doc.id,
              )
              .toSet(),
        );
  }

  // ============================================================
  // WATCH SAVED DOCUMENTS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
      watchSavedAttractions() {
    final user = currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_attractions')
        .orderBy(
          'savedAt',
          descending: true,
        )
        .snapshots();
  }

  // ============================================================
  // GET ALL SAVED IDS
  // ============================================================

  Future<Set<String>> getSavedIds() async {
    final user = currentUser;

    if (user == null) {
      return <String>{};
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_attractions')
        .get();

    return snapshot.docs
        .map(
          (doc) => doc.id,
        )
        .toSet();
  }

  // ============================================================
  // CHECK SAVED
  // ============================================================

  Future<bool> isSaved(
    String attractionId,
  ) async {
    final id =
        attractionId.trim();

    if (id.isEmpty) {
      return false;
    }

    final user = currentUser;

    if (user == null) {
      return false;
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_attractions')
        .doc(id)
        .get();

    return document.exists;
  }

  // ============================================================
  // SAVE ATTRACTION
  // ============================================================

  Future<void> save(
    AttractionModel attraction,
  ) async {
    final attractionId =
        attraction.id.trim();

    if (attractionId.isEmpty) {
      throw StateError(
        'Unable to save attraction because attraction ID is empty.',
      );
    }

    final document =
        _savedCollection()
            .doc(attractionId);

    await document.set(
      {
        'attractionId':
            attraction.id,

        'name':
            attraction.name,

        'state':
            attraction.state,

        'area':
            attraction.area,

        // Primary category
        'categoryId':
            attraction.categoryId,

        'categoryName':
            attraction.categoryName,

        // Multiple category tags
        'categoryIds':
            List<String>.from(
          attraction.categoryIds,
        ),

        'categoryNames':
            List<String>.from(
          attraction.categoryNames,
        ),

        'coverImageUrl':
            attraction.coverImageUrl,

        'imageUrls':
            List<String>.from(
          attraction.imageUrls,
        ),

        'latitude':
            attraction.latitude,

        'longitude':
            attraction.longitude,

        'savedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // REMOVE ATTRACTION
  // ============================================================

  Future<void> remove(
    String attractionId,
  ) async {
    final id =
        attractionId.trim();

    if (id.isEmpty) {
      return;
    }

    await _savedCollection()
        .doc(id)
        .delete();
  }

  // ============================================================
  // TOGGLE SAVE
  // ============================================================

  /// Returns:
  /// true  -> attraction is now saved
  /// false -> attraction was removed
  Future<bool> toggle(
    AttractionModel attraction,
  ) async {
    final attractionId =
        attraction.id.trim();

    if (attractionId.isEmpty) {
      throw StateError(
        'Unable to save attraction because attraction ID is empty.',
      );
    }

    final document =
        _savedCollection()
            .doc(attractionId);

    final snapshot =
        await document.get();

    if (snapshot.exists) {
      await document.delete();

      return false;
    }

    await save(
      attraction,
    );

    return true;
  }

  // ============================================================
  // CLEAR ALL SAVED ATTRACTIONS
  // ============================================================

  Future<void> clearAll() async {
    final snapshot =
        await _savedCollection()
            .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch =
        _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(
        doc.reference,
      );
    }

    await batch.commit();
  }
}
