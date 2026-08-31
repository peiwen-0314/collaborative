import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/heritage_data.dart';

class HeritageContentSeedService {
  HeritageContentSeedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> uploadStarterContent() async {
    final collection = _firestore.collection('heritage_attractions');
    final batch = _firestore.batch();

    for (final attraction in HeritageData.attractions) {
      batch.set(
        collection.doc(attraction.id),
        attraction.toSeedMap(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return HeritageData.attractions.length;
  }
}
