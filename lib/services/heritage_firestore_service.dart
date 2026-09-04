import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/heritage_attraction.dart';

class HeritageMigrationResult {
  const HeritageMigrationResult({
    required this.total,
    required this.created,
    required this.linked,
    required this.cleaned,
    required this.skipped,
  });

  final int total;
  final int created;
  final int linked;
  final int cleaned;
  final int skipped;

  @override
  String toString() {
    return 'total=$total, created=$created, linked=$linked, '
        'cleaned=$cleaned, skipped=$skipped';
  }
}

class HeritageFirestoreService {
  HeritageFirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String culturalHeritageCategoryId =
      'S8wzl7nxsXMZ73Zvtuhq';

  static const String culturalHeritageCategoryName =
      'Cultural & Heritage';

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
  // FINAL ONE-TIME STRUCTURE MIGRATION
  //
  // Final structure:
  //
  // attractions/{attractionId}
  //   -> all GENERAL attraction information
  //
  // heritage_attractions/{heritageId}
  //   -> attractionId + HERITAGE-SPECIFIC information only
  //
  // This method is idempotent. It is safe to run again.
  // ============================================================

  Future<HeritageMigrationResult>
  finalizeHeritageStructure() async {
    final snapshots = await Future.wait([
      _heritageCollection.get(),
      _attractionCollection.get(),
    ]);

    final heritageSnapshot = snapshots[0];
    final attractionSnapshot = snapshots[1];

    final attractionById =
    <String, Map<String, dynamic>>{};
    final attractionIdByName =
    <String, String>{};

    for (final doc in attractionSnapshot.docs) {
      final data = doc.data();
      attractionById[doc.id] = data;

      final normalizedName = _normalize(
        data['name']?.toString() ?? '',
      );

      if (normalizedName.isNotEmpty) {
        attractionIdByName.putIfAbsent(
          normalizedName,
              () => doc.id,
        );
      }
    }

    int created = 0;
    int linked = 0;
    int cleaned = 0;
    int skipped = 0;

    for (final heritageDoc
    in heritageSnapshot.docs) {
      final heritageData =
      Map<String, dynamic>.from(
        heritageDoc.data(),
      );

      final explicitAttractionId =
      _text(
        heritageData,
        'attractionId',
      );

      String? attractionId;

      // ----------------------------------------------------------
      // 1. Existing explicit relationship
      // ----------------------------------------------------------
      if (explicitAttractionId.isNotEmpty &&
          attractionById.containsKey(
            explicitAttractionId,
          )) {
        attractionId =
            explicitAttractionId;
      }

      // ----------------------------------------------------------
      // 2. Same document ID
      // ----------------------------------------------------------
      if (attractionId == null &&
          attractionById.containsKey(
            heritageDoc.id,
          )) {
        attractionId =
            heritageDoc.id;
      }

      // ----------------------------------------------------------
      // 3. Match by heritage name
      // ----------------------------------------------------------
      final heritageName =
      _text(
        heritageData,
        'name',
      );

      final normalizedHeritageName =
      _normalize(
        heritageName,
      );

      if (attractionId == null &&
          normalizedHeritageName.isNotEmpty) {
        attractionId =
        attractionIdByName[
        normalizedHeritageName];
      }

      // ----------------------------------------------------------
      // 4. Already-cleaned heritage records may no longer contain
      // name. If attractionId is present but the local snapshot was
      // stale, read that exact master record once.
      // ----------------------------------------------------------
      if (attractionId == null &&
          explicitAttractionId.isNotEmpty) {
        final explicitSnapshot =
        await _attractionCollection
            .doc(explicitAttractionId)
            .get();

        if (explicitSnapshot.exists &&
            explicitSnapshot.data() != null) {
          attractionId =
              explicitAttractionId;
          attractionById[
          explicitAttractionId] =
          explicitSnapshot.data()!;
        }
      }

      // ----------------------------------------------------------
      // 5. Create missing master Attraction.
      // ----------------------------------------------------------
      if (attractionId == null) {
        if (heritageName.isEmpty) {
          debugPrint(
            'Heritage migration skipped ${heritageDoc.id}: '
                'no attractionId and no legacy name.',
          );
          skipped++;
          continue;
        }

        DocumentReference<
            Map<String, dynamic>>
        attractionRef =
        _attractionCollection.doc(
          heritageDoc.id,
        );

        final sameIdSnapshot =
        await attractionRef.get();

        if (sameIdSnapshot.exists) {
          final sameIdName =
          _normalize(
            sameIdSnapshot
                .data()?['name']
                ?.toString() ??
                '',
          );

          if (sameIdName.isNotEmpty &&
              sameIdName !=
                  normalizedHeritageName) {
            attractionRef =
                _attractionCollection.doc();
          }
        }

        final newMaster =
        _createMasterAttractionData(
          heritageDocumentId:
          heritageDoc.id,
          heritageData:
          heritageData,
        );

        await attractionRef.set(
          newMaster,
          SetOptions(merge: true),
        );

        attractionId =
            attractionRef.id;

        final createdSnapshot =
        await attractionRef.get();

        attractionById[
        attractionId] =
            createdSnapshot.data() ??
                <String, dynamic>{};

        if (normalizedHeritageName
            .isNotEmpty) {
          attractionIdByName.putIfAbsent(
            normalizedHeritageName,
                () => attractionId!,
          );
        }

        created++;

        debugPrint(
          'Heritage migration created master Attraction '
              '$attractionId for "$heritageName".',
        );
      } else if (explicitAttractionId !=
          attractionId) {
        linked++;
      }

      // ----------------------------------------------------------
      // Repair / normalize the master Attraction before deleting
      // duplicate heritage fields.
      // ----------------------------------------------------------
      final attractionRef =
      _attractionCollection.doc(
        attractionId,
      );

      final latestAttractionSnapshot =
      await attractionRef.get();

      final currentAttraction =
      Map<String, dynamic>.from(
        latestAttractionSnapshot.data() ??
            attractionById[
            attractionId] ??
            <String, dynamic>{},
      );

      final masterUpdates =
      _buildMasterRepairUpdates(
        attractionId: attractionId,
        heritageDocumentId:
        heritageDoc.id,
        attractionData:
        currentAttraction,
        heritageData:
        heritageData,
      );

      if (masterUpdates.isNotEmpty) {
        await attractionRef.set(
          masterUpdates,
          SetOptions(merge: true),
        );
      }

      // ----------------------------------------------------------
      // Only AFTER the master document has been repaired do we
      // remove duplicate general fields from heritage_attractions.
      // ----------------------------------------------------------
      final heritageType =
      _firstNonEmpty([
        _text(
          heritageData,
          'heritageType',
        ),
        _text(
          heritageData,
          'category',
        ),
        'Heritage Site',
      ]);

      final duplicateGeneralFields =
      <String>[
        'name',
        'address',
        'area',
        'city',
        'state',
        'category',
        'categoryId',
        'categoryName',
        'latitude',
        'longitude',
        'imageUrl',
        'coverImageUrl',
        'imageUrls',
        'openingHours',
        'openingTime',
        'closingTime',
        'shortDescription',
        'description',
        'recommendedTime',
        'recommendedDuration',
        'phoneNumber',
        'facilities',
        'highlights',
        'isFreeEntry',
        'malaysianAdultFee',
        'malaysianChildFee',
        'malaysianSeniorFee',
        'nonMalaysianAdultFee',
        'nonMalaysianChildFee',
        'nonMalaysianSeniorFee',
        'status',
      ];

      final needsCleanup =
          duplicateGeneralFields.any(
            heritageData.containsKey,
          ) ||
              _text(
                heritageData,
                'attractionId',
              ) !=
                  attractionId ||
              _text(
                heritageData,
                'heritageType',
              ) !=
                  heritageType ||
              heritageData['schemaVersion'] !=
                  2;

      if (needsCleanup) {
        final cleanupUpdates =
        <String, dynamic>{
          'attractionId': attractionId,
          'heritageType': heritageType,
          'schemaVersion': 2,
          'lastUpdated':
          FieldValue.serverTimestamp(),

          // General Attraction data now belongs in `attractions`.
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

        await heritageDoc.reference.set(
          cleanupUpdates,
          SetOptions(merge: true),
        );

        cleaned++;

        debugPrint(
          'Heritage migration cleaned ${heritageDoc.id} '
              '-> attractions/$attractionId.',
        );
      }
    }

    final result = HeritageMigrationResult(
      total: heritageSnapshot.docs.length,
      created: created,
      linked: linked,
      cleaned: cleaned,
      skipped: skipped,
    );

    debugPrint(
      'Heritage final migration finished: $result',
    );

    return result;
  }

  // Backward-compatible method name used by the previous page.
  Future<void> createMissingAttractionRecords() async {
    await finalizeHeritageStructure();
  }

  // ============================================================
  // MASTER ATTRACTION CREATION
  // ============================================================

  Map<String, dynamic>
  _createMasterAttractionData({
    required String heritageDocumentId,
    required Map<String, dynamic>
    heritageData,
  }) {
    final imageUrl =
    _text(
      heritageData,
      'imageUrl',
    );

    final parsedHours =
    _splitOpeningHours(
      _text(
        heritageData,
        'openingHours',
      ),
    );

    final duration =
    _normalizeDuration(
      _text(
        heritageData,
        'recommendedTime',
      ),
    );

    return {
      'name':
      _text(heritageData, 'name'),
      'address': '',
      'area':
      _text(heritageData, 'city'),
      'state':
      _text(heritageData, 'state'),

      'categoryId':
      culturalHeritageCategoryId,
      'categoryName':
      culturalHeritageCategoryName,

      'description':
      _text(
        heritageData,
        'shortDescription',
      ),

      'latitude':
      _asDouble(
        heritageData['latitude'],
      ),
      'longitude':
      _asDouble(
        heritageData['longitude'],
      ),

      'coverImageUrl': imageUrl,
      'imageUrls': imageUrl.isEmpty
          ? <String>[]
          : <String>[imageUrl],

      'openingTime':
      parsedHours.$1,
      'closingTime':
      parsedHours.$2,

      'recommendedDuration':
      duration.isEmpty
          ? '1 - 2 hours'
          : duration,

      'phoneNumber': '',
      'facilities': <String>[],
      'highlights': <String>[
        _firstNonEmpty([
          _text(
            heritageData,
            'heritageType',
          ),
          _text(
            heritageData,
            'category',
          ),
          'Heritage Site',
        ]),
      ],

      // Current heritage seed records contain no paid-fee data.
      'isFreeEntry': true,
      'malaysianAdultFee': 0,
      'malaysianChildFee': 0,
      'malaysianSeniorFee': 0,
      'nonMalaysianAdultFee': 0,
      'nonMalaysianChildFee': 0,
      'nonMalaysianSeniorFee': 0,

      'status': _firstNonEmpty([
        _text(
          heritageData,
          'status',
        ),
        'Active',
      ]),

      'source':
      'EcoTravel Heritage Migration',
      'sourceCategories': <String>[
        'cultural_heritage',
        'heritage',
      ],
      'sourcePlaceId':
      heritageDocumentId,
      'sourceQualityScore': 0,
      'sourceWebsite': '',

      'createdAt':
      FieldValue.serverTimestamp(),
      'updatedAt':
      FieldValue.serverTimestamp(),
      'importedAt':
      FieldValue.serverTimestamp(),
    };
  }

  // ============================================================
  // REPAIR / NORMALIZE EXISTING MASTER ATTRACTIONS
  // ============================================================

  Map<String, dynamic>
  _buildMasterRepairUpdates({
    required String attractionId,
    required String heritageDocumentId,
    required Map<String, dynamic>
    attractionData,
    required Map<String, dynamic>
    heritageData,
  }) {
    final updates =
    <String, dynamic>{};

    String masterText(String key) {
      return _text(
        attractionData,
        key,
      );
    }

    String heritageText(String key) {
      return _text(
        heritageData,
        key,
      );
    }

    void fillText(
        String masterKey,
        String heritageKey,
        ) {
      if (masterText(masterKey).isEmpty) {
        final value =
        heritageText(heritageKey);

        if (value.isNotEmpty) {
          updates[masterKey] = value;
        }
      }
    }

    fillText('name', 'name');
    fillText('area', 'city');
    fillText('state', 'state');
    fillText(
      'description',
      'shortDescription',
    );

    if (!attractionData
        .containsKey('latitude') &&
        heritageData
            .containsKey('latitude')) {
      updates['latitude'] =
          _asDouble(
            heritageData['latitude'],
          );
    }

    if (!attractionData
        .containsKey('longitude') &&
        heritageData
            .containsKey('longitude')) {
      updates['longitude'] =
          _asDouble(
            heritageData['longitude'],
          );
    }

    final heritageImage =
    heritageText('imageUrl');

    if (masterText('coverImageUrl')
        .isEmpty &&
        heritageImage.isNotEmpty) {
      updates['coverImageUrl'] =
          heritageImage;
    }

    final imageUrls =
    _asStringList(
      attractionData['imageUrls'],
    );

    if (imageUrls.isEmpty &&
        heritageImage.isNotEmpty) {
      updates['imageUrls'] =
      <String>[heritageImage];
    }

    // Cultural & Heritage category is the master category for
    // every linked heritage record.
    if (masterText('categoryId') !=
        culturalHeritageCategoryId) {
      updates['categoryId'] =
          culturalHeritageCategoryId;
    }

    if (masterText('categoryName') !=
        culturalHeritageCategoryName) {
      updates['categoryName'] =
          culturalHeritageCategoryName;
    }

    // Normalize or backfill opening / closing time.
    var opening =
    _normalizeClockTime(
      masterText('openingTime'),
    );

    var closing =
    _normalizeClockTime(
      masterText('closingTime'),
    );

    if (opening.isEmpty ||
        closing.isEmpty) {
      final parsed =
      _splitOpeningHours(
        heritageText(
          'openingHours',
        ),
      );

      if (opening.isEmpty) {
        opening = parsed.$1;
      }

      if (closing.isEmpty) {
        closing = parsed.$2;
      }
    }

    if (opening.isNotEmpty &&
        opening !=
            masterText('openingTime')) {
      updates['openingTime'] =
          opening;
    }

    if (closing.isNotEmpty &&
        closing !=
            masterText('closingTime')) {
      updates['closingTime'] =
          closing;
    }

    // Normalize visit duration.
    final masterDuration =
    _normalizeDuration(
      masterText(
        'recommendedDuration',
      ),
    );

    final heritageDuration =
    _normalizeDuration(
      heritageText(
        'recommendedTime',
      ),
    );

    final duration =
    masterDuration.isNotEmpty
        ? masterDuration
        : heritageDuration;

    if (duration.isNotEmpty &&
        duration !=
            masterText(
              'recommendedDuration',
            )) {
      updates[
      'recommendedDuration'] =
          duration;
    }

    // Keep entry fee logic internally consistent:
    // zero fees => free entry; any positive fee => paid entry.
    const feeKeys = <String>[
      'malaysianAdultFee',
      'malaysianChildFee',
      'malaysianSeniorFee',
      'nonMalaysianAdultFee',
      'nonMalaysianChildFee',
      'nonMalaysianSeniorFee',
    ];

    bool anyPositiveFee = false;

    for (final key in feeKeys) {
      final value =
      _asDouble(
        attractionData[key],
      );

      if (value > 0) {
        anyPositiveFee = true;
        break;
      }
    }

    final shouldBeFree =
    !anyPositiveFee;

    if (attractionData[
    'isFreeEntry'] !=
        shouldBeFree) {
      updates['isFreeEntry'] =
          shouldBeFree;
    }

    if (masterText('status').isEmpty) {
      updates['status'] =
          _firstNonEmpty([
            heritageText('status'),
            'Active',
          ]);
    }

    // Keep heritage source tags without overwriting richer source
    // information already present on an existing Attraction.
    final sourceCategories =
    _asStringList(
      attractionData[
      'sourceCategories'],
    );

    final mergedCategories =
    <String>{
      ...sourceCategories,
      'cultural_heritage',
      'heritage',
    }.toList();

    if (!_sameStringList(
      sourceCategories,
      mergedCategories,
    )) {
      updates['sourceCategories'] =
          mergedCategories;
    }

    if (masterText('sourcePlaceId')
        .isEmpty &&
        masterText('source').startsWith(
          'EcoTravel Heritage',
        )) {
      updates['sourcePlaceId'] =
          heritageDocumentId;
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] =
          FieldValue.serverTimestamp();
    }

    return updates;
  }

