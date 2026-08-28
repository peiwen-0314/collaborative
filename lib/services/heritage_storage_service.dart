import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/heritage_data.dart';
import '../models/heritage_attraction.dart';

class RecognitionHistoryEntry {
  const RecognitionHistoryEntry({
    required this.attraction,
    required this.recognizedAt,
  });

  final HeritageAttraction attraction;
  final DateTime recognizedAt;
}

class HeritageStorageService {
  static const String _diaryKey = 'heritage_diary_ids';
  static const String _historyKey = 'heritage_recognition_history';

  Future<List<HeritageAttraction>> loadDiary() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_diaryKey) ?? <String>[];
    return ids
        .map(HeritageData.byId)
        .whereType<HeritageAttraction>()
        .toList();
  }

  Future<void> addToDiary(HeritageAttraction attraction) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_diaryKey) ?? <String>[];
    if (!ids.contains(attraction.id)) {
      ids.insert(0, attraction.id);
      await prefs.setStringList(_diaryKey, ids);
    }
  }

  Future<void> removeFromDiary(String attractionId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_diaryKey) ?? <String>[];
    ids.remove(attractionId);
    await prefs.setStringList(_diaryKey, ids);
  }

  Future<void> addRecognition(HeritageAttraction attraction) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    raw.insert(
      0,
      jsonEncode({
        'id': attraction.id,
        'time': DateTime.now().toIso8601String(),
      }),
    );
    if (raw.length > 20) {
      raw.removeRange(20, raw.length);
    }
    await prefs.setStringList(_historyKey, raw);
  }

  Future<List<RecognitionHistoryEntry>> loadRecognitionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    final result = <RecognitionHistoryEntry>[];

    for (final item in raw) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final attraction = HeritageData.byId(data['id']?.toString() ?? '');
        final date = DateTime.tryParse(data['time']?.toString() ?? '');
        if (attraction != null && date != null) {
          result.add(
            RecognitionHistoryEntry(
              attraction: attraction,
              recognizedAt: date,
            ),
          );
        }
      } catch (_) {
        // Ignore malformed historical entries.
      }
    }

    return result;
  }
}
