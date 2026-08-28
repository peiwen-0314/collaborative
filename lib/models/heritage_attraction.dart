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
    required this.imageAsset,
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
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String state;
  final String city;
  final String category;
  final double latitude;
  final double longitude;
  final String imageAsset;
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

  String get locationText => '$state, Malaysia';
}
