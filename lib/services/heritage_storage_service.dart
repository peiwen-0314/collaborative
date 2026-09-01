import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class HeritageDiaryEntry {
  const HeritageDiaryEntry({
    required this.attraction,
    required this.savedAt,
  });

  final HeritageAttraction attraction;
  final DateTime savedAt;
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
  }) : _firestoreService =
      firestoreService ?? HeritageFirestoreService();

  // Old diary key.
  // Keep this so your previously saved attractions are not lost.
  static const String _diaryKey = 'heritage_diary_ids';

  // New diary key.
  // Stores attraction ID together with saved date/time.
  static const String _diaryEntriesKey =
      'heritage_diary_entries';

  static const String _historyKey =
      'heritage_recognition_history';

  final HeritageFirestoreService _firestoreService;

  // ============================================================
  // LOAD DIARY - OLD COMPATIBILITY
  // ============================================================

  Future<List<HeritageAttraction>> loadDiary() async {
    final prefs = await SharedPreferences.getInstance();

    final ids =
        prefs.getStringList(_diaryKey) ?? <String>[];

    return _firestoreService.getByIds(ids);
  }

  // ============================================================
  // LOAD DIARY WITH SAVED DATE/TIME
  // ============================================================

  Future<List<HeritageDiaryEntry>>
  loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();

    final oldIds =
        prefs.getStringList(_diaryKey) ?? <String>[];

    final rawEntries = List<String>.from(
      prefs.getStringList(_diaryEntriesKey) ??
          <String>[],
    );

    final savedDates = <String, DateTime>{};

    // Read new diary entries.
    for (final item in rawEntries) {
      try {
        final data =
        jsonDecode(item) as Map<String, dynamic>;

        final id = data['id']?.toString() ?? '';

        final savedAt = DateTime.tryParse(
          data['savedAt']?.toString() ?? '',
        );

        if (id.isNotEmpty && savedAt != null) {
          savedDates[id] = savedAt;
        }
      } catch (_) {
        // Ignore invalid local records.
      }
    }

    // ==========================================================
    // MIGRATE OLD SAVED DIARY ITEMS
    // ==========================================================

    var needsSave = false;

    for (var i = 0; i < oldIds.length; i++) {
      final id = oldIds[i];

      if (!savedDates.containsKey(id)) {
        // Existing items did not store a date previously.
        // Give them a migration timestamp so they remain visible.
        final savedAt = DateTime.now().subtract(
          Duration(minutes: i),
        );

        savedDates[id] = savedAt;

        rawEntries.add(
          jsonEncode({
            'id': id,
            'savedAt': savedAt.toIso8601String(),
          }),
        );

        needsSave = true;
      }
    }

    if (needsSave) {
      await prefs.setStringList(
        _diaryEntriesKey,
        rawEntries,
      );
    }

    // Combine IDs.
    final allIds = <String>[...oldIds];

    for (final id in savedDates.keys) {
      if (!allIds.contains(id)) {
        allIds.add(id);
      }
    }

    final result = <HeritageDiaryEntry>[];

    // Get actual attraction information from Firestore.
    for (final id in allIds) {
      final attraction =
      await _firestoreService.getById(id);

      if (attraction == null) continue;

      result.add(
        HeritageDiaryEntry(
          attraction: attraction,
          savedAt:
          savedDates[id] ?? DateTime.now(),
        ),
      );
    }

    // Newest first by default.
    result.sort(
          (a, b) =>
          b.savedAt.compareTo(a.savedAt),
    );

    return result;
  }

  // ============================================================
  // ADD TO DIARY
  // ============================================================

  Future<void> addToDiary(
      HeritageAttraction attraction,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    // ----------------------------------------------------------
    // Keep old ID storage for compatibility.
    // ----------------------------------------------------------

    final ids =
        prefs.getStringList(_diaryKey) ?? <String>[];

    if (!ids.contains(attraction.id)) {
      ids.insert(0, attraction.id);

      await prefs.setStringList(
        _diaryKey,
        ids,
      );
    }

    // ----------------------------------------------------------
    // Store ID + saved date/time.
    // ----------------------------------------------------------

    final rawEntries = List<String>.from(
      prefs.getStringList(_diaryEntriesKey) ??
          <String>[],
    );

    var alreadyExists = false;

    for (final item in rawEntries) {
      try {
        final data =
        jsonDecode(item) as Map<String, dynamic>;

        if (data['id']?.toString() ==
            attraction.id) {
          alreadyExists = true;
          break;
        }
      } catch (_) {
        // Ignore invalid record.
      }
    }

    // Prevent duplicate diary records.
    if (!alreadyExists) {
      rawEntries.insert(
        0,
        jsonEncode({
          'id': attraction.id,
          'savedAt':
          DateTime.now().toIso8601String(),
        }),
      );

      await prefs.setStringList(
        _diaryEntriesKey,
        rawEntries,
      );
    }
  }

  // ============================================================
  // REMOVE FROM DIARY
  // ============================================================

  Future<void> removeFromDiary(
      String attractionId,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove old stored ID.
    final ids =
        prefs.getStringList(_diaryKey) ?? <String>[];

    ids.remove(attractionId);

    await prefs.setStringList(
      _diaryKey,
      ids,
    );

    // Remove new diary record.
    final rawEntries = List<String>.from(
      prefs.getStringList(_diaryEntriesKey) ??
          <String>[],
    );

    rawEntries.removeWhere((item) {
      try {
        final data =
        jsonDecode(item) as Map<String, dynamic>;

        return data['id']?.toString() ==
            attractionId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(
      _diaryEntriesKey,
      rawEntries,
    );
  }

  // ============================================================
  // ADD RECOGNITION HISTORY
  // ============================================================

  Future<void> addRecognition(
      HeritageAttraction attraction,
      ) async {
    final prefs = await SharedPreferences.getInstance();

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

  // ============================================================
  // LOAD RECOGNITION HISTORY
  // ============================================================

  Future<List<RecognitionHistoryEntry>>
  loadRecognitionHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final raw =
        prefs.getStringList(_historyKey) ??
            <String>[];

    final result =
    <RecognitionHistoryEntry>[];

    for (final item in raw) {
      try {
        final data =
        jsonDecode(item) as Map<String, dynamic>;

        final id =
            data['id']?.toString() ?? '';

        final date = DateTime.tryParse(
          data['time']?.toString() ?? '',
        );

        if (id.isEmpty || date == null) {
          continue;
        }

        final attraction =
        await _firestoreService.getById(id);

        if (attraction != null) {
          result.add(
            RecognitionHistoryEntry(
              attraction: attraction,
              recognizedAt: date,
            ),
          );
        }
      } catch (_) {
        // Ignore old or malformed records.
      }
    }

    return result;
  }
}