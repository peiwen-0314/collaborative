class HeritageAttraction {
  const HeritageAttraction({
    required this.id,
    required this.name,
    required this.aliases,
    required this.state,
    required this.city,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.openingHours,
    required this.shortDescription,
    required this.history,
    required this.culturalSignificance,
    required this.visitorEtiquette,
    required this.sustainabilityTip,
    required this.recommendedTime,
    required this.bestTime,
    required this.audioEnglish,
    required this.audioMalay,
    required this.audioChinese,
    this.address = '',
    this.categoryName = 'Cultural & Heritage',
    this.heritageDocumentId = '',
    this.yearBuilt = '',
    this.architecturalStyle = '',
    this.heritageStatus = '',
    this.conservationGuidelines = const <String>[],
    this.visitorEtiquetteItems = const <String>[],
    this.dressCode = const <String>[],
    this.photographyRestrictions = const <String>[],
    this.preservationPractices = const <String>[],
    this.stampImageUrl = '',
  });

  // ============================================================
  // LINK
  // ============================================================

  /// Canonical ID of the document in `attractions`.
  ///
  /// The rest of the app can continue using `attraction.id`.
  /// This means the Heritage Diary, nearby feature and AI recognition
  /// all point back to the same master Attraction.
  final String id;

  /// Firestore document ID in `heritage_attractions`.
  ///
  /// This can be different from [id] for old data.
  final String heritageDocumentId;

  // ============================================================
  // GENERAL ATTRACTION INFORMATION
  //
  // These values should come from `attractions/{id}`.
  // They stay on this view model so the existing UI does not need
  // to be rewritten.
  // ============================================================

  final String name;
  final String state;
  final String city;
  final String address;
  final String categoryName;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String openingHours;
  final String shortDescription;
  final String recommendedTime;

  // ============================================================
  // HERITAGE-SPECIFIC INFORMATION
  //
  // These values come from `heritage_attractions`.
  // ============================================================

  final List<String> aliases;

  /// Kept as `category` for compatibility with the current UI.
  /// In Firestore, use the clearer field name `heritageType`.
  final String category;

  final String history;
  final String culturalSignificance;
  final String visitorEtiquette;
  final String sustainabilityTip;
  final String bestTime;
  final String audioEnglish;
  final String audioMalay;
  final String audioChinese;
  final String yearBuilt;
  final String architecturalStyle;
  final String heritageStatus;
  final List<String> conservationGuidelines;
  final List<String> visitorEtiquetteItems;
  final List<String> dressCode;
  final List<String> photographyRestrictions;
  final List<String> preservationPractices;
  final String stampImageUrl;

  String get attractionId => id;

  String get heritageType => category;

  String get locationText {
    final cleanCity = city.trim();
    final cleanState = state.trim();

    if (cleanCity.isEmpty && cleanState.isEmpty) {
      return address.trim();
    }

    if (cleanCity.isEmpty) {
      return '$cleanState, Malaysia';
    }

    if (cleanState.isEmpty) {
      return '$cleanCity, Malaysia';
    }

    if (cleanCity.toLowerCase() == cleanState.toLowerCase()) {
      return '$cleanState, Malaysia';
    }

    return '$cleanCity, $cleanState, Malaysia';
  }

  // ============================================================
  // LINKED FACTORY
  //
  // General values are read from the master `attractions` document.
  // Heritage values are read from `heritage_attractions`.
  //
  // Old duplicate heritage fields remain as FALLBACKS so you can
  // migrate your Firestore gradually without breaking the app.
  // ============================================================

  factory HeritageAttraction.fromLinkedFirestore({
    required String heritageDocumentId,
    required Map<String, dynamic> heritageData,
    String? attractionDocumentId,
    Map<String, dynamic>? attractionData,
  }) {
    String text(
        Map<String, dynamic>? data,
        String key,
        ) {
      return data?[key]?.toString().trim() ?? '';
    }

    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    List<String> asStringList(dynamic value) {
      if (value is! List) {
        return const <String>[];
      }

      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    String firstNonEmpty(List<String> values) {
      for (final value in values) {
        final clean = value.trim();
        if (clean.isNotEmpty) {
          return clean;
        }
      }
      return '';
    }

    double linkedDouble(
        String key,
        ) {
      final attractionValue = attractionData?[key];

      if (attractionValue != null) {
        return asDouble(attractionValue);
      }

      return asDouble(heritageData[key]);
    }

    String linkedImage() {
      final coverImageUrl =
      text(attractionData, 'coverImageUrl');

      if (coverImageUrl.isNotEmpty) {
        return coverImageUrl;
      }

      final imageUrls =
      asStringList(attractionData?['imageUrls']);

      if (imageUrls.isNotEmpty) {
        return imageUrls.first;
      }

      // Temporary fallback for legacy heritage documents.
      return text(heritageData, 'imageUrl');
    }

    String linkedOpeningHours() {
      final openingTime =
      text(attractionData, 'openingTime');
      final closingTime =
      text(attractionData, 'closingTime');

      if (openingTime.isNotEmpty &&
          closingTime.isNotEmpty) {
        return '$openingTime - $closingTime';
      }

      if (openingTime.isNotEmpty) {
        return openingTime;
      }

      if (closingTime.isNotEmpty) {
        return closingTime;
      }

      // Temporary fallback for legacy heritage documents.
      return text(heritageData, 'openingHours');
    }

    final linkedId = firstNonEmpty([
      attractionDocumentId ?? '',
      text(heritageData, 'attractionId'),
      heritageDocumentId,
    ]);

    return HeritageAttraction(
      id: linkedId,
      heritageDocumentId: heritageDocumentId,

      // ----------------------------------------------------------
      // MASTER ATTRACTION DATA
      // ----------------------------------------------------------
      name: firstNonEmpty([
        text(attractionData, 'name'),
        text(heritageData, 'name'),
      ]),
      state: firstNonEmpty([
        text(attractionData, 'state'),
        text(heritageData, 'state'),
      ]),
      city: firstNonEmpty([
        text(attractionData, 'area'),
        text(heritageData, 'city'),
      ]),
      address: firstNonEmpty([
        text(attractionData, 'address'),
        text(heritageData, 'address'),
      ]),
      categoryName: firstNonEmpty([
        text(attractionData, 'categoryName'),
        'Cultural & Heritage',
      ]),
      latitude: linkedDouble('latitude'),
      longitude: linkedDouble('longitude'),
      imageUrl: linkedImage(),
      openingHours: linkedOpeningHours(),
      shortDescription: firstNonEmpty([
        text(attractionData, 'description'),
        text(heritageData, 'shortDescription'),
      ]),
      recommendedTime: firstNonEmpty([
        text(attractionData, 'recommendedDuration'),
        text(heritageData, 'recommendedTime'),
      ]),

      // ----------------------------------------------------------
      // HERITAGE DATA
      // ----------------------------------------------------------
      aliases: asStringList(
        heritageData['aliases'],
      ),
      category: firstNonEmpty([
        text(heritageData, 'heritageType'),
        text(heritageData, 'category'),
        'Heritage Site',
      ]),
      history: text(
        heritageData,
        'history',
      ),
      culturalSignificance: text(
        heritageData,
        'culturalSignificance',
      ),
      visitorEtiquette: text(
        heritageData,
        'visitorEtiquette',
      ),
      sustainabilityTip: text(
        heritageData,
        'sustainabilityTip',
      ),
      bestTime: text(
        heritageData,
        'bestTime',
      ),
      audioEnglish: text(
        heritageData,
        'audioEnglish',
      ),
      audioMalay: text(
        heritageData,
        'audioMalay',
      ),
      audioChinese: text(
        heritageData,
        'audioChinese',
      ),
      yearBuilt: text(
        heritageData,
        'yearBuilt',
      ),
      architecturalStyle: text(
        heritageData,
        'architecturalStyle',
      ),
      heritageStatus: text(
        heritageData,
        'heritageStatus',
      ),
      conservationGuidelines: asStringList(
        heritageData['conservationGuidelines'],
      ),
      visitorEtiquetteItems: asStringList(
        heritageData['visitorEtiquetteItems'],
      ),
      dressCode: asStringList(
        heritageData['dressCode'],
      ),
      photographyRestrictions: asStringList(
        heritageData['photographyRestrictions'],
      ),
      preservationPractices: asStringList(
        heritageData['preservationPractices'],
      ),
      stampImageUrl: text(
        heritageData,
        'stampImageUrl',
      ),
    );
  }

  // ============================================================
  // LEGACY FACTORY
  //
  // Kept so old code still compiles. New service code should use
  // fromLinkedFirestore().
  // ============================================================

  factory HeritageAttraction.fromFirestore(
      String documentId,
      Map<String, dynamic> data,
      ) {
    return HeritageAttraction.fromLinkedFirestore(
      heritageDocumentId: documentId,
      heritageData: data,
      attractionDocumentId:
      data['attractionId']?.toString().trim().isNotEmpty == true
          ? data['attractionId'].toString().trim()
          : documentId,
      attractionData: null,
    );
  }

  // ============================================================
  // HERITAGE-ONLY FIRESTORE MAP
  //
  // General attraction fields are intentionally NOT written here.
  // ============================================================

  Map<String, dynamic> toHeritageMap() {
    return {
      'attractionId': id,
      'aliases': aliases,
      'heritageType': category,
      'history': history,
      'culturalSignificance': culturalSignificance,
      'visitorEtiquette': visitorEtiquette,
      'sustainabilityTip': sustainabilityTip,
      'bestTime': bestTime,
      'audioEnglish': audioEnglish,
      'audioMalay': audioMalay,
      'audioChinese': audioChinese,
      'yearBuilt': yearBuilt,
      'architecturalStyle': architecturalStyle,
      'heritageStatus': heritageStatus,
      'conservationGuidelines': conservationGuidelines,
      'visitorEtiquetteItems': visitorEtiquetteItems,
      'dressCode': dressCode,
      'photographyRestrictions': photographyRestrictions,
      'preservationPractices': preservationPractices,
      'stampImageUrl': stampImageUrl,
    };
  }

  // Keep the old seeder method name so existing seeder code compiles.
  // It now writes ONLY the heritage extension information.
  Map<String, dynamic> toSeedMap() {
    return toHeritageMap();
  }
}
