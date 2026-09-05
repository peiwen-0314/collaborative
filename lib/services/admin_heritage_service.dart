import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class AdminHeritageRecord {
  const AdminHeritageRecord({
    required this.attraction,
    required this.status,
    required this.lastUpdated,
  });

  final HeritageAttraction attraction;
  final String status;
  final DateTime? lastUpdated;
}

class AdminHeritageService {
  AdminHeritageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    HeritageFirestoreService? heritageService,
  })  : _firestore =
      firestore ?? FirebaseFirestore.instance,
        _storage =
            storage ?? FirebaseStorage.instance,
        _heritageService =
            heritageService ??
                HeritageFirestoreService(
                  firestore: firestore,
                );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final HeritageFirestoreService
  _heritageService;

  CollectionReference<Map<String, dynamic>>
  get _heritageCollection =>
      _firestore.collection(
        'heritage_attractions',
      );

  CollectionReference<Map<String, dynamic>>
  get _attractionCollection =>
      _firestore.collection(
        'attractions',
      );


  // ============================================================
  // LINKED CULTURAL INFORMATION FORM
  // ============================================================

  Future<Map<String, dynamic>?> getMasterAttraction(
      String attractionId,
      ) async {
    final cleanId = attractionId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    final snapshot =
    await _attractionCollection
        .doc(cleanId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  _findHeritageDocumentByAttractionId(
      String attractionId,
      ) async {
    final cleanId = attractionId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    // First try the same document id because new records created
    // from Attraction Management may use the master Attraction id.
    final sameId =
    await _heritageCollection
        .doc(cleanId)
        .get();

    if (sameId.exists) {
      final linkedId =
          sameId.data()?['attractionId']
              ?.toString()
              .trim() ??
              '';

      if (linkedId.isEmpty ||
          linkedId == cleanId) {
        return sameId;
      }
    }

    // Existing migrated records such as H001-H005 may use a
    // different heritage document id, so resolve by attractionId.
    final query =
    await _heritageCollection
        .where(
      'attractionId',
      isEqualTo: cleanId,
    )
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return query.docs.first;
  }

  Future<Map<String, dynamic>?>
  getHeritageInformationByAttractionId(
      String attractionId,
      ) async {
    final snapshot =
    await _findHeritageDocumentByAttractionId(
      attractionId,
    );

    if (snapshot == null ||
        !snapshot.exists) {
      return null;
    }

    return <String, dynamic>{
      ...?snapshot.data(),
      '_heritageDocumentId':
      snapshot.id,
    };
  }

  Future<String> saveHeritageInformation({
    required String attractionId,
    required Map<String, dynamic> data,
  }) async {
    final cleanAttractionId =
    attractionId.trim();

    if (cleanAttractionId.isEmpty) {
      throw ArgumentError(
        'attractionId is required.',
      );
    }

    final master =
    await _attractionCollection
        .doc(cleanAttractionId)
        .get();

    if (!master.exists) {
      throw StateError(
        'Attraction $cleanAttractionId does not exist.',
      );
    }

    final existing =
    await _findHeritageDocumentByAttractionId(
      cleanAttractionId,
    );

    DocumentReference<Map<String, dynamic>>
    heritageRef;

    bool isNew = false;

    if (existing != null &&
        existing.exists) {
      heritageRef =
          _heritageCollection.doc(
            existing.id,
          );
    } else {
      // Prefer a readable one-to-one id when possible.
      final sameIdRef =
      _heritageCollection.doc(
        cleanAttractionId,
      );

      final sameIdSnapshot =
      await sameIdRef.get();

      if (!sameIdSnapshot.exists) {
        heritageRef = sameIdRef;
      } else {
        heritageRef =
            _heritageCollection.doc(
              await generateNextId(),
            );
      }

      isNew = true;
    }

    final heritageType =
    data['heritageType']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? data['heritageType']
        .toString()
        .trim()
        : 'Heritage Site';

    final cleanedData =
    <String, dynamic>{
      'attractionId':
      cleanAttractionId,
      'schemaVersion': 2,
      'heritageType':
      heritageType,
      'aliases':
      _asStringList(
        data['aliases'],
      ),
      'yearBuilt':
      data['yearBuilt']
          ?.toString()
          .trim() ??
          '',
      'architecturalStyle':
      data['architecturalStyle']
          ?.toString()
          .trim() ??
          '',
      'heritageStatus':
      data['heritageStatus']
          ?.toString()
          .trim() ??
          '',
      'history':
      data['history']
          ?.toString()
          .trim() ??
          '',
      'culturalSignificance':
      data['culturalSignificance']
          ?.toString()
          .trim() ??
          '',
      'bestTime':
      data['bestTime']
          ?.toString()
          .trim() ??
          '',
      'sustainabilityTip':
      data['sustainabilityTip']
          ?.toString()
          .trim() ??
          '',
      'visitorEtiquette':
      data['visitorEtiquette']
          ?.toString()
          .trim() ??
          '',
      'visitorEtiquetteItems':
      _asStringList(
        data[
        'visitorEtiquetteItems'],
      ),
      'conservationGuidelines':
      _asStringList(
        data[
        'conservationGuidelines'],
      ),
      'dressCode':
      _asStringList(
        data['dressCode'],
      ),
      'photographyRestrictions':
      _asStringList(
        data[
        'photographyRestrictions'],
      ),
      'preservationPractices':
      _asStringList(
        data[
        'preservationPractices'],
      ),
      'audioEnglish':
      data['audioEnglish']
          ?.toString()
          .trim() ??
          '',
      'audioMalay':
      data['audioMalay']
          ?.toString()
          .trim() ??
          '',
      'audioChinese':
      data['audioChinese']
          ?.toString()
          .trim() ??
          '',
      'stampImageUrl':
      data['stampImageUrl']
          ?.toString()
          .trim() ??
          '',
      'lastUpdated':
      FieldValue.serverTimestamp(),

      // Enforce final schema: general Attraction information
      // must not be duplicated in heritage_attractions.
      'name': FieldValue.delete(),
      'address': FieldValue.delete(),
      'area': FieldValue.delete(),
      'city': FieldValue.delete(),
      'state': FieldValue.delete(),
      'category': FieldValue.delete(),
      'categoryId': FieldValue.delete(),
      'categoryName': FieldValue.delete(),
      'latitude': FieldValue.delete(),
      'longitude': FieldValue.delete(),
      'imageUrl': FieldValue.delete(),
      'coverImageUrl': FieldValue.delete(),
      'imageUrls': FieldValue.delete(),
      'openingHours': FieldValue.delete(),
      'openingTime': FieldValue.delete(),
      'closingTime': FieldValue.delete(),
      'shortDescription':
      FieldValue.delete(),
      'description': FieldValue.delete(),
      'recommendedTime':
      FieldValue.delete(),
      'recommendedDuration':
      FieldValue.delete(),
      'phoneNumber': FieldValue.delete(),
      'facilities': FieldValue.delete(),
      'highlights': FieldValue.delete(),
      'isFreeEntry': FieldValue.delete(),
      'malaysianAdultFee':
      FieldValue.delete(),
      'malaysianChildFee':
      FieldValue.delete(),
      'malaysianSeniorFee':
      FieldValue.delete(),
      'nonMalaysianAdultFee':
      FieldValue.delete(),
      'nonMalaysianChildFee':
      FieldValue.delete(),
      'nonMalaysianSeniorFee':
      FieldValue.delete(),
      'status': FieldValue.delete(),
    };

    if (isNew) {
      cleanedData['createdAt'] =
          FieldValue.serverTimestamp();
    }

    await heritageRef.set(
      cleanedData,
      SetOptions(merge: true),
    );

    return heritageRef.id;
  }

  Future<void> deleteHeritageByAttractionId(
      String attractionId,
      ) async {
    final snapshot =
    await _findHeritageDocumentByAttractionId(
      attractionId,
    );

    if (snapshot == null ||
        !snapshot.exists) {
      return;
    }

    await snapshot.reference.delete();
  }

  // ============================================================
  // WATCH JOINED ADMIN RECORDS
  // ============================================================

  Stream<List<AdminHeritageRecord>>
  watchHeritagePlaces() {
    return _heritageService
        .watchAttractions()
        .asyncMap(
          (attractions) async {
        final records =
        <AdminHeritageRecord>[];

        for (final attraction
        in attractions) {
          final snapshots =
          await Future.wait([
            _attractionCollection
                .doc(attraction.id)
                .get(),
            _heritageCollection
                .doc(
              attraction
                  .heritageDocumentId,
            )
                .get(),
          ]);

          final attractionData =
              snapshots[0].data() ??
                  <String, dynamic>{};

          final heritageData =
              snapshots[1].data() ??
                  <String, dynamic>{};

          DateTime? lastUpdated;

          final rawUpdated =
              heritageData['lastUpdated'] ??
                  attractionData[
                  'updatedAt'];

          if (rawUpdated is Timestamp) {
            lastUpdated =
                rawUpdated.toDate();
          }

          records.add(
            AdminHeritageRecord(
              attraction:
              attraction,
              status:
              attractionData[
              'status']
                  ?.toString() ??
                  'Active',
              lastUpdated:
              lastUpdated,
            ),
          );
        }

        records.sort(
              (a, b) => a.attraction.name
              .toLowerCase()
              .compareTo(
            b.attraction.name
                .toLowerCase(),
          ),
        );

        return records;
      },
    );
  }

  Future<String> generateNextId() async {
    final snapshot =
    await _heritageCollection.get();

    var highest = 0;

    for (final doc in snapshot.docs) {
      final match =
      RegExp(r'^H(\d+)$')
          .firstMatch(doc.id);

      if (match == null) {
        continue;
      }

      final number =
      int.tryParse(
        match.group(1) ?? '',
      );

      if (number != null &&
          number > highest) {
        highest = number;
      }
    }

    return 'H${(highest + 1).toString().padLeft(3, '0')}';
  }

  Future<String> uploadHeritageImage({
    required String documentId,
    required XFile image,
  }) async {
    final bytes =
    await image.readAsBytes();

    final contentType =
    _contentTypeFromName(
      image.name,
    );

    final imageRef =
    _storage.ref(
      'heritage/$documentId/main_image',
    );

    await imageRef.putData(
      bytes,
      SettableMetadata(
        contentType:
        contentType,
      ),
    );

    return imageRef.getDownloadURL();
  }

  // ============================================================
  // ADD
  //
  // The form can continue sending one map. This service splits it:
  // - GENERAL fields -> attractions
  // - HERITAGE fields -> heritage_attractions
  // ============================================================

  Future<String> addHeritagePlace({
    required Map<String, dynamic> data,
    required XFile image,
  }) async {
    final heritageDocumentId =
    await generateNextId();

    final imageUrl =
    await uploadHeritageImage(
      documentId:
      heritageDocumentId,
      image: image,
    );

    final attractionRef =
    _attractionCollection.doc(
      heritageDocumentId,
    );

    final heritageRef =
    _heritageCollection.doc(
      heritageDocumentId,
    );

    final batch =
    _firestore.batch();

    batch.set(
      attractionRef,
      _buildGeneralAttractionMap(
        data: data,
        imageUrl: imageUrl,
        sourcePlaceId:
        heritageDocumentId,
        isNew: true,
      ),
      SetOptions(merge: true),
    );

    batch.set(
      heritageRef,
      _buildHeritageMap(
        data: data,
        attractionId:
        attractionRef.id,
        isNew: true,
      ),
      SetOptions(merge: true),
    );

    await batch.commit();

    return heritageDocumentId;
  }

  // ============================================================
  // UPDATE
  //
  // IMPORTANT: [heritageDocumentId] is the document ID from
  // heritage_attractions, NOT the master Attraction ID.
  // This matters for Kek Lok Si, whose master Attraction ID is
  // different from H005.
  // ============================================================

  Future<void> updateHeritagePlace({
    String? heritageDocumentId,
    String? id,
    required Map<String, dynamic> data,
    XFile? newImage,
  }) async {
    final cleanHeritageId =
    (heritageDocumentId ?? id ?? '')
        .trim();

    if (cleanHeritageId.isEmpty) {
      throw ArgumentError(
        'heritageDocumentId is required.',
      );
    }

    final heritageSnapshot =
    await _heritageCollection
        .doc(cleanHeritageId)
        .get();

    if (!heritageSnapshot.exists) {
      throw StateError(
        'Heritage record $cleanHeritageId does not exist.',
      );
    }

    final heritageData =
        heritageSnapshot.data() ??
            <String, dynamic>{};

    final attractionId =
    heritageData['attractionId']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? heritageData[
    'attractionId']
        .toString()
        .trim()
        : cleanHeritageId;

    String? imageUrl;

    if (newImage != null) {
      imageUrl =
      await uploadHeritageImage(
        documentId:
        cleanHeritageId,
        image: newImage,
      );
    }

    final batch =
    _firestore.batch();

    batch.set(
      _attractionCollection.doc(
        attractionId,
      ),
      _buildGeneralAttractionMap(
        data: data,
        imageUrl: imageUrl,
        sourcePlaceId:
        cleanHeritageId,
        isNew: false,
      ),
      SetOptions(merge: true),
    );

    batch.set(
      _heritageCollection.doc(
        cleanHeritageId,
      ),
      _buildHeritageMap(
        data: data,
        attractionId:
        attractionId,
        isNew: false,
      ),
      SetOptions(merge: true),
    );

    await batch.commit();
  }


  // ============================================================
  // DELETE
  //
  // Delete only the specialised heritage extension.
  // The master Attraction remains in the general Attractions module.
  // ============================================================

  Future<void> deleteHeritagePlace(
      String heritageDocumentId,
      ) async {
    final cleanHeritageId =
    heritageDocumentId.trim();

    if (cleanHeritageId.isEmpty) {
      return;
    }

    try {
      await _storage
          .ref(
        'heritage/$cleanHeritageId/main_image',
      )
          .delete();
    } on FirebaseException catch (error) {
      if (error.code !=
          'object-not-found') {
        rethrow;
      }
    }

    await _heritageCollection
        .doc(cleanHeritageId)
        .delete();
  }

  // ============================================================
  // SPLIT MAPS
  // ============================================================

  Map<String, dynamic>
  _buildGeneralAttractionMap({
    required Map<String, dynamic> data,
    required String? imageUrl,
    required String sourcePlaceId,
    required bool isNew,
  }) {
    final parsedHours =
    _splitOpeningHours(
      data['openingHours']
          ?.toString() ??
          '',
    );

    final result =
    <String, dynamic>{
      'name':
      data['name']
          ?.toString()
          .trim() ??
          '',
      'area':
      data['city']
          ?.toString()
          .trim() ??
          '',
      'state':
      data['state']
          ?.toString()
          .trim() ??
          '',
      'categoryId':
      HeritageFirestoreService
          .culturalHeritageCategoryId,
      'categoryName':
      HeritageFirestoreService
          .culturalHeritageCategoryName,
      'description':
      data['shortDescription']
          ?.toString()
          .trim() ??
          '',
      'latitude':
      _asDouble(
        data['latitude'],
      ),
      'longitude':
      _asDouble(
        data['longitude'],
      ),
      'openingTime':
      parsedHours.$1,
      'closingTime':
      parsedHours.$2,
      'recommendedDuration':
      _normalizeDuration(
        data['recommendedTime']
            ?.toString() ??
            '',
      ),
      'status':
      data['status']
          ?.toString()
          .trim()
          .isNotEmpty ==
          true
          ? data['status']
          .toString()
          .trim()
          : 'Active',
      'updatedAt':
      FieldValue.serverTimestamp(),
    };

    // Only write these optional general fields when the form
    // actually supplies them. This prevents an edit from erasing
    // richer information already stored in the master Attraction.
    if (data.containsKey('address')) {
      result['address'] =
          data['address']
              ?.toString()
              .trim() ??
              '';
    }

    if (data.containsKey(
      'phoneNumber',
    )) {
      result['phoneNumber'] =
          data['phoneNumber']
              ?.toString()
              .trim() ??
              '';
    }

    if (imageUrl != null &&
        imageUrl.trim().isNotEmpty) {
      result['coverImageUrl'] =
          imageUrl.trim();
      result['imageUrls'] =
      <String>[
        imageUrl.trim(),
      ];
    }

    if (isNew) {
      final heritageType =
      data['heritageType']
          ?.toString()
          .trim()
          .isNotEmpty ==
          true
          ? data['heritageType']
          .toString()
          .trim()
          : data['category']
          ?.toString()
          .trim()
          .isNotEmpty ==
          true
          ? data['category']
          .toString()
          .trim()
          : 'Heritage Site';

      result.addAll({
        'address':
        data['address']
            ?.toString()
            .trim() ??
            '',
        'phoneNumber':
        data['phoneNumber']
            ?.toString()
            .trim() ??
            '',
        'isFreeEntry': true,
        'malaysianAdultFee': 0,
        'malaysianChildFee': 0,
        'malaysianSeniorFee': 0,
        'nonMalaysianAdultFee': 0,
        'nonMalaysianChildFee': 0,
        'nonMalaysianSeniorFee': 0,
        'facilities':
        const <String>[],
        'highlights':
        <String>[heritageType],
        'sourceCategories':
        const <String>[
          'cultural_heritage',
          'heritage',
        ],
        'sourcePlaceId':
        sourcePlaceId,
        'source':
        'EcoTravel Heritage Admin',
        'sourceQualityScore': 0,
        'sourceWebsite': '',
        'createdAt':
        FieldValue.serverTimestamp(),
        'importedAt':
        FieldValue.serverTimestamp(),
      });
    }

    return result;
  }

  Map<String, dynamic>
  _buildHeritageMap({
    required Map<String, dynamic> data,
    required String attractionId,
    required bool isNew,
  }) {
    final heritageType =
    data['heritageType']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? data['heritageType']
        .toString()
        .trim()
        : data['category']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? data['category']
        .toString()
        .trim()
        : 'Heritage Site';

    final result =
    <String, dynamic>{
      'attractionId':
      attractionId,
      'schemaVersion': 2,
      'heritageType':
      heritageType,
      'aliases':
      _asStringList(
        data['aliases'],
      ),
      'history':
      data['history']
          ?.toString()
          .trim() ??
          '',
      'culturalSignificance':
      data['culturalSignificance']
          ?.toString()
          .trim() ??
          '',
      'visitorEtiquette':
      data['visitorEtiquette']
          ?.toString()
          .trim() ??
          '',
      'visitorEtiquetteItems':
      _asStringList(
        data[
        'visitorEtiquetteItems'],
      ),
      'sustainabilityTip':
      data['sustainabilityTip']
          ?.toString()
          .trim() ??
          '',
      'bestTime':
      data['bestTime']
          ?.toString()
          .trim() ??
          '',
      'yearBuilt':
      data['yearBuilt']
          ?.toString()
          .trim() ??
          '',
      'architecturalStyle':
      data['architecturalStyle']
          ?.toString()
          .trim() ??
          '',
      'heritageStatus':
      data['heritageStatus']
          ?.toString()
          .trim() ??
          '',
      'conservationGuidelines':
      _asStringList(
        data[
        'conservationGuidelines'],
      ),
      'dressCode':
      _asStringList(
        data['dressCode'],
      ),
      'photographyRestrictions':
      _asStringList(
        data[
        'photographyRestrictions'],
      ),
      'preservationPractices':
      _asStringList(
        data[
        'preservationPractices'],
      ),
      'audioEnglish':
      data['audioEnglish']
          ?.toString()
          .trim() ??
          '',
      'audioMalay':
      data['audioMalay']
          ?.toString()
          .trim() ??
          '',
      'audioChinese':
      data['audioChinese']
          ?.toString()
          .trim() ??
          '',
      if (data.containsKey(
        'stampImageUrl',
      ))
        'stampImageUrl':
        data['stampImageUrl']
            ?.toString()
            .trim() ??
            '',
      'lastUpdated':
      FieldValue.serverTimestamp(),

      // Remove old duplicate general fields if an old admin form
      // or record still contains them.
      'name':
      FieldValue.delete(),
      'address':
      FieldValue.delete(),
      'area':
      FieldValue.delete(),
      'city':
      FieldValue.delete(),
      'state':
      FieldValue.delete(),
      'category':
      FieldValue.delete(),
      'categoryId':
      FieldValue.delete(),
      'categoryName':
      FieldValue.delete(),
      'latitude':
      FieldValue.delete(),
      'longitude':
      FieldValue.delete(),
      'imageUrl':
      FieldValue.delete(),
      'coverImageUrl':
      FieldValue.delete(),
      'imageUrls':
      FieldValue.delete(),
      'openingHours':
      FieldValue.delete(),
      'openingTime':
      FieldValue.delete(),
      'closingTime':
      FieldValue.delete(),
      'shortDescription':
      FieldValue.delete(),
      'description':
      FieldValue.delete(),
      'recommendedTime':
      FieldValue.delete(),
      'recommendedDuration':
      FieldValue.delete(),
      'phoneNumber':
      FieldValue.delete(),
      'facilities':
      FieldValue.delete(),
      'highlights':
      FieldValue.delete(),
      'isFreeEntry':
      FieldValue.delete(),
      'malaysianAdultFee':
      FieldValue.delete(),
      'malaysianChildFee':
      FieldValue.delete(),
      'malaysianSeniorFee':
      FieldValue.delete(),
      'nonMalaysianAdultFee':
      FieldValue.delete(),
      'nonMalaysianChildFee':
      FieldValue.delete(),
      'nonMalaysianSeniorFee':
      FieldValue.delete(),
      'status':
      FieldValue.delete(),
    };

    if (isNew) {
      result['createdAt'] =
          FieldValue.serverTimestamp();
    }

    return result;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0.0;
  }

  List<String> _asStringList(
      dynamic value,
      ) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map(
          (item) =>
          item.toString().trim(),
    )
        .where(
          (item) => item.isNotEmpty,
    )
        .toList();
  }

  (String, String) _splitOpeningHours(
      String value,
      ) {
    final normalized =
    value
        .trim()
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    if (normalized.isEmpty) {
      return ('', '');
    }

    final parts = normalized
        .split('-')
        .map(
          (item) => item.trim(),
    )
        .where(
          (item) => item.isNotEmpty,
    )
        .toList();

    if (parts.length >= 2) {
      return (
      _normalizeClockTime(
        parts.first,
      ),
      _normalizeClockTime(
        parts.sublist(1).join('-'),
      ),
      );
    }

    return (
    _normalizeClockTime(
      normalized,
    ),
    '',
    );
  }

  String _normalizeClockTime(
      String value,
      ) {
    final clean = value.trim();

    final match =
    RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(clean);

    if (match == null) {
      return clean;
    }

    final hour =
    int.tryParse(
      match.group(1) ?? '',
    );

    final minute =
    int.tryParse(
      match.group(2) ?? '',
    );

    if (hour == null ||
        minute == null) {
      return clean;
    }

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _normalizeDuration(
      String value,
      ) {
    return value
        .trim()
        .replaceAll('–', ' - ')
        .replaceAll('—', ' - ')
        .replaceAll(
      RegExp(r'\s*-\s*'),
      ' - ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  String _contentTypeFromName(
      String fileName,
      ) {
    final name =
    fileName.toLowerCase();

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    if (name.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }
}
