import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/heritage_attraction.dart';

class HeritageFirestoreService {
  HeritageFirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
  get _collection =>
      _firestore.collection(
        'heritage_attractions',
      );

  // ============================================================
  // WATCH ALL ATTRACTIONS
  // ============================================================

  Stream<List<HeritageAttraction>>
  watchAttractions() {
    return _collection.snapshots().map(
          (snapshot) {
        final result = snapshot.docs
            .map(
              (doc) =>
              HeritageAttraction.fromFirestore(
                doc.id,
                doc.data(),
              ),
        )
            .toList();

        result.sort(
              (a, b) => a.name
              .toLowerCase()
              .compareTo(
            b.name.toLowerCase(),
          ),
        );

        return result;
      },
    );
  }

  // ============================================================
  // GET ALL ATTRACTIONS
  // ============================================================

  Future<List<HeritageAttraction>>
  getAttractions() async {
    final snapshot =
    await _collection.get();

    final result = snapshot.docs
        .map(
          (doc) =>
          HeritageAttraction.fromFirestore(
            doc.id,
            doc.data(),
          ),
    )
        .toList();

    result.sort(
          (a, b) => a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      ),
    );

    return result;
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  Future<HeritageAttraction?> getById(
      String id,
      ) async {
    if (id.trim().isEmpty) {
      return null;
    }

    final doc =
    await _collection.doc(id).get();

    final data = doc.data();

    if (!doc.exists || data == null) {
      return null;
    }

    return HeritageAttraction.fromFirestore(
      doc.id,
      data,
    );
  }

  // ============================================================
  // GET MULTIPLE BY IDS
  // ============================================================

  Future<List<HeritageAttraction>> getByIds(
      List<String> ids,
      ) async {
    final result =
    <HeritageAttraction>[];

    for (final id in ids) {
      final attraction =
      await getById(id);

      if (attraction != null) {
        result.add(attraction);
      }
    }

    return result;
  }

  // ============================================================
  // MATCH GOOGLE VISION RESULT
  // ============================================================

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

    // ==========================================================
    // STEP 1:
    // EXACT MATCH FIRST
    // ==========================================================
    //
    // Example:
    //
    // Google:
    // "Kek Lok Si Temple"
    //
    // Firestore:
    // "Kek Lok Si Temple"
    //
    // → exact match → H005
    //
    // This is always checked before generic words such as
    // "Temple", "Pagoda", etc.
    // ==========================================================

    for (final candidate
    in normalizedCandidates) {
      for (final attraction
      in attractions) {
        final possibleNames = <String>[
          attraction.name,
          ...attraction.aliases,
        ];

        for (final name
        in possibleNames) {
          if (_normalize(name) ==
              candidate) {
            return attraction;
          }
        }
      }
    }

    // ==========================================================
    // STEP 2:
    // STRONG KEYWORD MATCH
    // ==========================================================
    //
    // Useful when Google returns:
    //
    // "Guan Yin Statue @Kek Lok Si"
    //
    // It still contains:
    //
    // "kek lok si"
    //
    // Therefore → H005
    //
    // Generic terms are NOT used.
    // ==========================================================

    final strongKeywords =
    <String, List<String>>{
      'H001': [
        'sultan abdul samad',
        'bangunan sultan abdul samad',
      ],

      'H002': [
        'jonker street',
        'jonker walk',
        'jalan hang jebat',
      ],

      'H003': [
        'batu caves',
        'lord murugan batu caves',
        'sri subramaniar swamy',
      ],

      'H004': [
        'a famosa',
        'porta de santiago',
      ],

      'H005': [
        'kek lok si',
        'temple of supreme bliss',
        'guan yin statue kek lok si',
        'kuan yin statue kek lok si',
      ],
    };

    for (final candidate
    in normalizedCandidates) {
      for (final entry
      in strongKeywords.entries) {
        for (final keyword
        in entry.value) {
          final normalizedKeyword =
          _normalize(keyword);

          if (candidate.contains(
            normalizedKeyword,
          )) {
            for (final attraction
            in attractions) {
              if (attraction.id ==
                  entry.key) {
                return attraction;
              }
            }
          }
        }
      }
    }

    // ==========================================================
    // STEP 3:
    // NO SAFE MATCH
    // ==========================================================
    //
    // Examples:
    //
    // "Temple"
    // "Pagoda"
    // "Buddhist temple"
    // "Tourist attraction"
    // "Spink In The Sky"
    // "Penang Air Itam Laksa"
    //
    // These should NOT be forced into an attraction.
    // ==========================================================

    return null;
  }

  // ============================================================
  // NORMALIZE TEXT
  // ============================================================

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