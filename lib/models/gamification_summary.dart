class GamificationSummary {
  const GamificationSummary({
    required this.userName,
    required this.level,
    required this.levelTitle,
    required this.currentXp,
    required this.requiredXp,
    required this.totalPoints,
    required this.collectedStamps,
    required this.totalStamps,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.carbonSaved,
    required this.treeGrowth,
  });

  final String userName;
  final int level;
  final String levelTitle;
  final int currentXp;
  final int requiredXp;
  final int totalPoints;
  final int collectedStamps;
  final int totalStamps;
  final int completedChallenges;
  final int totalChallenges;
  final double carbonSaved;
  final double treeGrowth;

  factory GamificationSummary.fromMap(
      Map<String, dynamic> data, {
        required String userName,
      }) {
    int asInt(String key) => (data[key] as num?)?.toInt() ?? 0;
    double asDouble(String key) => (data[key] as num?)?.toDouble() ?? 0;

    return GamificationSummary(
      userName: userName,
      level: asInt('level'),
      levelTitle: data['levelTitle']?.toString() ?? 'Green Beginner',
      currentXp: asInt('currentXp'),
      requiredXp: asInt('requiredXp'),
      totalPoints: asInt('totalPoints'),
      collectedStamps: asInt('collectedStamps'),
      totalStamps: asInt('totalStamps'),
      completedChallenges: asInt('completedChallenges'),
      totalChallenges: asInt('totalChallenges'),
      carbonSaved: asDouble('carbonSaved'),
      treeGrowth: asDouble('treeGrowth').clamp(0.0, 1.0).toDouble(),
    );
  }
}
