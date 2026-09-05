import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/heritage_data.dart';
import 'heritage_firestore_service.dart';

class HeritageContentSeedService {
  HeritageContentSeedService({
    FirebaseFirestore? firestore,
  })  : _firestore =
      firestore ?? FirebaseFirestore.instance,
        _heritageService =
        HeritageFirestoreService(
          firestore: firestore,
        );

  final FirebaseFirestore _firestore;
  final HeritageFirestoreService
  _heritageService;

  Future<int> uploadStarterContent() async {
    final heritageCollection =
    _firestore.collection(
      'heritage_attractions',
    );

    final attractionSnapshot =
    await _firestore
        .collection('attractions')
        .get();

    final attractionIdByName =
    <String, String>{};

    for (final doc
    in attractionSnapshot.docs) {
      final name = _normalize(
        doc.data()['name']
            ?.toString() ??
            '',
      );

      if (name.isNotEmpty) {
        attractionIdByName.putIfAbsent(
          name,
              () => doc.id,
        );
      }
    }

    final batch =
    _firestore.batch();

    for (final attraction
    in HeritageData.attractions) {
      final heritageRef =
      heritageCollection.doc(
        attraction.id,
      );

      final existing =
      await heritageRef.get();

      final existingAttractionId =
          existing.data()?['attractionId']
              ?.toString()
              .trim() ??
              '';

      final matchedAttractionId =
      attractionIdByName[
      _normalize(
        attraction.name,
      )];

      final resolvedAttractionId =
      existingAttractionId.isNotEmpty
          ? existingAttractionId
          : matchedAttractionId ??
          attraction.id;

      final heritageMap =
      Map<String, dynamic>.from(
        attraction.toSeedMap(),
      );

      // Never trust the static H001-H005 id as the master
      // Attraction id. Kek Lok Si, for example, is linked to
      // a pre-existing auto-generated Attraction document.
      heritageMap['attractionId'] =
          resolvedAttractionId;
      heritageMap['heritageType'] =
          attraction.heritageType;
      heritageMap['schemaVersion'] = 2;
      heritageMap['lastUpdated'] =
          FieldValue.serverTimestamp();

      batch.set(
        heritageRef,
        heritageMap,
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Ensure missing master records are created/repaired and
    // duplicate general fields are cleaned if necessary.
    await _heritageService
        .finalizeHeritageStructure();

    return HeritageData.attractions.length;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }
}