  // ============================================================
  // WATCH LINKED HERITAGE ATTRACTIONS
  // ============================================================

  Stream<List<HeritageAttraction>>
  watchAttractions() {
    late StreamController<
        List<HeritageAttraction>> controller;

    StreamSubscription? heritageSubscription;
    StreamSubscription? attractionSubscription;

    bool loading = false;
    bool reloadRequested = false;

    Future<void> emitLatest() async {
      if (controller.isClosed) {
        return;
      }

      if (loading) {
        reloadRequested = true;
        return;
      }

      loading = true;

      try {
        do {
          reloadRequested = false;

          final result =
          await getAttractions();

          if (!controller.isClosed) {
            controller.add(result);
          }
        } while (reloadRequested &&
            !controller.isClosed);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(
            error,
            stackTrace,
          );
        }
      } finally {
        loading = false;
      }
    }

    controller = StreamController<
        List<HeritageAttraction>>(
      onListen: () {
        heritageSubscription =
            _heritageCollection
                .snapshots()
                .listen(
                  (_) => emitLatest(),
              onError: controller.addError,
            );

        attractionSubscription =
            _attractionCollection
                .snapshots()
                .listen(
                  (_) => emitLatest(),
              onError: controller.addError,
            );

        emitLatest();
      },
      onCancel: () async {
        await heritageSubscription
            ?.cancel();
        await attractionSubscription
            ?.cancel();
      },
    );

