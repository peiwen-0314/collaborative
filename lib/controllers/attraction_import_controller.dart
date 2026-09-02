import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/geoapify_attraction_service.dart';

class AttractionImportController extends ChangeNotifier {
  static const String geoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
  );

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

  Future<void> search({
    required String area,
    String? state,
    int radiusKm = 20,
  }) async {
    final cleanArea = area.trim();

    if (cleanArea.isEmpty) {
      errorMessage = 'Please enter an area or city.';
      successMessage = null;
      notifyListeners();
      return;
    }

    if (!hasApiKey) {
      errorMessage =
          'Geoapify API key is missing. See the run command below.';
      successMessage = null;
      notifyListeners();
      return;
    }

    isSearching = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final fetched = await _service.searchAttractions(
        area: cleanArea,
        state: state,
        radiusMeters: radiusKm * 1000,
        limit: 60,
      );

      results
        ..clear()
        ..addAll(fetched);

      selectedPlaceIds.clear();
      successMessage =
          '${results.length} attractions found around $cleanArea.';
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
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
      final selected = results
          .where((item) => selectedPlaceIds.contains(item.placeId))
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

          final details = await _service.getPlaceDetails(item);

          final imageUrls = <String>[
            if (details.imageUrl.trim().isNotEmpty)
              details.imageUrl.trim(),
          ];

          await _firestore.collection('attractions').add({
            'name': item.name,
            'categoryId': '',
            'categoryName': item.categoryName,
            'state': item.state,
            'area': item.area,
            'description': details.description,
            'isFreeEntry': false,

            'malaysianAdultFee': 0.0,
            'malaysianChildFee': 0.0,
            'malaysianSeniorFee': 0.0,

            'nonMalaysianAdultFee': 0.0,
            'nonMalaysianChildFee': 0.0,
            'nonMalaysianSeniorFee': 0.0,

            'openingTime': details.openingTime,
            'closingTime': details.closingTime,
            'recommendedDuration': '1 - 2 hours',
            'address': item.address,
            'phoneNumber': details.phoneNumber,
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
            'importedAt': FieldValue.serverTimestamp(),
          });

          imported++;
        } catch (_) {
          failed++;
        }
      }

      successMessage =
          '$imported imported, $skipped duplicate(s) skipped'
          '${failed > 0 ? ', $failed failed' : ''}.';

      return ImportSummary(
        imported: imported,
        skipped: skipped,
        failed: failed,
      );
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
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
