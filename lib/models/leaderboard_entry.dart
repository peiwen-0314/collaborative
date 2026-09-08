class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.totalPoints,
    required this.level,
  });

  final String userId;
  final String name;
  final int totalPoints;
  final int level;
}