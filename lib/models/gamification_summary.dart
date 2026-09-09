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
    required this.treeLevel,
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

  /// Current tree progress from 0.0 to 1.0.
  final double treeGrowth;

  /// Number of the current virtual tree.
  ///
  /// Tree 1 -> Tree 2 -> Tree 3 ...
  final int treeLevel;

  factory GamificationSummary.fromMap(
      Map<String, dynamic> data, {
        required String userName,
      }) {
    int asInt(String key) {
      return (data[key] as num?)?.toInt() ?? 0;
    }

    double asDouble(String key) {
      return (data[key] as num?)?.toDouble() ?? 0;
    }

    final rawTreeLevel = asInt('treeLevel');

    return GamificationSummary(
      userName: userName,

      level: asInt('level'),

      levelTitle:
      data['levelTitle']?.toString() ??
          'Green Beginner',

      currentXp: asInt('currentXp'),

      requiredXp: asInt('requiredXp'),

      totalPoints: asInt('totalPoints'),

      collectedStamps:
      asInt('collectedStamps'),

      totalStamps:
      asInt('totalStamps'),

      completedChallenges:
      asInt('completedChallenges'),

      totalChallenges:
      asInt('totalChallenges'),

      carbonSaved:
      asDouble('carbonSaved'),

      treeGrowth:
      asDouble('treeGrowth')
          .clamp(0.0, 1.0)
          .toDouble(),

      treeLevel:
      rawTreeLevel <= 0
          ? 1
          : rawTreeLevel,
    );
  }
}