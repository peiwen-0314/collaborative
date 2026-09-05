import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class HeritageDiaryEntry {
  const HeritageDiaryEntry({
    required this.documentId,
    required this.attraction,
    required this.savedAt,
    this.story = '',
  });

  // Unique Firestore visit document.
  // One attraction may appear more than once on different dates.
  final String documentId;
  final HeritageAttraction attraction;
  final DateTime savedAt;
  final String story;
}

class RecognitionHistoryEntry {
  const RecognitionHistoryEntry({
    required this.attraction,
    required this.recognizedAt,
  });

  final HeritageAttraction attraction;
  final DateTime recognizedAt;
}

class HeritageStorageService {
  HeritageStorageService({
    HeritageFirestoreService? firestoreService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreService =
      firestoreService ?? HeritageFirestoreService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final HeritageFirestoreService _firestoreService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ============================================================
  // OLD LOCAL KEYS
  // Used only for one-time migration of existing diary data.
  // Recognition history is still kept locally.
  // ============================================================

  static const String _diaryKey = 'heritage_diary_ids';

  static const String _diaryEntriesKey =
      'heritage_diary_entries';

  static const String _historyKey =
      'heritage_recognition_history';

  // ============================================================
  // FIRESTORE PATH
  //
  // users
  //   └── {uid}
  //        └── heritageDiary
  //             └── {attractionId + visitDate}
  //                  ├── attractionId
  //                  ├── dateKey      // yyyyMMdd
  //                  ├── savedAt
  //                  ├── story
  //                  └── updatedAt
  //
  // Rule:
  // same attraction + same calendar date = one visit only
  // same attraction + different calendar date = allowed
  // ============================================================

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'A user must be signed in before accessing the heritage diary.',
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>>
  _userDiaryCollection() {
    final user = _requireUser();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('heritageDiary');
  }


  String _dateKey(DateTime value) {
    final local = value.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year$month$day';
  }

  String _diaryDocumentId(
      String attractionId,
      DateTime date,
      ) {
    // base64Url keeps the attraction ID safe as a Firestore document ID.
    final encodedAttractionId = base64Url
        .encode(utf8.encode(attractionId))
        .replaceAll('=', '');

    return '${encodedAttractionId}_${_dateKey(date)}';
  }

  DateTime _readSavedAt(
      dynamic rawSavedAt,
      ) {
    if (rawSavedAt is Timestamp) {
      return rawSavedAt.toDate();
    }

    if (rawSavedAt is DateTime) {
      return rawSavedAt;
    }

    return DateTime.tryParse(
      rawSavedAt?.toString() ?? '',
    ) ??
        DateTime.now();
  }

  // ============================================================
  // ONE-TIME LOCAL -> FIRESTORE MIGRATION
  // ============================================================

  Future<void> _migrateLocalDiaryIfNeeded() async {
    final user = _requireUser();
    final prefs = await SharedPreferences.getInstance();

    final migrationKey =
        'heritage_diary_firestore_migrated_${user.uid}';

    if (prefs.getBool(migrationKey) == true) {
      return;
    }

    final oldIds =
        prefs.getStringList(_diaryKey) ?? <String>[];

    final rawEntries = List<String>.from(
      prefs.getStringList(_diaryEntriesKey) ??
          <String>[],
    );

    final localData =
    <String, Map<String, dynamic>>{};

    // Read the newer local JSON diary records first.
    for (final item in rawEntries) {
      try {
        final decoded =
        jsonDecode(item) as Map<String, dynamic>;

        final id = decoded['id']?.toString() ?? '';

        if (id.isEmpty) {
          continue;
        }

        final savedAt = DateTime.tryParse(
          decoded['savedAt']?.toString() ?? '',
        );

        localData[id] = {
          'savedAt': savedAt ?? DateTime.now(),
          'story': decoded['story']?.toString() ?? '',
        };
      } catch (_) {
        // Ignore malformed old local records.
      }
    }

    // Support very old diary records that only stored IDs.
    for (var i = 0; i < oldIds.length; i++) {
      final id = oldIds[i];

      localData.putIfAbsent(
        id,
            () => {
          'savedAt': DateTime.now().subtract(
            Duration(minutes: i),
          ),
          'story': '',
        },
      );
    }

    final collection = _userDiaryCollection();

    // Only create Firestore documents that do not already exist.
    // This prevents an old local blank story from overwriting a
    // newer Firestore story.
    for (final entry in localData.entries) {
      final savedAt =
      entry.value['savedAt'] as DateTime;
      final story =
          entry.value['story']?.toString() ?? '';

      final docRef = collection.doc(
        _diaryDocumentId(
          entry.key,
          savedAt,
        ),
      );

      final existing = await docRef.get();

      if (existing.exists) {
        continue;
      }

      await docRef.set({
        'attractionId': entry.key,
        'dateKey': _dateKey(savedAt),
        'savedAt': Timestamp.fromDate(savedAt),
        'story': story.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await prefs.setBool(
      migrationKey,
      true,
    );
  }

  // ============================================================
  // ONE-TIME FIRESTORE DOCUMENT-ID MIGRATION
  //
  // Older version used:
  //   heritageDiary/{attractionId}
  //
  // New version uses:
  //   heritageDiary/{attractionId + date}
  //
  // This allows repeat visits on different dates.
  // ============================================================

  Future<void> _migrateLegacyFirestoreDocumentsIfNeeded() async {
    final user = _requireUser();
    final prefs = await SharedPreferences.getInstance();

    final migrationKey =
        'heritage_diary_date_documents_v2_${user.uid}';

    if (prefs.getBool(migrationKey) == true) {
      return;
    }

    final collection = _userDiaryCollection();
    final snapshot = await collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final attractionId =
          data['attractionId']?.toString().trim() ?? '';

      if (attractionId.isEmpty) {
        continue;
      }

      final savedAt = _readSavedAt(
        data['savedAt'],
      );

      final targetId = _diaryDocumentId(
        attractionId,
        savedAt,
      );

      final targetDateKey = _dateKey(
        savedAt,
      );

      if (doc.id == targetId) {
        if (data['dateKey']?.toString() !=
            targetDateKey) {
          await doc.reference.set(
            {
              'dateKey': targetDateKey,
            },
            SetOptions(merge: true),
          );
        }

        continue;
      }

      final targetRef =
      collection.doc(targetId);

      final targetSnapshot =
      await targetRef.get();

      if (!targetSnapshot.exists) {
        await targetRef.set({
          ...data,
          'attractionId': attractionId,
          'dateKey': targetDateKey,
          'savedAt': Timestamp.fromDate(savedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If both old and new documents exist for the same
        // attraction/date, keep only one. Preserve an existing
        // non-empty story where possible.
        final targetData =
        targetSnapshot.data();

        final targetStory =
            targetData?['story']
                ?.toString()
                .trim() ??
                '';

        final oldStory =
            data['story']
                ?.toString()
                .trim() ??
                '';

        if (targetStory.isEmpty &&
            oldStory.isNotEmpty) {
          await targetRef.set(
            {
              'story': oldStory,
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await doc.reference.delete();
    }

    await prefs.setBool(
      migrationKey,
      true,
    );
  }

  Future<void> _prepareDiary() async {
    await _migrateLocalDiaryIfNeeded();
    await _migrateLegacyFirestoreDocumentsIfNeeded();
  }

  // ============================================================
  // LOAD DIARY - COMPATIBILITY METHOD
  // ============================================================

  Future<List<HeritageAttraction>> loadDiary() async {
    final entries = await loadDiaryEntries();

    return entries
        .map((entry) => entry.attraction)
        .toList();
  }

  // ============================================================
  // LOAD DIARY FROM FIRESTORE
  // ============================================================

  Future<List<HeritageDiaryEntry>>
  loadDiaryEntries() async {
    await _prepareDiary();

    final snapshot = await _userDiaryCollection()
        .orderBy(
      'savedAt',
      descending: true,
    )
        .get();

    final result = <HeritageDiaryEntry>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final attractionId =
      data['attractionId']?.toString().trim().isNotEmpty ==
          true
          ? data['attractionId'].toString()
          : doc.id;

      final attraction =
      await _firestoreService.getById(
        attractionId,
      );

      if (attraction == null) {
        continue;
      }

      final savedAt = _readSavedAt(
        data['savedAt'],
      );

      result.add(
        HeritageDiaryEntry(
          documentId: doc.id,
          attraction: attraction,
          savedAt: savedAt,
          story:
          data['story']?.toString() ?? '',
        ),
      );
    }

    result.sort(
          (a, b) =>
          b.savedAt.compareTo(a.savedAt),
    );

    return result;
  }

  // ============================================================
  // ADD TO DIARY - FIRESTORE
  //
  // Same attraction on the SAME calendar date is blocked.
  // Same attraction on a DIFFERENT calendar date is allowed.
  // ============================================================

  Future<bool> addToDiary(
      HeritageAttraction attraction, {
        DateTime? savedAt,
      }) async {
    await _prepareDiary();

    final visitDate =
        savedAt ?? DateTime.now();

    final docRef = _userDiaryCollection().doc(
      _diaryDocumentId(
        attraction.id,
        visitDate,
      ),
    );

    return _firestore.runTransaction<bool>(
          (transaction) async {
        final snapshot =
        await transaction.get(docRef);

        // Same attraction + same date already exists.
        if (snapshot.exists) {
          return false;
        }

        transaction.set(
          docRef,
          {
            'attractionId': attraction.id,
            'dateKey': _dateKey(visitDate),
            'savedAt': Timestamp.fromDate(
              visitDate,
            ),
            'story': '',
            'createdAt':
            FieldValue.serverTimestamp(),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        return true;
      },
    );
  }

  // ============================================================
  // CHECK IF THIS ATTRACTION IS ALREADY SAVED FOR A DATE
  // ============================================================

  Future<bool> isInDiary(
      String attractionId, {
        DateTime? date,
      }) async {
    await _prepareDiary();

    final visitDate =
        date ?? DateTime.now();

    final snapshot = await _userDiaryCollection()
        .doc(
      _diaryDocumentId(
        attractionId,
        visitDate,
      ),
    )
        .get();

    return snapshot.exists;
  }

  // ============================================================
  // UPDATE DIARY SAVED DATE/TIME - FIRESTORE
  //
  // Returns false when the same attraction already has another
  // visit on the selected target date.
  // ============================================================

  Future<bool> updateDiarySavedAt(
      String documentId,
      DateTime savedAt,
      ) async {
    await _prepareDiary();

    final collection =
    _userDiaryCollection();

    final sourceRef =
    collection.doc(documentId);

    return _firestore.runTransaction<bool>(
          (transaction) async {
        final sourceSnapshot =
        await transaction.get(sourceRef);

        if (!sourceSnapshot.exists) {
          return false;
        }

        final sourceData =
        sourceSnapshot.data()!;

        final attractionId =
            sourceData['attractionId']
                ?.toString() ??
                '';

        if (attractionId.isEmpty) {
          return false;
        }

        final targetId =
        _diaryDocumentId(
          attractionId,
          savedAt,
        );

        // Same visit document, only update its timestamp.
        if (targetId == documentId) {
          transaction.set(
            sourceRef,
            {
              'dateKey': _dateKey(savedAt),
              'savedAt':
              Timestamp.fromDate(savedAt),
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          return true;
        }

        final targetRef =
        collection.doc(targetId);

        final targetSnapshot =
        await transaction.get(targetRef);

        // Another visit of this attraction already exists
        // on the selected calendar date.
        if (targetSnapshot.exists) {
          return false;
        }

        transaction.set(
          targetRef,
          {
            ...sourceData,
            'attractionId': attractionId,
            'dateKey': _dateKey(savedAt),
            'savedAt':
            Timestamp.fromDate(savedAt),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        transaction.delete(sourceRef);

        return true;
      },
    );
  }

  // ============================================================
  // UPDATE DIARY STORY - FIRESTORE
  // ============================================================

  Future<void> updateDiaryStory(
      String documentId,
      String story,
      ) async {
    await _prepareDiary();

    final docRef = _userDiaryCollection()
        .doc(documentId);

    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw StateError(
        'Diary visit no longer exists.',
      );
    }

    await docRef.set(
      {
        'story': story.trim(),
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // REMOVE FROM DIARY - FIRESTORE
  // ============================================================

  Future<void> removeFromDiary(
      String documentId,
      ) async {
    await _prepareDiary();

    await _userDiaryCollection()
        .doc(documentId)
        .delete();
  }

  // ============================================================
  // RECOGNITION HISTORY
  //
  // This remains local because your request was to move the
  // heritage diary/story to Firestore.
  // ============================================================

  Future<void> addRecognition(
      HeritageAttraction attraction,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    final raw =
        prefs.getStringList(_historyKey) ??
            <String>[];

    raw.insert(
      0,
      jsonEncode({
        'id': attraction.id,
        'time':
        DateTime.now().toIso8601String(),
      }),
    );

    if (raw.length > 20) {
      raw.removeRange(
        20,
        raw.length,
      );
    }

    await prefs.setStringList(
      _historyKey,
      raw,
    );
  }

  Future<List<RecognitionHistoryEntry>>
  loadRecognitionHistory() async {
    final prefs =
    await SharedPreferences.getInstance();

    final raw =
        prefs.getStringList(_historyKey) ??
            <String>[];

    final result =
    <RecognitionHistoryEntry>[];

    for (final item in raw) {
      try {
        final data =
        jsonDecode(item)
        as Map<String, dynamic>;

        final id =
            data['id']?.toString() ?? '';

        final date = DateTime.tryParse(
          data['time']?.toString() ?? '',
        );

        if (id.isEmpty || date == null) {
          continue;
        }

        final attraction =
        await _firestoreService.getById(
          id,
        );

        if (attraction != null) {
          result.add(
            RecognitionHistoryEntry(
              attraction: attraction,
              recognizedAt: date,
            ),
          );
        }
      } catch (_) {
        // Ignore malformed recognition records.
      }
    }

    return result;
  }
}