    return controller.stream;
  }

  // ============================================================
  // LOAD + JOIN
  // ============================================================

  Future<List<HeritageAttraction>>
  getAttractions() async {
    final snapshots = await Future.wait([
      _heritageCollection.get(),
      _attractionCollection.get(),
    ]);

    final heritageSnapshot = snapshots[0];
    final attractionSnapshot = snapshots[1];

    final attractionById =
    <String, QueryDocumentSnapshot<
        Map<String, dynamic>>>{};

    final attractionByName =
    <String, QueryDocumentSnapshot<
        Map<String, dynamic>>>{};

    for (final doc
    in attractionSnapshot.docs) {
      attractionById[doc.id] = doc;

      final name = _normalize(
        doc.data()['name']
            ?.toString() ??
            '',
      );

      if (name.isNotEmpty) {
        attractionByName.putIfAbsent(
          name,
              () => doc,
        );
      }
    }

    final result =
    <HeritageAttraction>[];

    for (final heritageDoc
    in heritageSnapshot.docs) {
      final heritageData =
      heritageDoc.data();

      final explicitAttractionId =
      _text(
        heritageData,
        'attractionId',
      );

      QueryDocumentSnapshot<
          Map<String, dynamic>>?
      attractionDoc;

      if (explicitAttractionId.isNotEmpty) {
        attractionDoc =
        attractionById[
        explicitAttractionId];
      }

      attractionDoc ??=
      attractionById[
      heritageDoc.id];

      if (attractionDoc == null) {
        final heritageName =
        _normalize(
          heritageData['name']
              ?.toString() ??
              '',
        );

        if (heritageName.isNotEmpty) {
          attractionDoc =
          attractionByName[
          heritageName];
        }
      }

      result.add(
        HeritageAttraction
            .fromLinkedFirestore(
          heritageDocumentId:
          heritageDoc.id,
          heritageData:
          heritageData,
          attractionDocumentId:
          attractionDoc?.id ??
              explicitAttractionId,
          attractionData:
          attractionDoc?.data(),
        ),
      );
    }

    result.sort(
          (a, b) => a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      ),
    );

    return result;
  }

  Future<HeritageAttraction?> getById(
      String id,
      ) async {
    final cleanId = id.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    final attractions =
    await getAttractions();

    for (final attraction
    in attractions) {
      if (attraction.id == cleanId ||
          attraction.heritageDocumentId ==
              cleanId) {
        return attraction;
      }
    }

    return null;
  }

  Future<List<HeritageAttraction>>
  getByIds(
      List<String> ids,
      ) async {
    if (ids.isEmpty) {
      return const <HeritageAttraction>[];
    }

    final all =
    await getAttractions();

    final byId =
    <String, HeritageAttraction>{};

    for (final attraction in all) {
      byId[attraction.id] =
          attraction;

      if (attraction
          .heritageDocumentId
          .isNotEmpty) {
        byId.putIfAbsent(
          attraction
              .heritageDocumentId,
              () => attraction,
        );
      }
    }

    final result =
    <HeritageAttraction>[];

    for (final id in ids) {
      final attraction =
      byId[id.trim()];

      if (attraction != null) {
        result.add(attraction);
      }
    }

    return result;
  }

  Future<HeritageAttraction?>
  findByVisionCandidates(
      List<String> candidates,
      ) async {
    if (candidates.isEmpty) {
      return null;
    }

    final attractions =
    await getAttractions();

    final normalizedCandidates =
    candidates
        .map(_normalize)
        .where(
          (value) =>
      value.isNotEmpty,
    )
        .toList();

    for (final attraction
    in attractions) {
      final possibleNames =
      <String>[
        attraction.name,
        ...attraction.aliases,
      ].map(_normalize);

      for (final possibleName
      in possibleNames) {
        if (possibleName.isEmpty) {
          continue;
        }

        for (final candidate
        in normalizedCandidates) {
          if (candidate ==
              possibleName ||
              candidate.contains(
                possibleName,
              ) ||
              possibleName.contains(
                candidate,
              )) {
            return attraction;
          }
        }
      }
    }

    return null;
  }

  Future<void> linkToAttraction({
    required String heritageDocumentId,
    required String attractionId,
  }) async {
    final cleanHeritageId =
    heritageDocumentId.trim();
    final cleanAttractionId =
    attractionId.trim();

    if (cleanHeritageId.isEmpty ||
        cleanAttractionId.isEmpty) {
      throw ArgumentError(
        'heritageDocumentId and attractionId are required.',
      );
    }

    final attractionDoc =
    await _attractionCollection
        .doc(cleanAttractionId)
        .get();

    if (!attractionDoc.exists) {
      throw StateError(
        'Attraction $cleanAttractionId does not exist.',
      );
    }

    await _heritageCollection
        .doc(cleanHeritageId)
        .set(
      {
        'attractionId':
        cleanAttractionId,
        'schemaVersion': 2,
        'lastUpdated':
        FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _text(
      Map<String, dynamic> data,
      String key,
      ) {
    return data[key]
        ?.toString()
        .trim() ??
        '';
  }

  String _firstNonEmpty(
      List<String> values,
      ) {
    for (final value in values) {
      final clean = value.trim();

      if (clean.isNotEmpty) {
        return clean;
      }
    }

    return '';
  }

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

  bool _sameStringList(
      List<String> a,
      List<String> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0;
    i < a.length;
    i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  (String, String) _splitOpeningHours(
      String value,
      ) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return ('', '');
    }

    final normalized = clean
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    final parts = normalized
        .split('-')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
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
    _normalizeClockTime(clean),
    '',
    );
  }

  String _normalizeClockTime(
      String value,
      ) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return '';
    }

    final match = RegExp(
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
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
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
