import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/geoapify_attraction_service.dart';

class AttractionImportController extends ChangeNotifier {
  static const String geoapifyApiKey =
  String.fromEnvironment('GEOAPIFY_API_KEY');

  final FirebaseFirestore _firestore;
  late final GeoapifyAttractionService _service;

  AttractionImportController({
    FirebaseFirestore? firestore,
    GeoapifyAttractionService? service,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    _service = service ??
        const GeoapifyAttractionService(
          apiKey: geoapifyApiKey,
        );
  }

  final List<GeoapifyAttractionCandidate> results = [];
  final Set<String> selectedPlaceIds = {};

  bool isSearching = false;
  bool isImporting = false;

  String? errorMessage;
  String? successMessage;

  String importStatus = 'Draft';

  bool get hasApiKey => _service.hasApiKey;
  int get selectedCount => selectedPlaceIds.length;

  bool isSelected(GeoapifyAttractionCandidate item) {
    return selectedPlaceIds.contains(item.placeId);
  }

  void setImportStatus(String value) {
    importStatus = value;
    notifyListeners();
  }

  void toggleSelected(GeoapifyAttractionCandidate item) {
    if (selectedPlaceIds.contains(item.placeId)) {
      selectedPlaceIds.remove(item.placeId);
    } else {
      selectedPlaceIds.add(item.placeId);
    }

    notifyListeners();
  }

  void selectAll() {
    selectedPlaceIds
      ..clear()
      ..addAll(results.map((e) => e.placeId));

    notifyListeners();
  }

  void clearSelection() {
    selectedPlaceIds.clear();
    notifyListeners();
  }

  Future<void> searchByState({
    required String state,
  }) async {
    if (!hasApiKey) {
      errorMessage = 'Geoapify API key is missing.';
      successMessage = null;
      notifyListeners();
      return;
    }

    isSearching = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final fetched =
      await _service.searchStateAttractions(
        state: state,
      );

      results
        ..clear()
        ..addAll(fetched);

      selectedPlaceIds.clear();

      successMessage =
      '${results.length} attractions found across $state. '
          'Higher-quality attractions are shown first.';
    } catch (e) {
      errorMessage =
          e.toString().replaceFirst('Exception: ', '');
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  Future<ImportSummary> importSelected() async {
    if (selectedPlaceIds.isEmpty) {
      errorMessage = 'Please select at least one attraction.';
      successMessage = null;
      notifyListeners();

      return const ImportSummary();
    }

    isImporting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    int imported = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final categorySnapshot =
      await _firestore.collection('categories').get();

      final Map<String, _CategoryMatch> categoriesByName = {};

      for (final doc in categorySnapshot.docs) {
        final data = doc.data();

        final status =
        (data['status'] ?? 'Active').toString().trim();

        if (status != 'Active') {
          continue;
        }

        final name =
        (data['name'] ?? '').toString().trim();

        if (name.isEmpty) {
          continue;
        }

        categoriesByName[_normalizeCategoryName(name)] =
            _CategoryMatch(
              id: doc.id,
              name: name,
            );
      }

      final selected = results
          .where(
            (item) =>
            selectedPlaceIds.contains(item.placeId),
      )
          .toList();

      for (final item in selected) {
        try {
          final duplicate = await _firestore
              .collection('attractions')
              .where(
            'sourcePlaceId',
            isEqualTo: item.placeId,
          )
              .limit(1)
              .get();

          if (duplicate.docs.isNotEmpty) {
            skipped++;
            continue;
          }

          final categoryMatch =
          _findMatchingCategory(
            importedCategoryName: item.categoryName,
            categories: categoriesByName,
          );

          if (categoryMatch == null) {
            debugPrint(
              'Import failed for "${item.name}": '
                  'No active Firestore category matches '
                  '"${item.categoryName}".',
            );

            failed++;
            continue;
          }

          final details =
          await _service.getPlaceDetails(item);

          final imageUrls = <String>[
            if (details.imageUrl.trim().isNotEmpty)
              details.imageUrl.trim(),
          ];

          final attractionDocument =
          _firestore.collection('attractions').doc();

          final batch = _firestore.batch();

          batch.set(
            attractionDocument,
            {
              'name': item.name.trim(),

              // Real Firestore category relationship
              'categoryId': categoryMatch.id,
              'categoryName': categoryMatch.name,

              'state': item.state.trim(),
              'area': item.area.trim(),
              'description': details.description.trim(),

              'isFreeEntry': false,

              'malaysianAdultFee': 0.0,
              'malaysianChildFee': 0.0,
              'malaysianSeniorFee': 0.0,

              'nonMalaysianAdultFee': 0.0,
              'nonMalaysianChildFee': 0.0,
              'nonMalaysianSeniorFee': 0.0,

              'openingTime': details.openingTime.trim(),
              'closingTime': details.closingTime.trim(),

              'recommendedDuration': '1 - 2 hours',

              'address': item.address.trim(),
              'phoneNumber': details.phoneNumber.trim(),

              'facilities': details.facilities,
              'highlights': details.highlights,

              'imageUrls': imageUrls,
              'coverImageUrl':
              imageUrls.isNotEmpty ? imageUrls.first : '',

              'status': importStatus,
              'createdAt': FieldValue.serverTimestamp(),

              'latitude': item.latitude,
              'longitude': item.longitude,

              'source': 'Geoapify',
              'sourcePlaceId': item.placeId,
              'sourceCategories': item.categories,
              'sourceQualityScore': item.qualityScore,
              'sourceWebsite': details.website.trim(),
              'importedAt': FieldValue.serverTimestamp(),
            },
          );

          batch.update(
            _firestore
                .collection('categories')
                .doc(categoryMatch.id),
            {
              'attractionCount': FieldValue.increment(1),
            },
          );

          await batch.commit();

          imported++;
        } catch (e) {
          failed++;

          debugPrint(
            'Import attraction "${item.name}" error: $e',
          );
        }
      }

      successMessage =
      '$imported imported, '
          '$skipped duplicate(s) skipped'
          '${failed > 0 ? ', $failed failed' : ''}.';

      return ImportSummary(
        imported: imported,
        skipped: skipped,
        failed: failed,
      );
    } catch (e) {
      errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      return ImportSummary(
        imported: imported,
        skipped: skipped,
        failed: failed,
      );
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  _CategoryMatch? _findMatchingCategory({
    required String importedCategoryName,
    required Map<String, _CategoryMatch> categories,
  }) {
    final normalized =
    _normalizeCategoryName(importedCategoryName);

    final exact = categories[normalized];

    if (exact != null) {
      return exact;
    }

    final aliases = <String, List<String>>{
      'culturalheritage': [
        'cultureheritage',
        'heritageculture',
        'culturalhistorical',
        'culturehistorical',
        'heritage',
      ],
      'artsculture': [
        'artculture',
        'artsheritage',
        'museumculture',
        'museum',
      ],
      'naturescenic': [
        'nature',
        'natureoutdoor',
        'natureadventure',
        'scenicnature',
        'naturalattraction',
      ],
      'religiouscultural': [
        'religious',
        'religionculture',
        'religiousheritage',
        'spiritualcultural',
      ],
      'touristattraction': [
        'attraction',
        'tourism',
        'generaltourism',
        'others',
        'other',
      ],
    };

    final possibleNames =
        aliases[normalized] ?? const <String>[];

    for (final alias in possibleNames) {
      final match = categories[alias];

      if (match != null) {
        return match;
      }
    }

    for (final entry in categories.entries) {
      if (entry.key.contains(normalized) ||
          normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  String _normalizeCategoryName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll('and', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class _CategoryMatch {
  final String id;
  final String name;

  const _CategoryMatch({
    required this.id,
    required this.name,
  });
}

class ImportSummary {
  final int imported;
  final int skipped;
  final int failed;

  const ImportSummary({
    this.imported = 0,
    this.skipped = 0,
    this.failed = 0,
  });
}
