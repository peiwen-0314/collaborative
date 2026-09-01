import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/heritage_attraction.dart';

class HeritageFirestoreService {
  HeritageFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('heritage_attractions');

  Stream<List<HeritageAttraction>> watchAttractions() {
    return _collection.snapshots().map((snapshot) {
      final result = snapshot.docs
          .map((doc) => HeritageAttraction.fromFirestore(doc.id, doc.data()))
          .toList();
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return result;
    });
  }

  Future<List<HeritageAttraction>> getAttractions() async {
    final snapshot = await _collection.get();
    final result = snapshot.docs
        .map((doc) => HeritageAttraction.fromFirestore(doc.id, doc.data()))
        .toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<HeritageAttraction?> getById(String id) async {
    if (id.trim().isEmpty) return null;
    final doc = await _collection.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return HeritageAttraction.fromFirestore(doc.id, data);
  }

  Future<List<HeritageAttraction>> getByIds(List<String> ids) async {
    final result = <HeritageAttraction>[];
    for (final id in ids) {
      final attraction = await getById(id);
      if (attraction != null) result.add(attraction);
    }
    return result;
  }

  Future<HeritageAttraction?> findByVisionCandidates(
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    final attractions = await getAttractions();
    final normalizedCandidates = candidates
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toList();

    for (final attraction in attractions) {
      final possibleNames = <String>[
        attraction.name,
        ...attraction.aliases,
      ].map(_normalize);

      for (final possibleName in possibleNames) {
        for (final candidate in normalizedCandidates) {
          if (candidate == possibleName ||
              candidate.contains(possibleName) ||
              possibleName.contains(candidate)) {
            return attraction;
          }
        }
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
