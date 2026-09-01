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

    // Extra historical-information fields.
    this.yearBuilt = '',
    this.architecturalStyle = '',
    this.heritageStatus = '',
    this.conservationGuidelines = const <String>[],
    this.visitorEtiquetteItems = const <String>[],
    this.dressCode = const <String>[],
    this.photographyRestrictions = const <String>[],
    this.preservationPractices = const <String>[],
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String state;
  final String city;
  final String category;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String openingHours;
  final String shortDescription;
  final String history;
  final String culturalSignificance;
  final String visitorEtiquette;
  final String sustainabilityTip;
  final String recommendedTime;
  final String bestTime;
  final String audioEnglish;
  final String audioMalay;
  final String audioChinese;

  // New fields used by the Historical Information design.
  final String yearBuilt;
  final String architecturalStyle;
  final String heritageStatus;
  final List<String> conservationGuidelines;
  final List<String> visitorEtiquetteItems;
  final List<String> dressCode;
  final List<String> photographyRestrictions;
  final List<String> preservationPractices;

  String get locationText {
    final cleanCity = city.trim();
    final cleanState = state.trim();

    if (cleanCity.isEmpty) {
      return '$cleanState, Malaysia';
    }

    if (cleanCity.toLowerCase() == cleanState.toLowerCase()) {
      return '$cleanState, Malaysia';
    }

    return '$cleanCity, $cleanState, Malaysia';
  }

  factory HeritageAttraction.fromFirestore(
      String documentId,
      Map<String, dynamic> data,
      ) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    List<String> asStringList(dynamic value) {
      if (value is! List) return const <String>[];

      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return HeritageAttraction(
      id: documentId,
      name: data['name']?.toString() ?? '',
      aliases: asStringList(data['aliases']),
      state: data['state']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Heritage Site',
      latitude: asDouble(data['latitude']),
      longitude: asDouble(data['longitude']),
      imageUrl: data['imageUrl']?.toString() ?? '',
      openingHours: data['openingHours']?.toString() ?? '',
      shortDescription: data['shortDescription']?.toString() ?? '',
      history: data['history']?.toString() ?? '',
      culturalSignificance:
      data['culturalSignificance']?.toString() ?? '',
      visitorEtiquette: data['visitorEtiquette']?.toString() ?? '',
      sustainabilityTip: data['sustainabilityTip']?.toString() ?? '',
      recommendedTime: data['recommendedTime']?.toString() ?? '',
      bestTime: data['bestTime']?.toString() ?? '',
      audioEnglish: data['audioEnglish']?.toString() ?? '',
      audioMalay: data['audioMalay']?.toString() ?? '',
      audioChinese: data['audioChinese']?.toString() ?? '',

      // New Firestore fields.
      yearBuilt: data['yearBuilt']?.toString() ?? '',
      architecturalStyle: data['architecturalStyle']?.toString() ?? '',
      heritageStatus: data['heritageStatus']?.toString() ?? '',
      conservationGuidelines:
      asStringList(data['conservationGuidelines']),
      visitorEtiquetteItems:
      asStringList(data['visitorEtiquetteItems']),
      dressCode: asStringList(data['dressCode']),
      photographyRestrictions:
      asStringList(data['photographyRestrictions']),
      preservationPractices:
      asStringList(data['preservationPractices']),
    );
  }

  // Used by the one-time text seeder. imageUrl is deliberately omitted so
  // an image URL you paste into Firestore will never be overwritten.
  Map<String, dynamic> toSeedMap() {
    return {
      'name': name,
      'aliases': aliases,
      'state': state,
      'city': city,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': openingHours,
      'shortDescription': shortDescription,
      'history': history,
      'culturalSignificance': culturalSignificance,
      'visitorEtiquette': visitorEtiquette,
      'sustainabilityTip': sustainabilityTip,
      'recommendedTime': recommendedTime,
      'bestTime': bestTime,
      'audioEnglish': audioEnglish,
      'audioMalay': audioMalay,
      'audioChinese': audioChinese,

      // New historical-information fields.
      'yearBuilt': yearBuilt,
      'architecturalStyle': architecturalStyle,
      'heritageStatus': heritageStatus,
      'conservationGuidelines': conservationGuidelines,
      'visitorEtiquetteItems': visitorEtiquetteItems,
      'dressCode': dressCode,
      'photographyRestrictions': photographyRestrictions,
      'preservationPractices': preservationPractices,
    };
  }
}
